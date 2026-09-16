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
param([int]$Secondes = 60, [string]$Output = (Join-Path $PSScriptRoot '..\capture-moteur.png'))
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
$studio = (Get-ChildItem 'C:\Program Files (x86)\Roblox\Versions\*\RobloxStudioBeta.exe' | Select-Object -First 1).FullName
$place = (Resolve-Path (Join-Path $PSScriptRoot '..\BrainRotRoyale.autotest.rbxlx')).Path
$stock = Join-Path $env:LOCALAPPDATA 'Roblox\tmp-capture-storage'
$plugDir = Join-Path $env:LOCALAPPDATA 'Roblox\Plugins'
New-Item -ItemType Directory -Force $plugDir | Out-Null
$plug = Join-Path $plugDir 'BRR_AutoRun.lua'
Copy-Item (Join-Path $PSScriptRoot 'BRR_AutoRun.lua') $plug -Force
$depart = Get-Date
$pidStudio = $null
try {
  $json = & powershell -NoProfile -ExecutionPolicy Bypass -File 'D:\AutoWinOS\scripts\hdesk-lancer.ps1' `
    -Id 'brrcap' -Executable $studio -Arguments ('"' + $place + '"') `
    -Travail 'capture 3D par le moteur' -Conversation 'conv-531' | Select-Object -Last 1
  $lance = $json | ConvertFrom-Json
  $pidStudio = $lance.pid
  # La fenetre existe des le lancement, mais Studio la remanie pendant le chargement : on repasse
  # plusieurs fois, jusqu'a ce que la capture soit prise (le script client attend 25 s).
  Start-Sleep -Seconds $Secondes
  $img = Get-ChildItem -LiteralPath $stock -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt $depart -and $_.Length -gt 20000 } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $img) {
    [pscustomobject]@{ pid = $pidStudio; capture = $null; motif = 'aucune image produite par le moteur' } | ConvertTo-Json -Compress
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
  [pscustomobject]@{ pid = $pidStudio; output = $Output; taille = $t; couleurs = $set.Count; source = $img.FullName } | ConvertTo-Json -Compress
  if ($set.Count -le 1) { exit 3 }
} finally {
  # Le test MULTIJOUEUR lance un serveur et un processus par client : arreter le seul processus
  # lance laissait 6 Studio ouverts (mesure 2026-09-14). On arrete ceux DEMARRES APRES notre
  # lancement — jamais un Studio que l'utilisateur avait deja ouvert.
  if ($pidStudio) { Stop-Process -Id $pidStudio -Force -ErrorAction SilentlyContinue }
  Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue |
    Where-Object { $_.StartTime -ge $depart } |
    Stop-Process -Force -ErrorAction SilentlyContinue
  Remove-Item $plug -ErrorAction SilentlyContinue
}
