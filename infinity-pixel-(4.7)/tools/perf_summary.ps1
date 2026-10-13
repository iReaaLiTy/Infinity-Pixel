param([string[]]$Files)
# Resumo de JSONs do perf_probe: FPS medio, 1% pior e chamadas de desenho por cenario.
foreach($f in $Files){
 $j=Get-Content $f -Raw | ConvertFrom-Json
 Write-Output "== $f ($($j.adapter), $($j.window))"
 foreach($v in $j.views){ Write-Output ("{0,-48} avg {1,6}  1% {2,6}  draws {3,6}  prims {4,7}" -f $v.view,$v.fps_avg,$v.fps_1pct_low,$v.draw_calls_avg,$v.primitives_avg) }
}
