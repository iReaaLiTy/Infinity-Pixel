extends SceneTree

# Monta comparacoes ANTES | DEPOIS (esquerda | direita) a partir de capturas
# reais do Godot com o mesmo nome em duas pastas. Saida em JPG reduzido, com
# uma faixa fina separando os lados (ambar = antes, jade = depois).
#   Godot_console --headless --path . --script res://tools/compose_compare.gd --
#       --antes=<pasta> --depois=<pasta> --out=<pasta> [--width=1600]

func _initialize() -> void:
	var a := ""
	var b := ""
	var out := ""
	var width := 1600
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--antes="): a = arg.trim_prefix("--antes=").trim_suffix("/") + "/"
		if arg.begins_with("--depois="): b = arg.trim_prefix("--depois=").trim_suffix("/") + "/"
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
		if arg.begins_with("--width="): width = int(arg.trim_prefix("--width="))
	DirAccess.make_dir_recursive_absolute(out)
	var count := 0
	for file in DirAccess.get_files_at(a):
		if not file.ends_with(".png") or not FileAccess.file_exists(b + file):
			continue
		var left := Image.load_from_file(a + file)
		var right := Image.load_from_file(b + file)
		var half := width / 2
		var h := int(round(half * float(left.get_height()) / left.get_width()))
		left.resize(half, h, Image.INTERPOLATE_LANCZOS)
		right.resize(half, h, Image.INTERPOLATE_LANCZOS)
		left.convert(Image.FORMAT_RGB8)
		right.convert(Image.FORMAT_RGB8)
		var img := Image.create(half * 2 + 6, h + 6, false, Image.FORMAT_RGB8)
		img.fill(Color("10251f"))
		img.fill_rect(Rect2i(0, 0, half + 3, 4), Color("d5a45e"))
		img.fill_rect(Rect2i(half + 3, 0, half + 3, 4), Color("69c7a0"))
		img.blit_rect(left, Rect2i(0, 0, half, h), Vector2i(0, 6))
		img.blit_rect(right, Rect2i(0, 0, half, h), Vector2i(half + 6, 6))
		img.save_jpg(out + file.get_basename() + ".jpg", 0.86)
		count += 1
	print("[COMPARA] %d comparacoes em %s" % [count, out])
	quit()
