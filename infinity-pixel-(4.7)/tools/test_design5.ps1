param([switch]$Rendered, [string]$Stage='final', [string[]]$Suites=@('ally_combat','attack_direction','build_heal','combat_balance','combat_collect','creature_motion','day_cycle','day_cycle_real','defense_economy','domestication_regression','gameplay_stability','healing_actions','inventory_ui','navigation_contracts','night_enemy_visual','physics_contracts','player_facing','player_health','settings_ui','sky_cycle','territory','tutorial','visual_invariants','visual_overhaul3','visual_overhaul4','world_layout','gameplay5','tower_layout5','design5','acceptance'))
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot
$engine='C:\Users\ppfti\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe'
$mode=if($Rendered){'window'}else{'headless'}
$dest=Join-Path $projectRoot "docs/validation/design-5-evidence/$Stage-$mode"
New-Item -ItemType Directory -Force $dest | Out-Null
$env:APPDATA=Join-Path $env:TEMP 'jadefall-design5'
$env:LOCALAPPDATA=$env:APPDATA
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
if($Rendered -and $Suites.Count -gt 5){$Suites += 'main_menu'}
$results=@()
foreach($suite in $Suites){
 $argsList=@('--path',('"'+$projectRoot+'"'),'--fixed-fps','60','--disable-vsync')
 if(-not $Rendered){$argsList+='--headless'}
 $argsList+=@("res://tests/$suite.tscn",'--',('"--report='+$dest.Replace('\','/')+'/'+$suite+'.json"'))
 $log=Join-Path $dest "$suite.log"
 $err=Join-Path $dest "$suite.err"
 $proc=Start-Process $engine -ArgumentList $argsList -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $err -PassThru
 $handle=$proc.Handle
 $timeout=-not $proc.WaitForExit(180000)
 if($timeout){Stop-Process -Id $proc.Id}
 $bad=$timeout -or ($proc.ExitCode -ne 0) -or (Select-String -LiteralPath $log -Pattern 'FAIL:') -or (Select-String -LiteralPath $err -Pattern 'SCRIPT ERROR|SHADER ERROR|Parse Error')
 $results += [pscustomobject]@{suite=$suite;mode=$mode;exit=$proc.ExitCode;passed=(-not $bad);timeout=$timeout}
 Write-Output "$suite $mode passed=$(-not $bad)"
}
$results | ConvertTo-Json | Set-Content (Join-Path $dest 'summary.json') -Encoding utf8
if($results.passed -contains $false){exit 1}
