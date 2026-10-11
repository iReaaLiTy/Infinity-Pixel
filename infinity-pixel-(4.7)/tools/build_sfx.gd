extends SceneTree

# Visual Overhaul 4.0 (Fase G) — efeitos sonoros ORIGINAIS, sintetizados aqui
# (seno, ruido filtrado, envelopes), no mesmo espirito de tools/compose_score.py
# (musica). Nenhum sample de terceiros. Grava WAV 16-bit mono 22,05 kHz em
# assets/audio/sfx/; o jogo so carrega os arquivos (nada e sintetizado em jogo).
# Determinista (semente fixa): rodar de novo gera os mesmos arquivos.
#   Godot_console --headless --path . --script res://tools/build_sfx.gd
# Sao placeholders de qualidade: a lista de producao final esta em
# docs/context/audio-auditoria.md.

const RATE := 22050
const OUT := "res://assets/audio/sfx/"
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	rng.seed = 40440
	DirAccess.make_dir_recursive_absolute(OUT)
	_save("ui_hover", ui_hover())
	_save("ui_click", ui_click())
	_save("collect_wood", collect_wood())
	_save("collect_stone", collect_stone())
	_save("build", build())
	_save("tower_shot", tower_shot())
	_save("growl", growl())
	_save("wave_start", wave_start())
	_save("ambience_day", ambience(false))
	_save("ambience_night", ambience(true))
	quit()

# --- utilidades -------------------------------------------------------------------
func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b

static func env(t: float, attack: float, decay: float) -> float:
	## Ataque linear curto e queda exponencial.
	if t < attack:
		return t / maxf(attack, 0.0001)
	return exp(-(t - attack) / maxf(decay, 0.0001))

func noise() -> float:
	return rng.randf_range(-1.0, 1.0)

## Filtro passa-baixa de um polo (estado em `s`).
static func lp(s: Array, x: float, k: float) -> float:
	s[0] += (x - s[0]) * k
	return s[0]

func _save(label: String, b: PackedFloat32Array) -> void:
	var peak := 0.0001
	for v in b:
		peak = maxf(peak, absf(v))
	var gain := 0.7 / peak # normaliza a -3 dBFS; o volume final e do barramento SFX
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		data.encode_s16(i * 2, int(clampf(b[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	var path := OUT + label + ".wav"
	var err := wav.save_to_wav(ProjectSettings.globalize_path(path))
	print("[SFX] %s %.2f s %s" % [path, b.size() / float(RATE), "ok" if err == OK else "ERRO %d" % err])

# --- sons -------------------------------------------------------------------------
## Hover: "tic" de pedra bem curto e baixo.
func ui_hover() -> PackedFloat32Array:
	var b := _buf(0.05)
	var s := [0.0]
	for i in b.size():
		var t := i / float(RATE)
		b[i] = (sin(TAU * 1650.0 * t) * 0.5 + lp(s, noise(), 0.3) * 0.5) * env(t, 0.002, 0.012)
	return b

## Clique: batida de pedra (dois parciais) com transiente.
func ui_click() -> PackedFloat32Array:
	var b := _buf(0.12)
	var s := [0.0]
	for i in b.size():
		var t := i / float(RATE)
		var body := sin(TAU * 540.0 * t) * 0.6 + sin(TAU * 1120.0 * t) * 0.3
		b[i] = body * env(t, 0.002, 0.03) + lp(s, noise(), 0.5) * env(t, 0.0005, 0.006) * 0.6
	return b

## Coleta de madeira: "toc" grave com queda de tom e lascas.
func collect_wood() -> PackedFloat32Array:
	var b := _buf(0.22)
	var s := [0.0]
	var phase := 0.0
	for i in b.size():
		var t := i / float(RATE)
		phase += TAU * lerpf(190.0, 115.0, minf(t / 0.08, 1.0)) / RATE
		var thud := sin(phase) * env(t, 0.002, 0.05)
		var chips := lp(s, noise(), 0.35) * env(t, 0.001, 0.025)
		b[i] = thud * 0.8 + chips * 0.5
	return b

## Coleta de pedra: "clink" com parciais inarmonicos (cristal no minerio).
func collect_stone() -> PackedFloat32Array:
	var b := _buf(0.3)
	var s := [0.0]
	for i in b.size():
		var t := i / float(RATE)
		var ring := sin(TAU * 1380.0 * t) * 0.5 + sin(TAU * 2270.0 * t) * 0.3 + sin(TAU * 3510.0 * t) * 0.15
		b[i] = ring * env(t, 0.001, 0.06) + lp(s, noise(), 0.6) * env(t, 0.0005, 0.01) * 0.7
	return b

## Construcao: tres batidas subindo e um sino jade no fim.
func build() -> PackedFloat32Array:
	var b := _buf(0.9)
	var s := [0.0]
	for i in b.size():
		var t := i / float(RATE)
		var v := 0.0
		for k in 3:
			var t0 := k * 0.12
			if t >= t0:
				var tt := t - t0
				v += sin(TAU * (150.0 + 40.0 * k) * tt) * env(tt, 0.002, 0.045) * 0.7
				v += lp(s, noise(), 0.3) * env(tt, 0.001, 0.012) * 0.3
		if t >= 0.4:
			var tc := t - 0.4
			v += (sin(TAU * 1318.5 * tc) * 0.4 + sin(TAU * 1975.5 * tc) * 0.2) * env(tc, 0.004, 0.22)
		b[i] = v
	return b

## Disparo da torre: "zing" cristalino descendo, com vibrato leve.
func tower_shot() -> PackedFloat32Array:
	var b := _buf(0.26)
	var phase := 0.0
	for i in b.size():
		var t := i / float(RATE)
		var f := lerpf(1900.0, 950.0, minf(t / 0.2, 1.0)) * (1.0 + 0.01 * sin(TAU * 38.0 * t))
		phase += TAU * f / RATE
		b[i] = (sin(phase) * 0.7 + sin(phase * 2.01) * 0.15) * env(t, 0.003, 0.07)
	return b

## Rosnado da preparacao da mordida: grave aspero com tremolo.
func growl() -> PackedFloat32Array:
	var b := _buf(0.45)
	var s := [0.0]
	var s2 := [0.0]
	var phase := 0.0
	for i in b.size():
		var t := i / float(RATE)
		phase += TAU * lerpf(85.0, 70.0, t / 0.45) / RATE
		var saw := fposmod(phase / TAU, 1.0) * 2.0 - 1.0
		var rough := lp(s, noise(), 0.08)
		var trem := 0.65 + 0.35 * sin(TAU * 23.0 * t)
		var shape := smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.3, 0.45, t))
		b[i] = lp(s2, saw * 0.6 + rough * 0.9, 0.18) * trem * shape
	return b

## Inicio da onda: trompa grave de dois tons e um tambor distante.
func wave_start() -> PackedFloat32Array:
	var b := _buf(2.0)
	var s := [0.0]
	for i in b.size():
		var t := i / float(RATE)
		var horn := 0.0
		for h in 5:
			var amp := 1.0 / (h + 1)
			horn += sin(TAU * 110.0 * (h + 1) * t) * amp + sin(TAU * 164.8 * (h + 1) * t) * amp * 0.6
		horn *= smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(1.2, 2.0, t)) * 0.25
		var drum := 0.0
		for k in 2:
			var t0 := 0.15 + k * 0.5
			if t >= t0:
				drum += sin(TAU * 62.0 * (t - t0)) * env(t - t0, 0.003, 0.12)
		b[i] = lp(s, horn, 0.25) + drum * 0.6
	return b

## Ambiente em loop (8 s): vento filtrado; de dia, piados curtos; a noite,
## grilos. Fim e comeco cruzados (emenda sem clique).
func ambience(night: bool) -> PackedFloat32Array:
	var seconds := 8.0
	var b := _buf(seconds)
	var s := [0.0]
	var s2 := [0.0]
	for i in b.size():
		var t := i / float(RATE)
		var gust := 0.55 + 0.45 * sin(TAU * t / seconds) * sin(TAU * 2.0 * t / seconds + 1.0)
		b[i] = lp(s2, lp(s, noise(), 0.02), 0.05) * gust * (2.2 if night else 3.0)
	if night:
		# grilos: portadora ~4,4 kHz em rajadas de 3 pulsos
		for c in 3:
			var f := 4200.0 + 260.0 * c
			var start := rng.randf_range(0.0, 1.0)
			var t0 := start
			while t0 < seconds - 0.3:
				for p in 3:
					var a := int((t0 + p * 0.045) * RATE)
					for k in int(0.03 * RATE):
						if a + k < b.size():
							var tt := k / float(RATE)
							b[a + k] += sin(TAU * f * tt) * sin(PI * tt / 0.03) * 0.12
				t0 += rng.randf_range(0.5, 0.9)
	else:
		# piados: varreduras curtas para cima, espacadas
		var t0 := rng.randf_range(0.4, 1.2)
		while t0 < seconds - 0.5:
			var notes := rng.randi_range(2, 4)
			var base := rng.randf_range(2600.0, 3600.0)
			for n in notes:
				var a := int((t0 + n * 0.11) * RATE)
				var phase := 0.0
				for k in int(0.08 * RATE):
					if a + k < b.size():
						var tt := k / float(RATE)
						phase += TAU * (base + 1400.0 * tt / 0.08) / RATE
						b[a + k] += sin(phase) * sin(PI * tt / 0.08) * 0.1
			t0 += rng.randf_range(1.4, 2.6)
	# emenda: cruza os ultimos 0,5 s com o comeco
	var fade := int(0.5 * RATE)
	for k in fade:
		var w := k / float(fade)
		b[k] = b[k] * w + b[b.size() - fade + k] * (1.0 - w)
	b.resize(b.size() - fade)
	return b
