extends RefCounted

# Configuracoes do jogador (playtest 09/10/2026). So o que funciona e e testado:
# volume geral (barramento Master), musica (Music, via AudioDirector), efeitos
# (SFX), tela cheia e escala da interface. Salvas em user://settings.cfg.

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"master": 1.0,
	"music": 0.55, # o mesmo padrao do AudioDirector
	"sfx": 1.0,
	"fullscreen": false,
	"ui_scale": 1.0,
}
const UI_SCALES := [0.9, 1.0, 1.15]

static var values := DEFAULTS.duplicate()

static func load_settings() -> void:
	values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in DEFAULTS:
		values[key] = cfg.get_value("jogador", key, DEFAULTS[key])

static func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in values:
		cfg.set_value("jogador", key, values[key])
	cfg.save(PATH)

static func set_value(key: String, value, audio: Node, window: Window) -> void:
	values[key] = value
	apply(audio, window)
	save_settings()

static func reset(audio: Node, window: Window) -> void:
	values = DEFAULTS.duplicate()
	apply(audio, window)
	save_settings()

static func _bus_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))

static func apply(audio: Node, window: Window) -> void:
	_bus_volume("Master", float(values.master))
	_bus_volume("SFX", float(values.sfx))
	if audio != null and audio.has_method("set_volume"):
		audio.set_volume(float(values.music))
	if window != null:
		window.content_scale_factor = float(values.ui_scale)
		if DisplayServer.get_name() != "headless":
			var want := DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
			if DisplayServer.window_get_mode() != want:
				DisplayServer.window_set_mode(want)
