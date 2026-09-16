# Ouvre la copie de test dans Studio sur un bureau cache (Run = serveur seul, sans joueur).
# Le plugin temporaire tools/BRR_AutoRun.lua lance Run, puis est retire ; les lignes [BRR] du
# journal Studio sont recopiees ici. Rien ne s'affiche sur l'ecran de l'utilisateur.
#
# 2026-09-16, deux causes mesurees et corrigees :
#  1. hdesk-lancer.ps1 exige -Travail (et un fil) depuis le 2026-09-13 : sans lui, rien ne demarrait ;
#  2. Studio est a INSTANCE UNIQUE : le processus lance meurt aussitot et c'est un AUTRE processus
#     qui ouvre la place. On ne suit donc plus le pid rendu, on suit le processus VIVANT, et on
#     attend l'apparition des lignes [BRR] au lieu d'un delai fixe.
param([int]$Secondes = 200)
$ErrorActionPreference = 'Stop'
$studio = Get-ChildItem 'C:\Program Files (x86)\Roblox\Versions\*\RobloxStudioBeta.exe' | Select-Object -First 1
$place = Join-Path $PSScriptRoot '..\BrainRotRoyale.autotest.rbxlx' | Resolve-Path
$logs = Join-Path $env:LOCALAPPDATA 'Roblox\logs'
$plugDir = Join-Path $env:LOCALAPPDATA 'Roblox\Plugins'
New-Item -ItemType Directory -Force $plugDir | Out-Null
$plug = Join-Path $plugDir 'BRR_AutoRun.lua'
Copy-Item (Join-Path $PSScriptRoot 'BRR_AutoRun.lua') $plug -Force
# Verrou laisse par une session morte : Studio ouvrirait la place en lecture seule.
$verrou = "$place.lock"
if ((Test-Path $verrou) -and -not (Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue)) { Remove-Item $verrou -Force }
$avant = Get-Date
$conv = if ($env:AUTOWIN_CONVERSATION_ID) { $env:AUTOWIN_CONVERSATION_ID } else { 'conv-531' }
& powershell -NoProfile -File (Join-Path $PSScriptRoot '..\..\AutoWinOS\scripts\hdesk-lancer.ps1') `
  -Id brrtest -Executable $studio.FullName -Arguments "`"$place`"" `
  -Travail 'test automatique Brainrot Royale' -Conversation $conv -AttenteSecondes 60 | Out-Null

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
