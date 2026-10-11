extends Node

var music: AudioStreamPlayer
var jingle: AudioStreamPlayer
var sfx: AudioStreamPlayer
var fade: Tween
var current := ""
var volume := .55
var last_nonzero_volume := .55
var muted := false
var paused_mix := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	add_child(music)
	jingle = AudioStreamPlayer.new()
	jingle.bus = "Music"
	jingle.volume_db = -12
	add_child(jingle)
	sfx = AudioStreamPlayer.new()
	sfx.bus = "SFX"
	sfx.volume_db = -18
	add_child(sfx)
	add_to_group("audio_director")
	_setup_sfx()
	set_volume(volume)

func set_volume(value: float) -> void:
	volume = value
	if value > 0.0:
		last_nonzero_volume = value # restaurado ao desligar o mudo pelo icone do menu
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(volume, .0001)))

func set_muted(value: bool) -> void:
	muted = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), value)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), value)

func set_paused_mix(value: bool) -> void:
	paused_mix = value
	# Music continues softly through pause; world SFX stop with the world.
	music.volume_db = -22 if value else -14

func change_music(mode: String) -> void:
	paused_mix = false
	jingle.stop()
	if current == mode and music.playing:
		music.volume_db = -14
		return
	current = mode
	if fade != null and fade.is_valid(): fade.kill()
	fade = create_tween()
	fade.tween_property(music, "volume_db", -55.0, .35)
	fade.tween_callback(func():
		music.stop()
		var stream = load("res://assets/audio/refugio_%s.wav" % mode).duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		music.stream = stream
		music.play()
	)
	fade.tween_property(music, "volume_db", -14.0, .65)

func result(won: bool) -> void:
	change_music("calm")
	jingle.stream = load("res://assets/audio/victory.wav" if won else "res://assets/audio/defeat.wav")
	jingle.play()

func effect(bond: bool = false) -> void:
	sfx.stream = load("res://assets/audio/bond.wav" if bond else "res://assets/audio/strike.wav")
	sfx.play()

func _exit_tree() -> void:
	if fade != null and fade.is_valid(): fade.kill()
	if _amb_fade != null and _amb_fade.is_valid(): _amb_fade.kill()
	for player in [music, jingle, sfx, ambient] + _sfx_players.values():
		if is_instance_valid(player):
			player.stop()
			player.stream = null

# --- 4.0 (Fase G): efeitos nomeados e ambiente ---------------------------------
# Sons originais sintetizados por tools/build_sfx.gd (assets/audio/sfx). Cada
# efeito tem volume proprio e intervalo minimo (varias torres ou invasores ao
# mesmo tempo nao viram metralhadora). Todos no barramento SFX.
const SFX := {
	"ui_hover": [-30.0, 0.04], "ui_click": [-20.0, 0.05],
	"collect_wood": [-17.0, 0.06], "collect_stone": [-18.0, 0.06],
	"build": [-15.0, 0.25], "tower_shot": [-27.0, 0.14], "growl": [-23.0, 0.35],
	"wave_start": [-13.0, 1.5],
}
const AMBIENCE_DB := -27.0
var _sfx_players := {}
var _sfx_last := {}
var ambient: AudioStreamPlayer
var ambience := ""
var _amb_fade: Tween

func _setup_sfx() -> void:
	for label in SFX:
		var path := "res://assets/audio/sfx/%s.wav" % label
		if not ResourceLoader.exists(path):
			continue # sem o arquivo, o efeito fica mudo (nada quebra)
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.stream = load(path)
		p.volume_db = SFX[label][0]
		p.max_polyphony = 3
		add_child(p)
		_sfx_players[label] = p
	ambient = AudioStreamPlayer.new()
	ambient.bus = "SFX"
	ambient.volume_db = -60.0
	add_child(ambient)
	# Todo botao do jogo (menu, telas, mochila, HUD) ganha hover e clique.
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta("silent"):
		node.mouse_entered.connect(func(): if not node.disabled: play("ui_hover"))
		node.pressed.connect(play.bind("ui_click"))

## Toca um efeito nomeado (ignora se tocou ha menos que o intervalo minimo).
func play(label: String) -> void:
	var p: AudioStreamPlayer = _sfx_players.get(label)
	if p == null or muted:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_sfx_last.get(label, -10.0)) < SFX[label][1]:
		return
	_sfx_last[label] = now
	p.play()

## Ambiente em loop: "day" (vento e piados), "night" (grilos) ou "" (nenhum).
func set_ambience(mode: String) -> void:
	if mode == ambience or ambient == null:
		return
	ambience = mode
	if _amb_fade != null and _amb_fade.is_valid(): _amb_fade.kill()
	_amb_fade = create_tween()
	_amb_fade.tween_property(ambient, "volume_db", -60.0, 0.6)
	if mode == "":
		_amb_fade.tween_callback(ambient.stop)
		return
	_amb_fade.tween_callback(func():
		var path := "res://assets/audio/sfx/ambience_%s.wav" % mode
		if not ResourceLoader.exists(path):
			return
		var stream: AudioStreamWAV = load(path).duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		ambient.stream = stream
		ambient.play()
	)
	_amb_fade.tween_property(ambient, "volume_db", AMBIENCE_DB, 1.4)
