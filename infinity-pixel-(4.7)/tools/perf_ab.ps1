param([string]$Before, [string]$Out, [int]$Rounds=2)
# Design 5.0: desempenho ANTES x DEPOIS na mesma sessao, alternando as rodadas
# (depois, antes, depois, antes...) para o estado da maquina pesar igual nos dois.
# -Before = pasta de uma copia do projeto no commit de partida (git archive).
$engine='C:\Users\ppfti\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe'
$after=Split-Path $PSScriptRoot
New-Item -ItemType Directory -Force $Out | Out-Null
$Out=(Resolve-Path $Out).Path # World 6.0: caminho absoluto (o projeto "antes" resolvia o relativo dentro da propria copia)
$env:APPDATA=Join-Path $env:TEMP 'jadefall-perf-ab'
$env:LOCALAPPDATA=$env:APPDATA
for($r=1; $r -le $Rounds; $r++){
 foreach($side in @(@('depois',$after),@('antes',$Before))){
  $json=(Join-Path $Out "$($side[0])_r$r.json").Replace('\','/')
  $p=Start-Process $engine -ArgumentList @('--path',('"'+$side[1]+'"'),'--disable-vsync','--resolution','1920x1080','res://tests/perf_probe.tscn','--',('"--report='+$json+'"'),'--seconds=8','--live') -RedirectStandardOutput (Join-Path $Out "$($side[0])_r$r.log") -RedirectStandardError (Join-Path $Out "$($side[0])_r$r.err") -PassThru
  $p.WaitForExit(900000) | Out-Null
  Write-Output "$($side[0]) r$r exit=$($p.ExitCode)"
 }
}
