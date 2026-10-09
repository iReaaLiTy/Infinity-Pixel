extends RefCounted

# Spec 017A — paleta "Vale de Jade" e material toon da reforma visual.
# Nenhum material da fatia usa cor solta fora daqui. Cores em sRGB (albedo).

# Jade = jogador (cristal, runas, encaixes)
const JADE := Color("3fbf8f")
const JADE_DARK := Color("1e6b57")
const JADE_LIGHT := Color("a8e6cf")
const CRYSTAL_GLOW := Color("7fd8b0")
# Ambar = fogo/interacao
const AMBER := Color("e9a23b")
const AMBER_DARK := Color("b8742a")
const TERRACOTTA := Color("c0533a")
# Grama do patio
const GRASS := Color("6faf5a")
const GRASS_MID := Color("5c9a4c")
const GRASS_DARK := Color("3e7a45")
# Terra batida
const EARTH := Color("c9a66b")
const EARTH_MID := Color("a8854f")
const EARTH_EDGE := Color("8c6a3f")
# Pedra do Refugio
const STONE_LIGHT := Color("b9a58c")
const STONE := Color("8f7e69")
const STONE_DARK := Color("6f6152")
# Madeira
const WOOD := Color("8a5e3b")
const WOOD_DARK := Color("5e3f27")
# Paredoes
const CLIFF_LIGHT := Color("a39c8f")
const CLIFF := Color("857e72")
const CLIFF_DARK := Color("6f6a60")
const CLIFF_TOP := Color("4f8a4a")
# Ameaca noturna (referencia; inimigos fora da 017A)
const NIGHT := [Color("18244d"), Color("25214f"), Color("332452"), Color("6678c8")]

# As cores acima sao o tom DESEJADO NA TELA. Medido na linha de base (12:00,
# GL Compatibility): face ao sol sai ~3,6x mais clara que o albedo em luz
# linear (pedra #7c8980 -> #def2d9 na tela). O material multiplica a cor por
# vertice por este cinza (0,62 sRGB = 0,34 linear) para a paleta nao estourar.
const ALBEDO_SCALE := Color(0.62, 0.62, 0.62)

## Material toon nativo (opcao A da Spec 017A): faixas de luz do proprio
## StandardMaterial3D, sem brilho especular, borda de luz suave e cor por
## vertice (a variacao vem da malha, nao de mais materiais nem texturas).
## `band` = largura da transicao luz/sombra (0 = degrau seco).
static func toon(band := 0.22, rim := 0.18) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = ALBEDO_SCALE
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = band # no modo toon, a rugosidade e a largura da faixa
	m.metallic_specular = 0.0
	if rim > 0.0:
		m.rim_enabled = true
		m.rim = rim
		m.rim_tint = 0.6
	return m

## Toon com emissao (cristal, runas): a energia sobe a noite via night_glow.
static func toon_glow(glow: Color, band := 0.22, rim := 0.35) -> StandardMaterial3D:
	var m := toon(band, rim)
	m.emission_enabled = true
	m.emission = glow
	m.emission_energy_multiplier = 0.3
	return m
