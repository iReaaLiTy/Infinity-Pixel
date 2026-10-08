# Spec 015: todas as suites (territory + sky_cycle + regressoes). -Rendered = com janela (+ main_menu).
param([switch]$Rendered, [string[]]$Suites = @('territory','sky_cycle','build_heal','healing_actions','combat_collect','defense_economy','day_cycle','day_cycle_real','world_layout','player_health','player_facing','physics_contracts','navigation_contracts','acceptance'))
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot
$config = Get-Content -LiteralPath (Join-Path $projectRoot '.vscode/mcp.json') -Raw | ConvertFrom-Json
$engine = $config.servers.godot.env.GODOT_PATH
$env:APPDATA = Join-Path $env:TEMP 'infinity-spec015'
$env:LOCALAPPDATA = $env:APPDATA
$evidence = Join-Path $projectRoot 'docs/validation/spec015-evidence'
New-Item -ItemType Directory -Force -Path $evidence,$env:APPDATA | Out-Null
$mode = if ($Rendered) { 'Windows' } else { 'headless' }
if ($Rendered -and $Suites -notcontains 'main_menu') { $Suites += 'main_menu' }
$failedSuites = @()
foreach ($suite in $Suites) {
    $arguments = @('--path', ('"'+$projectRoot+'"'), '--fixed-fps','60')
    if (-not $Rendered) { $arguments += '--headless' }
    $arguments += @("res://tests/$suite.tscn", '--', ('"--report='+$evidence.Replace('\','/')+'/'+$suite+'_'+$mode+'.json"'), '--evidence-dir=user://spec015-acceptance', ('"--output='+$evidence.Replace('\','/')+'/menu/"'))
    $log = Join-Path $evidence ($suite+'_'+$mode+'.log')
    $errors = Join-Path $evidence ($suite+'_'+$mode+'_errors.log')
    $process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $errors -PassThru
    Write-Output "$suite ($mode): pid=$($process.Id)"
    # Cache handle before WaitForExit: otherwise PowerShell can lose ExitCode.
    $handle = $process.Handle
    if (-not $process.WaitForExit(600000)) { Stop-Process -Id $process.Id; throw "Timeout: $suite" }
    Write-Output "$suite ($mode): exit=$($process.ExitCode)"
    Select-String -LiteralPath $log -Pattern 'RESULT|HEALING ACTIONS|FAIL:' | ForEach-Object { $_.Line }
    # Preserve complete stderr in the evidence, including known shutdown warnings.
    Select-String -LiteralPath $errors -Pattern 'SCRIPT ERROR|SHADER ERROR|Parse Error' | ForEach-Object { $_.Line }
    if ($process.ExitCode -ne 0 -or (Select-String -LiteralPath $log -Pattern 'FAIL:') -or (Select-String -LiteralPath $errors -Pattern 'SCRIPT ERROR|SHADER ERROR|Parse Error')) {
        $failedSuites += $suite
    }
}
if ($failedSuites.Count -gt 0) { throw ('Failed suites: ' + ($failedSuites -join ', ')) }
