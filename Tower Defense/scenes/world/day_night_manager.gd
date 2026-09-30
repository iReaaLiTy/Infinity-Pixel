extends Node

# Spec: docs/specs/006-ciclo-dia-noite.md
# RF-AGE-013 — Estados DIA e NOITE (CONFIRMADO)
# RF-AGE-014 — Transicao manual DIA -> NOITE (CONFIRMADO)
# RF-AGE-015 — Retorno ao DIA apos vitoria (CONFIRMADO)
# RF-AGE-016 — Fim de sessao apos derrota (CONFIRMADO)
# RF-AGE-018 — Buff noturno (PROVISORIO)
#
# Autoload (singleton): registrado em project.godot [autoload] como "DayNightManager".

enum State { DAY, NIGHT }

signal day_started
signal night_started
signal game_over

# RF-AGE-018 — hipotese de protototipo: valor inicial 1.30/1.20, teto de
# exploracao 1.50/1.40 nesta rodada. HP/resistencia (1.00) fora de escopo
# neste ciclo — exposto para configuracao futura, ainda sem uso.
@export var night_damage_multiplier := 1.30
@export var night_speed_multiplier := 1.20
@export var night_health_multiplier := 1.00

var state: State = State.DAY
var is_game_over := false
var gameplay_enabled := false

func reset_session(active: bool = false) -> void:
	state = State.DAY
	is_game_over = false
	gameplay_enabled = active

func can_play() -> bool:
	return gameplay_enabled and not is_game_over and not get_tree().paused

func _unhandled_input(event: InputEvent) -> void:
	if can_play() and event.is_action_pressed("start_night") and not event.is_echo():
		start_night()

# RF-AGE-014: transicao DIA -> NOITE sempre manual, nunca por cronometro.
func start_night() -> void:
	if not can_play() or state == State.NIGHT:
		return
	state = State.NIGHT
	print("[DIA/NOITE] Iniciar Noite acionado. Estado: NOITE")
	night_started.emit()

# RF-AGE-015: chamado pelo WaveManager quando a onda e vencida.
func report_wave_victory() -> void:
	if is_game_over or state != State.NIGHT:
		return
	state = State.DAY
	print("[DIA/NOITE] Vitoria da noite. Estado: DIA")
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
