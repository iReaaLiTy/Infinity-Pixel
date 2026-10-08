param([switch]$Rendered, [string[]]$Suites = @('territory','sky_cycle','build_heal','healing_actions','combat_collect','defense_economy','day_cycle','day_cycle_real','world_layout','player_health','player_facing','physics_contracts','navigation_contracts','acceptance'))
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot
$engine = 'C:\Users\ppfti\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe'
$evidence = Join-Path $projectRoot 'docs/delivery/ac1/evidence'
$mode = if ($Rendered) { 'Windows' } else { 'headless' }
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
$env:APPDATA = Join-Path $env:TEMP 'infinity-ac1-20261007'
$env:LOCALAPPDATA = $env:APPDATA
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$results = @()
foreach ($suite in $Suites) {
    $dest = Join-Path $evidence ($suite + '_' + $mode)
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    $argsList = @('--path', ('"' + $projectRoot + '"'), '--fixed-fps', '60')
    if (-not $Rendered) { $argsList += '--headless' }
    $argsList += @("res://tests/$suite.tscn", '--', ('"--report=' + $dest.Replace('\','/') + '/report.json"'), ('"--output=' + $dest.Replace('\','/') + '/"'), ('"--evidence-dir=' + $dest.Replace('\','/') + '/"'))
    $log = Join-Path $dest 'stdout.log'
    $err = Join-Path $dest 'stderr.log'
    $proc = Start-Process -FilePath $engine -ArgumentList $argsList -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $err -PassThru
    $handle = $proc.Handle
    if (-not $proc.WaitForExit(600000)) { Stop-Process -Id $proc.Id; throw "Timeout $suite" }
    $bad = ($proc.ExitCode -ne 0) -or (Select-String -LiteralPath $log -Pattern 'FAIL:') -or (Select-String -LiteralPath $err -Pattern 'SCRIPT ERROR|SHADER ERROR|Parse Error')
    $results += [pscustomobject]@{suite=$suite; mode=$mode; exit=$proc.ExitCode; passed=(-not $bad)}
    Write-Output "$suite $mode exit=$($proc.ExitCode) passed=$(-not $bad)"
    Select-String -LiteralPath $log -Pattern 'RESULT|HEALING ACTIONS|FAIL:' | ForEach-Object { $_.Line }
}
$results | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence ('summary_' + $mode + '.json')) -Encoding utf8
if ($results.passed -contains $false) { exit 1 }
