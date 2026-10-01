<#
  CAPTURE 3D SANS AUCUNE APPARITION SUR L'ECRAN DE L'UTILISATEUR.

  Pourquoi (conv-531, 2026-09-14) : la voie tools/studio-capture-3d.ps1 lance Studio sur le bureau
  REEL, hors de la zone visible. Malgre toutes les corrections, une petite fenetre de chargement
  reste peinte ~17 ms a chaque lancement, et l'utilisateur la voit clignoter.

  Ici, Studio tourne dans un bureau Windows CACHE (scripts/hdesk-lancer.ps1). PrintWindow n'y lit
  qu'une zone unie — mais le MOTEUR, lui, rend normalement : le script client BRR_Capture appelle
  CaptureService:CaptureScreenshot et Studio ecrit un PNG dans
  %LOCALAPPDATA%\Roblox\tmp-capture-storage. On recupere ce fichier.

  Difference avec studio-capture-3d.ps1 : l'image est la VUE DU JEU seule (sans l'interface de
  Studio), au format de la fenetre du bureau cache.

  Usage : powershell -NoProfile -File tools/studio-capture-moteur.ps1 [-Secondes 60] [-Output capture-moteur.png]
  Sortie JSON ; code 3 si aucune capture n'a ete produite.
#>
# -Place : place a ouvrir. Par defaut BrainRotRoyale.autotest.rbxlx — MAIS ce fichier est
# reconstruit par tout `python build.py --autotest ...` qui tourne en parallele : mesure du
# 2026-09-20, la place a ete regeneree SANS BRR_HUB pendant la capture, et Studio a ouvert un
# match au lieu du menu (journal Studio : « [HUB] copie de test : hub ferme »). Passer une
# COPIE privee via -Place met la capture a l'abri de cet ecrasement.
# fix-ok: place partagee ecrasee par un build concurrent pendant le chargement de Studio
# -Id : bureau cache a utiliser. Defaut 'brrcap'. fix-ok: l'identifiant etait EN DUR, donc deux
# captures en parallele se disputaient le meme bureau ; mesure le 2026-09-20 : le lanceur a rendu
# « identifiant 'brrcap' occupe (pid 13972) », pid nul, et le script a recupere l'image de l'AUTRE
# Studio (un match au lieu de la boutique). On isole le bureau ET on n'accepte que l'image de
# NOTRE processus (le moteur nomme le fichier wob-<pid>...).
param([int]$Secondes = 60, [string]$Output = (Join-Path $PSScriptRoot '..\captures\capture-moteur.png'), [string]$Place = '', [string]$Id = 'brrcap')
# Les photos vont dans captures/ (ignore par git) et non plus a la racine (2026-09-21) : on cree
# le dossier de la sortie s'il manque, quel que soit -Output.
New-Item -ItemType Directory -Force (Split-Path -Parent ([System.IO.Path]::GetFullPath($Output))) | Out-Null
$ErrorActionPreference = 'Stop'
# FORMAT DE L'IMAGE : C'EST LA SESSION D'AFFICHAGE QUI DECIDE (corrige le 2026-09-14).
# Premiere explication, FAUSSE : « le bureau cache impose le portrait ». En realite le bureau cache
# herite de la resolution de la SESSION. Mesure : session Bureau a distance en 1080x2304 affichee a
# 200 % -> ecran vu par les applications 540x1152, image 592x1348 (portrait) ; la meme session
# remise en paysage -> ecran 1920x1080, fenetre 1296x930. Rien a regler dans ce script.
# Ce qui a ete tente et ne sert a rien : redimensionner la fenetre dans le bureau cache (la largeur
# reste plafonnee par l'ecran de la session) et changer la resolution du bureau
# (ChangeDisplaySettingsEx rend -1). A savoir si on y revient : SetThreadDesktop exige un FIL NEUF,
# sinon erreur 170 (ERROR_BUSY).
# LE STUDIO LE PLUS RECENT, dans les DEUX dossiers d'installation (fix du 2026-09-29, conv-885).
# Cause mesuree : Studio 0.740 s'est installe dans « Program Files », le 0.739 est reste dans
# « Program Files (x86) ». Lance, le 0.739 passe la main au 0.740 (« -parentPid <lui> » dans la
# ligne de commande du nouveau) puis se ferme en code 0 : le script suivait un processus mort, ne
# fermait jamais le vrai Studio (pid 3328 reste ouvert) et ne retrouvait pas l'image a son pid.
# Meme regle que tools/ecotest_moteur.ps1 : le plus recent sur disque.
$studio = (Get-ChildItem 'C:\Program Files\Roblox\Versions\*\RobloxStudioBeta.exe', 'C:\Program Files (x86)\Roblox\Versions\*\RobloxStudioBeta.exe' -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
$place = (Resolve-Path ($(if ($Place) { $Place } else { Join-Path $PSScriptRoot '..\BrainRotRoyale.autotest.rbxlx' }))).Path
$stock = Join-Path $env:LOCALAPPDATA 'Roblox\tmp-capture-storage'
$plugDir = Join-Path $env:LOCALAPPDATA 'Roblox\Plugins'
New-Item -ItemType Directory -Force $plugDir | Out-Null
# fix-ok: cause mesuree du « aucune image produite par le moteur » du 2026-09-20 14:47 — le nom du
# plugin etait FIXE ('BRR_AutoRun.lua'), partage par tous les runs ; le bloc finally d'une capture
# concurrente (Studio pid 18968, demarre a 14:52:30) supprimait le plugin AVANT que notre Studio ne
# le charge, donc aucun Play, donc aucune capture. Un nom par bureau cache supprime la collision.
$plug = Join-Path $plugDir ('BRR_AutoRun-' + ($Id -replace '[^A-Za-z0-9_-]', '_') + '.lua')
Copy-Item (Join-Path $PSScriptRoot 'BRR_AutoRun.lua') $plug -Force
# CONNEXION EN FILE UNIQUE (fix du 2026-09-29, conv-885). Cause mesuree : trois captures lancees
# ensemble ont renouvele la connexion Roblox au meme instant. Le jeton de renouvellement ne sert
# qu'une fois : deux Studio ont recu « 401 Unauthorized » sur oauth/v1/userinfo et l'un a EFFACE la
# session enregistree (« Deleting and logging out security cookies », journal 07:06:16). Studio
# etait deconnecte pour tout le monde, et chaque capture suivante rendait « arretee trop tot ? ».
# Un Studio ne demarre donc que quand aucun autre n'est en train de se connecter : un verrou
# entre les captures, puis l'attente de tout Studio demarre depuis moins de 25 s (lance par un
# autre script ou a la main). Le verrou est rendu des que NOTRE Studio est connecte.
$fileConnexion = New-Object System.Threading.Mutex($false, 'Local\BRR-Studio-Connexion')
$tientConnexion = $false
try { $tientConnexion = $fileConnexion.WaitOne([TimeSpan]::FromSeconds(240)) }
catch [System.Threading.AbandonedMutexException] { $tientConnexion = $true }
if (-not $tientConnexion) {
  [pscustomobject]@{ pid = $null; capture = $null; motif = "file de connexion Studio occupee depuis 240 s" } | ConvertTo-Json -Compress
  exit 6
}
$calme = (Get-Date).AddSeconds(60)
while ((Get-Date) -lt $calme -and (Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue |
    Where-Object { $_.StartTime -gt (Get-Date).AddSeconds(-25) })) { Start-Sleep -Milliseconds 500 }
$depart = Get-Date
$pidStudio = $null
try {
  $json = & powershell -NoProfile -ExecutionPolicy Bypass -File 'D:\AutoWinOS\scripts\hdesk-lancer.ps1' `
    -Id $Id -Executable $studio -Arguments ('"' + $place + '"') `
    -Travail 'capture 3D par le moteur' -Conversation 'conv-531' | Select-Object -Last 1
  $lance = $json | ConvertFrom-Json
  $pidStudio = $lance.pid
  $pidLanceur = $pidStudio
  # Un Studio qui passe la main a une version plus recente : c'est le RELAIS qui rend la vue (et
  # qui nomme l'image wob-<son pid>). On le reconnait a « -parentPid <notre pid> ».
  $trouverRelais = {
    if ($pidStudio -ne $pidLanceur) { return }
    $relais = Get-CimInstance Win32_Process -Filter "Name='RobloxStudioBeta.exe'" -ErrorAction SilentlyContinue |
      Where-Object { $_.CommandLine -match ('-parentPid ' + $pidLanceur + '\b') } | Select-Object -First 1
    if ($relais) { $script:pidStudio = [int]$relais.ProcessId }
  }
  if (-not $pidStudio) {
    [pscustomobject]@{ pid = $null; capture = $null; motif = "le bureau cache '$Id' n'a pas rendu de processus : $($lance.erreur)" } | ConvertTo-Json -Compress
    exit 4
  }
  # Connexion de NOTRE Studio (son journal porte le chemin de notre place des la ligne 6) :
  # connecte -> on rend la file ; fenetre de connexion -> on le DIT, au lieu d'attendre pour rien.
  $motPlace = [IO.Path]::GetFileName($place)
  $etatConnexion = $null
  $jConnexion = $null
  $limiteConnexion = (Get-Date).AddSeconds(45)
  while (-not $etatConnexion -and (Get-Date) -lt $limiteConnexion) {
    Start-Sleep -Milliseconds 500
    & $trouverRelais
    $jConnexion = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Roblox\logs') -Filter '*Studio*.log' -ErrorAction SilentlyContinue |
      Where-Object { $_.LastWriteTime -gt $depart } |
      Where-Object { Select-String -Path $_.FullName -Pattern ([regex]::Escape($motPlace)) -Quiet -ErrorAction SilentlyContinue } |
      Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($jConnexion) {
      if (Select-String -Path $jConnexion.FullName -Pattern 'Logged in User GUID' -Quiet -ErrorAction SilentlyContinue) { $etatConnexion = 'connecte' }
      # 0.739 ecrit « show login dialog [start] » ; 0.740 ouvre une page de connexion par QR code
      # et ecrit « awaitQuickSignIn » (journaux du 2026-09-29, 5 sessions deconnectees sur 5, et
      # aucune session connectee ne porte cette ligne).
      elseif (Select-String -Path $jConnexion.FullName -Pattern 'show login dialog \[start\]|awaitQuickSignIn' -Quiet -ErrorAction SilentlyContinue) { $etatConnexion = 'deconnecte' }
    }
  }
  & $trouverRelais
  if ($tientConnexion) { $fileConnexion.ReleaseMutex(); $tientConnexion = $false }
  if ($etatConnexion -eq 'deconnecte') {
    [pscustomobject]@{ pid = $pidStudio; capture = $null; motif = "Studio n'est plus connecte a Roblox : il a ouvert sa fenetre de connexion (journal $($jConnexion.Name)). Ouvre Studio une fois, reconnecte-toi, puis relance." } | ConvertTo-Json -Compress
    exit 5
  }
  # La fenetre existe des le lancement, mais Studio la remanie pendant le chargement : on repasse
  # plusieurs fois, jusqu'a ce que la capture soit prise (le script client attend 25 s).
  Start-Sleep -Seconds $Secondes
  # fix-ok: cause mesuree le 2026-09-20 — trois captures d'affilee ont rendu « aucune image »
  # alors que le rendu marchait. Le nom du fichier n'etait PAS en cause (le moteur ecrit bien
  # wob-<pid>000000) : notre Studio etait ARRETE avant la capture (journal 12:53:42, derniere
  # ligne a 12:54:07, soit 25 s de session) par le bloc finally d'un run voisin lance avec l'-Id
  # par defaut, qui arrete tous les Studio demarres apres lui. On ne peut pas empecher le voisin,
  # mais on peut le DIRE : on relit le journal de NOTRE session (reconnaissable a notre chemin de
  # place, unique par run), et sans la ligne « [BRRCAP] capture prete » le motif nomme la vraie
  # cause au lieu de « aucune image ». L'heure de cette ligne sert aussi a choisir le bon fichier.
  $motPlace = [IO.Path]::GetFileName($place)
  $journal = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Roblox\logs') -Filter '*.log' -EA SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt $depart } |
    Where-Object { Select-String -Path $_.FullName -Pattern ([regex]::Escape($motPlace)) -Quiet } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $hCap = $null
  if ($journal) {
    $ligne = Select-String -Path $journal.FullName -Pattern 'BRRCAP. capture prete' | Select-Object -Last 1
    if ($ligne -and $ligne.Line -match '^([0-9T:\.\-]+Z)') { $hCap = [datetime]::Parse($matches[1]).ToLocalTime() }
  }
  if (-not $hCap) {
    $motif = if ($journal) { "notre session Studio n'a pas atteint la capture (journal $($journal.Name), place $motPlace) : arretee trop tot ?" }
             else { "aucun journal Studio pour la place $motPlace" }
    [pscustomobject]@{ pid = $pidStudio; capture = $null; motif = $motif } | ConvertTo-Json -Compress
    exit 3
  }
  # Le moteur nomme sa capture « wob-<pid>000000 » : c'est le lien SUR avec notre processus, et il
  # passe avant l'heure. fix-ok: la selection par heure seule a ramene wob-8988000000 alors que
  # notre Studio etait le pid 15500 (mesure 15:17) — l'image d'un run voisin, prise a la meme
  # seconde. On ne garde l'heure que comme repli, et on le DIT dans la sortie (champ `correlation`).
  $tous = Get-ChildItem -LiteralPath $stock -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt $depart -and $_.Length -gt 20000 }
  $img = $tous | Where-Object { $_.Name -like "wob-$pidStudio*" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $correlation = 'pid'
  if (-not $img) {
    $correlation = 'heure (incertain : aucune image au nom de notre pid)'
    $img = $tous | Sort-Object { [math]::Abs(($_.LastWriteTime - $hCap).TotalSeconds) } | Select-Object -First 1
  }
  if (-not $img) {
    [pscustomobject]@{ pid = $pidStudio; capture = $null; motif = 'capture annoncee par le moteur mais aucun fichier dans le stock' } | ConvertTo-Json -Compress
    exit 3
  }
  Copy-Item $img.FullName $Output -Force
  # Compte des couleurs distinctes : 1 = rate, ~250 = vue rendue (meme critere que la voie hors ecran).
  Add-Type -AssemblyName System.Drawing
  $bmp = [System.Drawing.Bitmap]::FromFile($Output)
  $set = New-Object 'System.Collections.Generic.HashSet[int]'
  for ($i = 0; $i -lt 32; $i++) { for ($j = 0; $j -lt 32; $j++) {
    $null = $set.Add($bmp.GetPixel([int](($bmp.Width - 1) * $i / 31), [int](($bmp.Height - 1) * $j / 31)).ToArgb())
  } }
  $t = "$($bmp.Width)x$($bmp.Height)"; $bmp.Dispose()
  [pscustomobject]@{ pid = $pidStudio; output = $Output; taille = $t; couleurs = $set.Count; correlation = $correlation; source = $img.FullName } | ConvertTo-Json -Compress
  if ($set.Count -le 1) { exit 3 }
} finally {
  # Le test MULTIJOUEUR lance un serveur et un processus par client : arreter le seul processus
  # lance laissait 6 Studio ouverts (mesure 2026-09-14). On arrete ceux DEMARRES APRES notre
  # lancement — jamais un Studio que l'utilisateur avait deja ouvert.
  if ($pidStudio) { Stop-Process -Id $pidStudio -Force -ErrorAction SilentlyContinue }
  if ($pidLanceur -and $pidLanceur -ne $pidStudio) { Stop-Process -Id $pidLanceur -Force -ErrorAction SilentlyContinue }
  # On n'arrete les autres Studio recents QUE sur le bureau par defaut : avec un -Id propre a un
  # run, tuer ceux des autres runs saboterait leur capture (constate le 2026-09-20).
  if ($Id -eq 'brrcap') {
    Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue |
      Where-Object { $_.StartTime -ge $depart } |
      Stop-Process -Force -ErrorAction SilentlyContinue
  }
  Remove-Item $plug -ErrorAction SilentlyContinue
  if ($tientConnexion) { $fileConnexion.ReleaseMutex() }
  $fileConnexion.Dispose()
}
