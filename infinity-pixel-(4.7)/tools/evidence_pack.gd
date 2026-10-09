extends SceneTree

# Empacota evidencias visuais (nao e teste): converte capturas PNG em JPG
# reduzido e monta comparacoes lado a lado (esquerda = antes, direita = depois).
# Uso: godot --headless --script res://tools/evidence_pack.gd -- --list=<arquivo>
# Cada linha do arquivo: "copy|<png>|<jpg>|<escala>" ou
#                        "pair|<png antes>|<png depois>|<jpg>|<escala>"
func _initialize() -> void:
	var list := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--list="): list = arg.trim_prefix("--list=")
	var count := 0
	for line in FileAccess.get_file_as_string(list).split("\n", false):
		var f := line.strip_edges().split("|")
		if f.size() < 4:
			continue
		if f[0] == "copy":
			var img := Image.load_from_file(f[1])
			img.resize(int(img.get_width() * float(f[3])), int(img.get_height() * float(f[3])), Image.INTERPOLATE_LANCZOS)
			img.save_jpg(f[2], 0.86)
			count += 1
		elif f[0] == "pair" and f.size() >= 5:
			var a := Image.load_from_file(f[1])
			var b := Image.load_from_file(f[2])
			var s := float(f[4])
			var w := int(a.get_width() * s)
			var h := int(a.get_height() * s)
			a.resize(w, h, Image.INTERPOLATE_LANCZOS)
			b.resize(w, h, Image.INTERPOLATE_LANCZOS)
			a.convert(Image.FORMAT_RGB8)
			b.convert(Image.FORMAT_RGB8)
			var out := Image.create(w * 2 + 6, h, false, Image.FORMAT_RGB8)
			out.fill(Color(0.06, 0.08, 0.08))
			out.blit_rect(a, Rect2i(0, 0, w, h), Vector2i(0, 0))
			out.blit_rect(b, Rect2i(0, 0, w, h), Vector2i(w + 6, 0))
			out.save_jpg(f[3], 0.86)
			count += 1
	print("[EVIDENCIA] %d imagens" % count)
	quit()
