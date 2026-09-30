# Ouvre la copie de test dans Studio sur un bureau cache (Run = serveur seul, sans joueur).
# Le plugin temporaire tools/BRR_AutoRun.lua lance Run, puis est retire ; les lignes [BRR] du
# journal Studio sont recopiees ici. Rien ne s'affiche sur l'ecran de l'utilisateur.
#
# 2026-09-16, deux causes mesurees et corrigees :
#  1. hdesk-lancer.ps1 exige -Travail (et un fil) depuis le 2026-09-13 : sans lui, rien ne demarrait ;
#  2. Studio est a INSTANCE UNIQUE : le processus lance meurt aussitot et c'est un AUTRE processus
#     qui ouvre la place. On ne suit donc plus le pid rendu, on suit le processus VIVANT, et on
#     attend l'apparition des lignes [BRR] au lieu d'un delai fixe.
# -Place : ouvrir une AUTRE place que la copie de test partagee. Deux sessions qui travaillent dans
#   le meme depot se reecrivaient BrainRotRoyale.autotest.rbxlx entre le build et l'ouverture de
#   Studio : le run mesurait alors la place de l'autre (mesure du 2026-09-20, trois runs perdus).
param([int]$Secondes = 200, [string]$Place = '')
$ErrorActionPreference = 'Stop'
# STUDIO EST A INSTANCE UNIQUE, et ce script TUE Studio en fin de course. Demarrer alors qu'une
# autre session en tient un, c'est mesurer sa place puis couper son travail. On refuse.
if (Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue) {
  Write-Output 'STUDIO_OCCUPE : une autre session tient Studio, run non lance'
  exit 4
}
# LE STUDIO LE PLUS RECENT, dans les DEUX dossiers d'installation (2026-09-30, meme regle que
# studio-capture-moteur.ps1). Le premier trouve dans « (x86) » etait le 0.739, qui passe la main au
# 0.741 de « Program Files » puis se ferme : lancer directement le plus recent evite ce relais.
$studio = Get-ChildItem 'C:\Program Files\Roblox\Versions\*\RobloxStudioBeta.exe', 'C:\Program Files (x86)\Roblox\Versions\*\RobloxStudioBeta.exe' -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
$place = if ($Place -ne '') { Resolve-Path $Place } else { Join-Path $PSScriptRoot '..\BrainRotRoyale.autotest.rbxlx' | Resolve-Path }
$logs = Join-Path $env:LOCALAPPDATA 'Roblox\logs'
$plugDir = Join-Path $env:LOCALAPPDATA 'Roblox\Plugins'
New-Item -ItemType Directory -Force $plugDir | Out-Null
$plug = Join-Path $plugDir 'BRR_AutoRun.lua'
Copy-Item (Join-Path $PSScriptRoot 'BRR_AutoRun.lua') $plug -Force
# Verrou laisse par une session morte : Studio ouvrirait la place en lecture seule.
$verrou = "$place.lock"
if ((Test-Path $verrou) -and -not (Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue)) { Remove-Item $verrou -Force }
# CONNEXION EN FILE UNIQUE, partagee avec studio-capture-moteur.ps1 (meme verrou nomme). Cause
# mesuree le 2026-09-29 (conv-885) : trois Studio qui renouvellent la connexion au meme instant
# se disputent un jeton a usage unique, et l'un EFFACE la session enregistree pour tout le monde.
$fileConnexion = New-Object System.Threading.Mutex($false, 'Local\BRR-Studio-Connexion')
$tientConnexion = $false
try { $tientConnexion = $fileConnexion.WaitOne([TimeSpan]::FromSeconds(240)) }
catch [System.Threading.AbandonedMutexException] { $tientConnexion = $true }
if (-not $tientConnexion) { Write-Output 'CONNEXION_OCCUPEE : file de connexion Studio occupee depuis 240 s'; exit 6 }
$avant = Get-Date
$conv = if ($env:AUTOWIN_CONVERSATION_ID) { $env:AUTOWIN_CONVERSATION_ID } else { 'conv-531' }
& powershell -NoProfile -File (Join-Path $PSScriptRoot '..\..\AutoWinOS\scripts\hdesk-lancer.ps1') `
  -Id brrtest -Executable $studio.FullName -Arguments "`"$place`"" `
  -Travail 'test automatique Brainrot Royale' -Conversation $conv -AttenteSecondes 60 | Out-Null

# STUDIO DECONNECTE = ARRET IMMEDIAT (2026-09-30). Mesure : Studio 0.741 deconnecte ouvre une page
# de connexion par QR code, n'ouvre JAMAIS la place, et le script attendait ses 240 s pour rendre
# un journal sans aucune ligne [BRR] — un « rien » indiscernable d'un jeu qui ne demarre pas.
# 0.739 ecrit « show login dialog [start] », 0.740+ « awaitQuickSignIn » ; connecte, il ecrit
# « Logged in User GUID ». On lit le journal de NOTRE place, au plus 45 s.
$motPlace = [IO.Path]::GetFileName("$place")
$etatConnexion = $null
$jConnexion = $null
$limiteConnexion = (Get-Date).AddSeconds(45)
while (-not $etatConnexion -and (Get-Date) -lt $limiteConnexion) {
  Start-Sleep -Milliseconds 500
  $jConnexion = Get-ChildItem $logs -Filter '*Studio*.log' -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt $avant } |
    Where-Object { Select-String -Path $_.FullName -Pattern ([regex]::Escape($motPlace)) -Quiet -ErrorAction SilentlyContinue } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($jConnexion) {
    if (Select-String -Path $jConnexion.FullName -Pattern 'Logged in User GUID' -Quiet -ErrorAction SilentlyContinue) { $etatConnexion = 'connecte' }
    elseif (Select-String -Path $jConnexion.FullName -Pattern 'show login dialog \[start\]|awaitQuickSignIn' -Quiet -ErrorAction SilentlyContinue) { $etatConnexion = 'deconnecte' }
  }
}
$fileConnexion.ReleaseMutex(); $fileConnexion.Dispose()
if ($etatConnexion -eq 'deconnecte') {
  Get-Process RobloxStudioBeta, RobloxCrashHandler -ErrorAction SilentlyContinue |
    Where-Object { $_.StartTime -gt $avant } | Stop-Process -Force -ErrorAction SilentlyContinue
  Remove-Item $plug -ErrorAction SilentlyContinue
  Write-Output "STUDIO_DECONNECTE : Studio a ouvert sa page de connexion au lieu de la place (journal $($jConnexion.Name)). Ouvrir Studio une fois, se connecter, puis relancer."
  exit 5
}

# Attente ACTIVE : on s'arrete des que le journal porte la fin du test, au plus tard a $Secondes.
$fin = (Get-Date).AddSeconds($Secondes)
$log = $null
while ((Get-Date) -lt $fin) {
  Start-Sleep 5
  $log = Get-ChildItem $logs -Filter '*Studio*.log' | Where-Object { $_.LastWriteTime -gt $avant } |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($log -and (Select-String -Path $log.FullName -Pattern '\[ECOTEST\] FIN|\[BRR\] plugin : .* termine' -Quiet)) { break }
}
Get-Process RobloxStudioBeta, RobloxCrashHandler -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Remove-Item $plug -ErrorAction SilentlyContinue
if (-not $log) { Write-Output 'AUCUN_JOURNAL'; exit 3 }
Write-Output "journal=$($log.Name)"
Select-String -Path $log.FullName -Pattern '\[BRR\]|\[ECOTEST\]|\[HUB\]|GameServer|GameClient|Script error' | ForEach-Object { $_.Line }
