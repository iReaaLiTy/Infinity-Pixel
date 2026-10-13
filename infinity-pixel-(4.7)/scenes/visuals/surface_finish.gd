extends RefCounted

# Design Overhaul 5.0 — acabamento de superficie do mundo (so visual).
#
# A arte low-poly e pintada por face (cor por vertice) e nao tem UV. Para a
# pedra, a madeira e o chao nao parecerem plastico liso, os materiais toon
# opacos ganham um GRAO sutil: uma textura de ruido procedural (gerada aqui,
# 128 px, sem arquivo externo e sem licenca de terceiros) aplicada como
# "detail" multiplicativo em projecao triplanar no espaco do mundo — desgaste,
# manchas e variacao de tom que acompanham a superficie sem esticar.
#
# Materiais iguais viram UM so material compartilhado (cache por parametros):
# a passada tambem reduz trocas de material. Ficam de fora: materiais com
# emissao (cristais, runas: o brilho noturno anima por instancia), transparentes,
# sem cor por vertice e tudo dentro de criaturas e do Player (identidade
# visual preservada). Custo: 3 amostras de uma textura de 128 px por pixel.

const GRAIN_SIZE := 128
const GRAIN_LOW := 0.8 # tom mais escuro do grao (multiplica a cor)
const TILE := 0.42 # repeticoes por metro (~2,4 m por ladrilho)
# O grao escurece em media ~10%; a escala do albedo compensa (mesmo tom medio).
const COMPENSATE := 1.1

static var _grain: ImageTexture
static var _cache := {}

## Ruido fractal sem emendas, remapeado para cinza entre GRAIN_LOW e 1.
static func grain() -> ImageTexture:
	if _grain == null:
		var noise := FastNoiseLite.new()
		noise.seed = 2026
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.035
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = 4
		noise.fractal_gain = 0.55
		var img := noise.get_seamless_image(GRAIN_SIZE, GRAIN_SIZE, false, false, 0.1, true)
		img.convert(Image.FORMAT_RGB8)
		for y in GRAIN_SIZE:
			for x in GRAIN_SIZE:
				var v := img.get_pixel(x, y).r
				var g := lerpf(GRAIN_LOW, 1.0, smoothstep(0.15, 0.85, v))
				img.set_pixel(x, y, Color(g, g, g))
		img.generate_mipmaps()
		_grain = ImageTexture.create_from_image(img)
	return _grain

static func eligible(m: Material) -> bool:
	var s := m as StandardMaterial3D
	return s != null and s.vertex_color_use_as_albedo and not s.emission_enabled \
		and s.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not s.detail_enabled

## Versao com grao (compartilhada) de um material toon opaco; os demais voltam iguais.
static func finished(m: Material) -> Material:
	if not eligible(m):
		return m
	var s := m as StandardMaterial3D
	var key := "%s|%.3f|%s|%.3f|%.3f|%d|%d|%s" % [s.albedo_color, s.roughness, s.rim_enabled, s.rim, s.rim_tint,
		s.cull_mode, s.diffuse_mode, s.vertex_color_is_srgb]
	if not _cache.has(key):
		var f := s.duplicate() as StandardMaterial3D
		f.resource_name = "finished_" + s.resource_name
		f.albedo_color = Color(minf(s.albedo_color.r * COMPENSATE, 1.0), minf(s.albedo_color.g * COMPENSATE, 1.0), minf(s.albedo_color.b * COMPENSATE, 1.0))
		f.detail_enabled = true
		f.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		f.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
		f.detail_albedo = grain()
		f.uv2_triplanar = true
		f.uv2_world_triplanar = true
		f.uv2_triplanar_sharpness = 2.0
		f.uv2_scale = Vector3(TILE, TILE, TILE)
		f.set_meta("finished", true)
		_cache[key] = f
	return _cache[key]

## Aplica o acabamento a toda a arte sob `root` (exceto criaturas e Player).
## Devolve quantos materiais foram trocados.
static func apply(root: Node) -> int:
	var count := 0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if _inside_actor(mi, root):
			continue
		if mi.material_override != null:
			var f := finished(mi.material_override)
			if f != mi.material_override:
				mi.material_override = f
				count += 1
		elif mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var sm := mi.get_surface_override_material(i)
				var base := sm if sm != null else mi.mesh.surface_get_material(i)
				if base != null and eligible(base):
					mi.set_surface_override_material(i, finished(base))
					count += 1
	return count

static func _inside_actor(n: Node, root: Node) -> bool:
	var p := n
	while p != null and p != root:
		if p is CharacterBody3D or p.is_in_group("player") or p.is_in_group("wild_dino") or p.get("showcase") != null:
			return true
		p = p.get_parent()
	return false
