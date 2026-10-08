param([switch]$Rendered, [string[]]$Suites = @('world_layout','player_health','player_facing','physics_contracts','navigation_contracts','acceptance'))
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot
$config = Get-Content -LiteralPath (Join-Path $projectRoot '.vscode/mcp.json') -Raw | ConvertFrom-Json
$engine = $config.servers.godot.env.GODOT_PATH
$env:APPDATA = Join-Path $env:TEMP 'infinity-spec012-appdata'
$env:LOCALAPPDATA = $env:APPDATA
$evidence = Join-Path $projectRoot 'docs/validation/spec012-evidence'
New-Item -ItemType Directory -Force -Path $evidence,$env:APPDATA | Out-Null
$mode = if ($Rendered) { 'Windows' } else { 'headless' }
foreach ($suite in $Suites) {
    $arguments = @('--path', ('"'+$projectRoot+'"'), '--fixed-fps','60')
    if (-not $Rendered) { $arguments += '--headless' }
    $arguments += @("res://tests/$suite.tscn", '--', ('"--report='+$evidence.Replace('\','/')+'/'+$suite+'_'+$mode+'.json"'), '--evidence-dir=user://spec012-acceptance')
    $log = Join-Path $evidence ($suite+'_'+$mode+'.log')
    $errors = Join-Path $evidence ($suite+'_'+$mode+'_errors.log')
    $process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $errors -PassThru
    Write-Output "$suite ($mode): pid=$($process.Id)"
    if (-not $process.WaitForExit(180000)) { Stop-Process -Id $process.Id; throw "Timeout: $suite" }
    Write-Output "$suite ($mode): exit=$($process.ExitCode)"
    Get-Content -LiteralPath $log -Tail 2
    Get-Content -LiteralPath $errors | Where-Object { $_ -notmatch 'certificate store|os_windows.cpp|^\s*$' }
}
