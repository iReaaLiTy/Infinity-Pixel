extends Node

# Spec: docs/specs/006-ciclo-dia-noite.md
# RF-AGE-013 — Estados DIA e NOITE (CONFIRMADO)
# RF-AGE-015 — Retorno ao DIA apos vitoria (CONFIRMADO)
# RF-AGE-016 — Fim de sessao apos derrota (CONFIRMADO)
# RF-AGE-018 — Buff noturno (PROVISORIO)
# Spec: docs/specs/013-relogio-ciclo-ataques-noturnos.md
# RF-CIC-001 a 007 — relogio de gameplay, ciclo automatico, dias/noites (PROVISORIO)
#
# Autoload (singleton): registrado em project.godot [autoload] como "DayNightManager".
# Fonte UNICA de verdade do tempo: estado DIA/NOITE, horario, numero do dia e
# noites defendidas. HUD, WaveManager, IA (dano noturno) e visual so consultam
# isto ou escutam os sinais abaixo.

enum State { DAY, NIGHT }

signal day_started # amanhecer (fim de noite defendida); RF-AGE-015
signal night_started # 18:00; RF-CIC-003
signal night_warning # uma vez por dia, `night_warning_seconds` antes das 18:00
signal game_over

# RF-AGE-018 — hipotese de protototipo: valor inicial 1.30/1.20, teto de
# exploracao 1.50/1.40 nesta rodada. HP/resistencia (1.00) fora de escopo
# neste ciclo — exposto para configuracao futura, ainda sem uso.
@export var night_damage_multiplier := 1.15 # balanceamento 09/10/2026: era 1,30
@export var night_speed_multiplier := 1.20
@export var night_health_multiplier := 1.00

# Spec 013 — relogio. Segundos REAIS de gameplay (pausam com o jogo).
@export var day_duration_seconds := 90.0 # 08:00 -> 18:00 (era 180 s; reduzido apos o 1o playtest)
@export var night_duration_seconds := 45.0 # 18:00 -> 05:59, so o relogio (era 90 s)
@export var night_warning_seconds := 20.0 # aviso "A noite se aproxima" (era 30 s)
@export var night_countdown_seconds := 10.0 # contagem "ANOITECE EM N"
@export var day_start_hour := 8
@export var night_start_hour := 18
@export var dawn_hour := 6
## So para desenvolvimento: N forca a noite. Desligado no jogo normal.
@export var debug_force_night_key := false

var state: State = State.DAY
var is_game_over := false
var gameplay_enabled := false
var day_number := 1 # Dia N e Noite N compartilham o numero
var nights_defended := 0
var phase_elapsed := 0.0 # segundos de gameplay desde o inicio do periodo atual
var _warning_sent := false
## Spec 022 (tutorial): segura SO o relogio (criaturas, torres e combate seguem
## normais) enquanto o jogador aprende. reset_session() sempre zera: sair do
## tutorial ou comecar outra partida nunca deixa o relogio parado.
var clock_hold := false

func reset_session(active: bool = false) -> void:
	state = State.DAY
	is_game_over = false
	gameplay_enabled = active
	day_number = 1
	nights_defended = 0
	phase_elapsed = 0.0
	_warning_sent = false
	clock_hold = false

func can_play() -> bool:
	return gameplay_enabled and not is_game_over and not get_tree().paused

# RF-CIC-001: o relogio so anda com gameplay ativo — pausa, menu e derrota o
# congelam. Usa o delta do jogo, nunca o relogio do sistema.
func _process(delta: float) -> void:
	if not can_play():
		return
	if clock_hold:
		return
	phase_elapsed += delta
	if state == State.DAY:
		if not _warning_sent and seconds_until_night() <= night_warning_seconds:
			_warning_sent = true
			print("[CICLO] A noite se aproxima (%.0f s)." % seconds_until_night())
			night_warning.emit()
		if phase_elapsed >= day_duration_seconds:
			start_night() # RF-CIC-003: 18:00 inicia a noite sozinha

func _unhandled_input(event: InputEvent) -> void:
	if debug_force_night_key and can_play() and event.is_action_pressed("start_night") and not event.is_echo():
		start_night()

# RF-CIC-003: chamado pelo relogio as 18:00 (ou por teste/depuracao).
func start_night() -> void:
	if not can_play() or state == State.NIGHT:
		return
	state = State.NIGHT
	phase_elapsed = 0.0
	print("[DIA/NOITE] Noite %d comecou (18:00). Estado: NOITE" % day_number)
	night_started.emit()

# RF-AGE-015 / RF-CIC-005: chamado pelo WaveManager quando a onda e vencida.
# Unico caminho de NOITE -> DIA: o relogio nunca encerra a noite sozinho.
func report_wave_victory() -> void:
	if is_game_over or state != State.NIGHT:
		return
	state = State.DAY
	nights_defended += 1
	day_number += 1
	phase_elapsed = 0.0
	_warning_sent = false
	print("[DIA/NOITE] Noite defendida (%d). Amanheceu: Dia %d, 08:00. Estado: DIA" % [nights_defended, day_number])
	day_started.emit()

# RF-AGE-016: chamado pela Base quando o HP chega a 0. Fim de sessao definitivo,
# nao retorna a DIA.
func report_defeat() -> void:
	if is_game_over:
		return
	is_game_over = true
	print("[DIA/NOITE] DERROTA — base destruida. Sessao encerrada, reinicie para tentar de novo.")
	game_over.emit()

func is_night() -> bool:
	return state == State.NIGHT and not is_game_over

func is_day() -> bool:
	return state == State.DAY and not is_game_over

# Spec 005 RF-AGE-009: aliados so podem ser reposicionados (F) na preparacao (DIA).
func can_command_allies() -> bool:
	return is_day() and can_play()

func seconds_until_night() -> float:
	return maxf(day_duration_seconds - phase_elapsed, 0.0) if state == State.DAY else 0.0

# RF-CIC-002: minutos desde 00:00. Dia: 08:00 -> 18:00. Noite: 18:00 -> 05:59,
# segurando em 05:59 enquanto a onda nao acaba (o relogio nao vence a noite).
func clock_minutes() -> int:
	if state == State.DAY:
		var day_span := (night_start_hour - day_start_hour) * 60
		var t := minf(phase_elapsed / maxf(day_duration_seconds, .001), 1.0)
		return day_start_hour * 60 + int(t * day_span)
	var night_span := (24 - night_start_hour + dawn_hour) * 60
	var n := minf(phase_elapsed / maxf(night_duration_seconds, .001), 1.0)
	return (night_start_hour * 60 + mini(int(n * night_span), night_span - 1)) % 1440

# Spec 014 RF-CEU-001: o mesmo horario de clock_minutes(), mas continuo (horas
# com fracao), para o visual interpolar sem degraus de minuto. So leitura:
# deriva de state/phase_elapsed, nao e um segundo relogio. Dia 8.0 -> 18.0;
# noite 18.0 -> 29.98 (05:59 do dia seguinte, segurando como clock_minutes).
func clock_hours() -> float:
	if state == State.DAY:
		var t := minf(phase_elapsed / maxf(day_duration_seconds, .001), 1.0)
		return day_start_hour + t * (night_start_hour - day_start_hour)
	var night_span := 24 - night_start_hour + dawn_hour
	var n := minf(phase_elapsed / maxf(night_duration_seconds, .001), 1.0)
	return night_start_hour + minf(n * night_span, night_span - 1.0 / 60.0)

func clock_text() -> String:
	var m := clock_minutes()
	return "%02d:%02d" % [m / 60, m % 60]
