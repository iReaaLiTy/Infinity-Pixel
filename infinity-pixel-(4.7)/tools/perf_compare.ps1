param([string]$Dir)
# Design 5.0: media das rodadas antes_rN.json x depois_rN.json do perf_ab.ps1,
# por cenario: FPS medio, 1% pior e chamadas de desenho (tabela Markdown).
function Load($prefix){
 $acc=@{}
 foreach($f in Get-ChildItem $Dir -Filter "$prefix*.json"){
  $j=Get-Content $f.FullName -Raw | ConvertFrom-Json
  foreach($v in $j.views){
   if(-not $acc.ContainsKey($v.view)){ $acc[$v.view]=@() }
   $acc[$v.view]+=$v
  }
 }
 return $acc
}
$a=Load 'antes_'; $d=Load 'depois_'
Write-Output "| Cenario | FPS medio antes | FPS medio depois | 1% pior antes | 1% pior depois | draws antes | draws depois |"
Write-Output "|---|---|---|---|---|---|---|"
foreach($k in $d.Keys | Sort-Object){
 if(-not $a.ContainsKey($k)){ continue }
 $fa=($a[$k] | Measure-Object fps_avg -Average).Average; $fd=($d[$k] | Measure-Object fps_avg -Average).Average
 $la=($a[$k] | Measure-Object fps_1pct_low -Average).Average; $ld=($d[$k] | Measure-Object fps_1pct_low -Average).Average
 $da=($a[$k] | Measure-Object draw_calls_avg -Average).Average; $dd=($d[$k] | Measure-Object draw_calls_avg -Average).Average
 Write-Output ("| {0} | {1:N1} | {2:N1} | {3:N1} | {4:N1} | {5:N0} | {6:N0} |" -f $k,$fa,$fd,$la,$ld,$da,$dd)
}
