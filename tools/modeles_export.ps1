# Exporte la GEOMETRIE des modeles retenus (tools/boutique/choix.json) depuis Roblox Studio,
# sur un bureau cache : l'ecran de l'utilisateur ne bouge pas. Aucun script d'asset n'est lu.
# Le plugin ne peut pas ecrire de fichier : il imprime dans le journal Studio, recopie ici.
param([int]$Secondes = 420, [string]$Sortie = "$PSScriptRoot\boutique\export2.log")
$ErrorActionPreference = 'Stop'
$studio = Get-ChildItem 'C:\Program Files (x86)\Roblox\Versions\*\RobloxStudioBeta.exe' | Select-Object -First 1
$place = (Join-Path $PSScriptRoot '..\BrainRotRoyale.autotest.rbxlx' | Resolve-Path).Path
$logs = Join-Path $env:LOCALAPPDATA 'Roblox\logs'
$plugDir = Join-Path $env:LOCALAPPDATA 'Roblox\Plugins'
New-Item -ItemType Directory -Force $plugDir | Out-Null
$choix = Get-Content (Join-Path $PSScriptRoot 'boutique\choix.json') -Raw
$lua = (Get-Content (Join-Path $PSScriptRoot 'BRR_Modeles_export.lua') -Raw).Replace('__CHOIX__', "game:GetService('HttpService'):JSONDecode([[$choix]])")
$plug = Join-Path $plugDir 'BRR_Modeles_export.lua'
# Set-Content -Encoding UTF8 pose un BOM ; Luau refuse le plugin (« got Unicode character U+feff », mesure 2026-09-20).
[IO.File]::WriteAllText($plug, $lua, (New-Object Text.UTF8Encoding $false))
# Verrou laisse par une session morte : Studio ouvrirait la place en lecture seule.
$verrou = "$place.lock"
if ((Test-Path $verrou) -and -not (Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue)) { Remove-Item $verrou -Force }
$avant = Get-Date
& powershell -NoProfile -File 'D:\AutoWinOS\scripts\hdesk-lancer.ps1' `
  -Id run-run-7dd6af999f50-1 -Executable $studio.FullName -Arguments "`"$place`"" `
  -Travail 'export geometrie modeles Brainrot Royale' -AttenteSecondes 90 | Out-Null
$fin = (Get-Date).AddSeconds($Secondes)
$log = $null
while ((Get-Date) -lt $fin) {
  Start-Sleep 5
  $log = Get-ChildItem $logs -Filter '*Studio*.log' | Where-Object { $_.LastWriteTime -gt $avant } |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($log -and (Select-String -Path $log.FullName -Pattern '\[BRRMOD\] FIN' -Quiet)) { break }
}
Get-Process RobloxStudioBeta, RobloxCrashHandler -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Remove-Item $plug -ErrorAction SilentlyContinue
if (-not $log) { Write-Output 'AUCUN_JOURNAL'; exit 3 }
(Select-String -Path $log.FullName -Pattern '\[BRRMOD\]|\[BRRMODP\]').Line | Set-Content -Path $Sortie -Encoding UTF8
Write-Output "journal=$($log.Name) lignes=$((Get-Content $Sortie).Count)"
if (-not (Select-String -Path $Sortie -Pattern '\[BRRMOD\] FIN' -Quiet)) { exit 4 }
