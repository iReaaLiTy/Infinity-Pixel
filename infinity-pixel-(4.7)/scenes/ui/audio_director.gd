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
	for player in [music, jingle, sfx]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
