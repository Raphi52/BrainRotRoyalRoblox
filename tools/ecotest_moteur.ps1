<#
  Rejoue le scenario moteur [ECOTEST] dans Roblox Studio, sur un bureau Windows CACHE, et enregistre
  le passage s'il est VERT (tools/ecotest-dernier.json, lu par tools/test_ecotest_a_jour.py).

  Differences voulues avec tools/studio-run-cache.ps1 : ne refuse pas de tourner quand un autre Studio
  est ouvert, et n'arrete JAMAIS que SON Studio (reconnu au chemin de sa place privee dans la ligne de
  commande) — studio-run-cache.ps1 arrete tous les Studio, y compris ceux d'autres travaux.
  Usage : powershell -NoProfile -ExecutionPolicy Bypass -File tools/ecotest_moteur.ps1 [-Secondes 240]
  Code 0 = vert et enregistre ; 1 = cas en echec ; 3 = pas de fin de scenario dans le journal.
#>
param([int]$Secondes = 240)
$ErrorActionPreference = 'Stop'
$racine = Resolve-Path (Join-Path $PSScriptRoot '..')
$id = "ecotest-$PID"
$place = Join-Path $racine "place-ecotest-$PID.rbxlx"   # ignore par git (place-*.rbxlx)
$plugDir = Join-Path $env:LOCALAPPDATA 'Roblox\Plugins'
$plug = Join-Path $plugDir "BRR_AutoRun-$id.lua"
$studio = (Get-ChildItem 'C:\Program Files\Roblox\Versions\*\RobloxStudioBeta.exe', 'C:\Program Files (x86)\Roblox\Versions\*\RobloxStudioBeta.exe' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
$code = 3
try {
  & python (Join-Path $racine 'build.py') --autotest --ecotest | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "build.py --autotest --ecotest a echoue" }
  Copy-Item (Join-Path $racine 'BrainRotRoyale.autotest.rbxlx') $place -Force
  New-Item -ItemType Directory -Force $plugDir | Out-Null
  Copy-Item (Join-Path $PSScriptRoot 'BRR_AutoRun.lua') $plug -Force
  $depart = Get-Date
  & powershell -NoProfile -ExecutionPolicy Bypass -File 'D:\AutoWinOS\scripts\hdesk-lancer.ps1' `
    -Id $id -Executable $studio -Arguments ('"' + $place + '"') -Travail 'scenario moteur ECOTEST' `
    -Conversation $(if ($env:AUTOWIN_CONVERSATION_ID) { $env:AUTOWIN_CONVERSATION_ID } else { 'conv-873' }) `
    -AttenteSecondes 60 -SurvieSecondes 1 | Out-Null
  $motPlace = [IO.Path]::GetFileName($place)
  $journal = $null
  $fin = (Get-Date).AddSeconds($Secondes)
  while ((Get-Date) -lt $fin) {
    Start-Sleep 5
    $journal = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Roblox\logs') -Filter '*Studio*.log' |
      Where-Object { $_.LastWriteTime -gt $depart } |
      Where-Object { Select-String -Path $_.FullName -Pattern ([regex]::Escape($motPlace)) -Quiet } |
      Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($journal -and (Select-String -Path $journal.FullName -Pattern '\[ECOTEST\] FIN' -Quiet)) { break }
  }
  if (-not $journal -or -not (Select-String -Path $journal.FullName -Pattern '\[ECOTEST\] FIN' -Quiet)) {
    Write-Output "PAS DE FIN : aucun « [ECOTEST] FIN » en $Secondes s pour $motPlace"
  } else {
    $lignes = Select-String -Path $journal.FullName -Pattern '\[ECOTEST\] .* (OK|ECHEC)$' | ForEach-Object { $_.Line }
    $ok = @($lignes | Where-Object { $_ -match ' OK$' }).Count
    $echec = @($lignes | Where-Object { $_ -match ' ECHEC$' }).Count
    $lignes | Where-Object { $_ -match ' ECHEC$' } | ForEach-Object { ($_ -split 'CreatorOutput\] ')[-1] }
    Write-Output "ECOTEST : $ok OK, $echec ECHEC (journal $($journal.Name))"
    if ($echec -eq 0 -and $ok -gt 0) {
      & python (Join-Path $PSScriptRoot 'ecotest_empreinte.py') --ecrire $ok $echec
      $code = 0
    } else { $code = 1 }
  }
} finally {
  # N'arreter QUE notre Studio : celui dont la ligne de commande porte le chemin de NOTRE place.
  Get-CimInstance Win32_Process -Filter "Name='RobloxStudioBeta.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine.Contains([IO.Path]::GetFileName($place)) } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Milliseconds 500
  Remove-Item $plug -ErrorAction SilentlyContinue
  Remove-Item $place, "$place.lock" -ErrorAction SilentlyContinue
}
exit $code
