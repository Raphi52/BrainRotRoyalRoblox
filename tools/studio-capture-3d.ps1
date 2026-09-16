# Capture 3D d'une partie de test, hors de la zone visible (voir D:\AutoWinOS\scripts\hors-ecran-capture.ps1).
# Le plugin temporaire tools/BRR_AutoRun.lua lance Play dans la copie de test, puis il est retire.
param([int]$Secondes = 35, [string]$Output = (Join-Path $PSScriptRoot '..\capture-3d.png'), [int]$Rafale = 1, [int]$IntervalleSecondes = 3, [string]$Demarrage = 'Minimized', [ValidateSet('Normal','Suspendu')][string]$Lancement = 'Suspendu')
$ErrorActionPreference = 'Stop'
$studio = (Get-ChildItem 'C:\Program Files (x86)\Roblox\Versions\*\RobloxStudioBeta.exe' | Select-Object -First 1).FullName
$place = (Resolve-Path (Join-Path $PSScriptRoot '..\BrainRotRoyale.autotest.rbxlx')).Path
$plugDir = Join-Path $env:LOCALAPPDATA 'Roblox\Plugins'
New-Item -ItemType Directory -Force $plugDir | Out-Null
$plug = Join-Path $plugDir 'BRR_AutoRun.lua'
Copy-Item (Join-Path $PSScriptRoot 'BRR_AutoRun.lua') $plug -Force
try {
  & powershell -NoProfile -ExecutionPolicy Bypass -File 'D:\AutoWinOS\scripts\hors-ecran-capture.ps1' `
    -Executable $studio -Arguments "`"$place`"" -AttenteSecondes $Secondes -Output $Output -Rafale $Rafale -IntervalleSecondes $IntervalleSecondes -Demarrage $Demarrage -Lancement $Lancement
  $code = $LASTEXITCODE
} finally {
  Remove-Item $plug -ErrorAction SilentlyContinue
}
exit $code
