#!/bin/zsh
set -eu
ac1_dir="${0:A:h}"
ac1_godot="${GODOT_BIN:-$HOME/Downloads/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$ac1_godot" ]]; then
  print 'Godot não encontrada. Defina GODOT_BIN com o executável Godot 4.7.2 ou abra o projeto na Godot.'
  exit 1
fi
exec "$ac1_godot" --main-pack "$ac1_dir/InfinityPixel.pck"
