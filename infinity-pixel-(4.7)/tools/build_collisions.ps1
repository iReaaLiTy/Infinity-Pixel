# Spec 012: Godot reads both Transform3D and position/scale from saved scenes.
param([string]$GodotPath)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot
if (-not $GodotPath) {
    $config = Get-Content -LiteralPath (Join-Path $projectRoot '.vscode/mcp.json') -Raw | ConvertFrom-Json
    $GodotPath = $config.servers.godot.env.GODOT_PATH
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Pass -GodotPath with the Godot 4.6 executable.' }
$process = Start-Process -FilePath $GodotPath -ArgumentList @('--headless', '--path', ('"' + $projectRoot + '"'), '--script', 'res://tools/build_collisions.gd') -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Collider generation failed: $($process.ExitCode)" }