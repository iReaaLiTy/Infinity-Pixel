extends CharacterBody3D

# Spec: docs/specs/002-dinossauro-selvagem.md
# RF-AGE-003 — Spawn e avanco ate o territorio (CONFIRMADO)
# RF-AGE-004 — Deteccao e ataque corpo a corpo (PROVISORIO)
# Spec: docs/specs/003-domesticacao.md — RF-AGE-017 (is_domesticable)
# Spec: docs/specs/004-dinossauro-domesticado.md — RF-AGE-007/008 (aliado)
# Spec: docs/specs/006-ciclo-dia-noite.md — RF-AGE-018 (buff noturno)

const MAX_HP := 80.0 # RF-AGE-004 valor inicial. Teto de teste: ate 120.
const BASE_ATTACK_DAMAGE := 15.0 # RF-AGE-004 valor inicial. Teto de teste: ate 25.
const ATTACK_COOLDOWN := 1.0 # RF-AGE-004 valor inicial. Minimo de teste: 0,6 s.
const DETECTION_RANGE := 8.0 # RF-AGE-004 valor inicial. Teto de teste: ate 12.
const BASE_SPEED := 4.0 # RF-AGE-004 valor inicial. Teto de teste: 5,5 (sempre < 6 do jogador).
# NAO esta na Spec 002: alcance do golpe do inimigo. Provisorio, espelha os 2 m do jogador.
const ATTACK_REACH := 2.0
const TERRITORY_ARRIVAL_DISTANCE := 1.5 # distancia em que considera ter "chegado" ao territorio
const GRAVITY := 9.8
# Spec 003 RF-AGE-005 valor inicial: 30% de vida restante. Faixa de teste: 20% a 40%.
const DOMESTICATION_HP_FRACTION := 0.3
# RF-AGE-008 valor inicial: 8 m de raio de defesa a partir do ponto de "ficar".
const DEFENSE_RADIUS := 8.0
# NAO esta na Spec 004: distancia em que o aliado para de seguir o jogador. Provisorio.
const ALLY_FOLLOW_STOP_DISTANCE := 2.5
# NAO esta na Spec 004: alcance para o comando "ficar" atingir o aliado. Provisorio,
# reaproveita a mesma ordem de grandeza do alcance de domesticacao (3 m).
const ALLY_COMMAND_RANGE := 3.0

# Spec: docs/specs/010-navegacao-avoidance-criaturas.md (RF-NAV-001 a 006, PROVISORIO).
# Valores de tuning da navegacao; nenhum altera velocidade, dano ou alcance.
const REPATH_DISTANCE := 0.5 # so pede caminho novo se o destino andar mais que isso
const REPATH_MIN_INTERVAL := 0.2 # e no maximo 5 pedidos por segundo
const RETARGET_INTERVAL := 0.15 # busca de alvo por grupos, em vez de a cada quadro
const SLOT_ARRIVAL := 0.25 # chegou ao slot (anel da base 1,2 + 0,25 < 1,5 m de chegada)
const ALLY_SLOT_RESUME := 1.0 # aliado parado so volta a andar se o slot se afastar disso
const SLOT_REVIEW_INTERVAL := 0.5 # revisao de slot (anel de espera / inalcancavel)
const STUCK_CHECK_INTERVAL := 1.0
const STUCK_MIN_PROGRESS := 0.25 # andou menos que isso em 1 s querendo andar = preso
const SLOT_SETTLE_RADIUS := 1.0 # preso a ate 1 m do destino = "perto o suficiente"
const FACE_MIN_SPEED := 0.5 # abaixo disso nao vira o corpo (evita giro com avoidance)

const ApproachSlots := preload("res://scenes/enemies/approach_slots.gd") # Spec 010

enum AllyState { FOLLOWING, STAYING }

# Usados pelo WaveManager para saber quando um inimigo da onda deixou de ser ameaca.
signal died(dino: Node3D)
signal domesticated(dino: Node3D)
# F recusado (noite/fim de jogo). Para feedback na interface.
signal command_rejected

@export var is_domesticable := true # RF-AGE-017: propriedade explicita, nao depende do nome do node/cena.
# AC1 (GDD secoes 3 e 6): encontro diurno domesticavel. Territorial = nao avanca
# ate a base; so persegue alvos dentro de leash_radius do ponto de origem e depois
# volta para ele. Inimigos de onda/teste usam o padrao (false) e nao mudam.
@export var territorial := false
@export var leash_radius := 12.0 # NAO esta em Spec: provisorio para o encontro AC1.

@onready var hp_label: Label3D = $HpLabel3D
@onready var prompt_label: Label3D = $PromptLabel3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var hp: float = MAX_HP
var is_domesticated := false
var is_being_domesticated := false # RF-AGE-006: true durante a canalizacao (segurando E)
var ally_state: AllyState = AllyState.FOLLOWING # RF-AGE-007
var _stay_position: Vector3
var _territory: Node3D
var _target: Node3D
var _attack_cooldown_left := 0.0
var _arrived := false
var _attack_announced := false # log "[ALIADO] Atacando" uma vez por alvo
var _returning_to_post := false # log "[ALIADO] Retornando" uma vez apos cada combate
var home_position: Vector3 # origem do encontro territorial (capturada no _ready)

# Spec 010 — estado da navegacao
var _player_ref: Node3D
var _frame_delta := 0.0
var _nav_available := false
var _nav_check_left := 0.0
var _nav_goal := Vector3.INF
var _repath_left := 0.0
var _retarget_left := 0.0
var _slot_target: Node3D
var _slot_kind := &""
var _slot_review_left := 0.0
var _stuck_left := STUCK_CHECK_INTERVAL
var _stuck_origin := Vector3.ZERO
var _stuck_count := 0 # verificacoes seguidas sem progresso
var _settled_goal := Vector3.INF # destino bloqueado aceito como "perto o suficiente"
var _avoidance_pending := false
var _face_target: Node3D # alvo dentro do alcance: o corpo olha para ele
var _ally_moving := false # histerese do seguir

func _ready() -> void:
	add_to_group("damageable") # ADR 0001
	add_to_group("wild_dino")
	home_position = global_position
	_territory = get_tree().get_first_node_in_group("territory") as Node3D
	if _territory == null and not territorial:
		push_warning("WildDino: nenhum no no grupo 'territory' na cena; o dinossauro nao tem para onde avancar.")
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	_update_label()

func _exit_tree() -> void:
	_release_slot() # RF-NAV-003: morte/remocao libera o slot para outra criatura

func _physics_process(delta: float) -> void:
	if not DayNightManager.can_play():
		return
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_frame_delta = delta
	_repath_left = maxf(_repath_left - delta, 0.0)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta

	if is_domesticated:
		_process_ally(delta)
		return

	if is_being_domesticated:
		# RF-AGE-006: enquanto o Player canaliza a domesticacao, o WildDino fica
		# parado e nao ataca (nem persegue), mas continua vivo e sem queue_free().
		# Spec 010: sem avoidance aqui, para nao ser empurrado durante o canal.
		_hold_still()
		return

	# Spec 010: busca por grupos a cada RETARGET_INTERVAL, nao a cada quadro.
	_retarget_left -= delta
	if _retarget_left <= 0.0 or (_target != null and not is_instance_valid(_target)):
		_retarget_left = RETARGET_INTERVAL
		_target = _find_nearest_target()

	var desired := Vector3.ZERO
	_face_target = null
	if _target != null:
		# RF-AGE-004: ameaca detectada — deixa de seguir para o territorio e vai ate o alvo.
		# RF-NAV-003: cada perseguidor vai para o proprio slot ao redor do alvo.
		var to_target := _flat_offset(_target.global_position)
		desired = _approach(_target, &"attack", _current_speed(), ATTACK_REACH)
		if to_target.length() <= ATTACK_REACH:
			_face_target = _target
			_try_attack(_target)
		_arrived = false
	elif territorial:
		# Encontro diurno: sem alvo, volta ao ponto de origem e fica ali (RF-NAV-002).
		_release_slot()
		desired = _navigate_to(home_position, _current_speed(), 0.5)
	elif _territory != null:
		# RF-NAV-004: cada inimigo vai para o proprio slot ao redor do refugio.
		desired = _approach(_territory, &"base", _current_speed(), TERRITORY_ARRIVAL_DISTANCE)
		var to_territory := _flat_offset(_territory.global_position)
		if to_territory.length() > TERRITORY_ARRIVAL_DISTANCE:
			_arrived = false
		else:
			if not _arrived:
				_arrived = true
				print("%s chegou ao territorio." % name)
			# RF-AGE-012: dinossauro que chega a base passa a ataca-la (mesmo padrao
			# de cooldown do ataque ao jogador, reaproveitando _try_attack).
			_face_target = _territory
			_try_attack(_territory)

	_drive(desired)

# Spec 004 RF-AGE-008: o aliado mantem o mesmo HP/atributos de selvagem e pode
# ser ferido por hostis. O jogador nao fere aliados (filtro em player.gd).
func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return # ja derrotado neste frame (queue_free pendente)
	$Visual.flash()
	hp -= amount
	if is_domesticated:
		print("[ALIADO] recebeu %.0f de dano. HP: %.0f/%.0f" % [amount, maxf(hp, 0.0), MAX_HP])
	else:
		print("%s recebeu %.0f de dano. HP: %.0f/%.0f" % [name, amount, maxf(hp, 0.0), MAX_HP])
	_update_label()
	if hp <= 0.0:
		if is_domesticated:
			print("[ALIADO] %s foi derrotado" % name)
			remove_from_group("domesticated") # hostis param de mira-lo ja neste frame
		else:
			print("%s foi derrotado." % name)
		died.emit(self)
		queue_free()

# RF-AGE-005 + RF-AGE-017: precisa de vida no limiar ou abaixo E ser de uma
# especie/variante domesticavel (`is_domesticable`), consultado diretamente
# aqui — nunca por nome de node ou de cena.
func can_be_domesticated() -> bool:
	return is_domesticable and not is_domesticated and hp > 0.0 and hp <= MAX_HP * DOMESTICATION_HP_FRACTION

# RF-AGE-006: chamado quando a canalizacao termina. Desde a Spec 013C a vida volta
# ao maximo (antes era mantida).
func domesticate() -> void:
	if is_domesticated:
		return # transicao unica: chamar de novo nao cura nem emite sinais
	# Spec 013C (RF-CMB-003): a domesticacao concluida restaura a vida inteira,
	# uma unica vez (aqui, na transicao selvagem -> aliado). Depois o aliado pode
	# voltar a perder vida normalmente; nao ha regeneracao continua.
	hp = MAX_HP
	is_being_domesticated = false
	is_domesticated = true
	ally_state = AllyState.FOLLOWING # RF-AGE-007: comeca seguindo o jogador
	_release_slot() # RF-NAV-003: deixa o slot de ataque ao redor do jogador
	_target = null
	print("%s foi domesticado com %.0f/%.0f HP (nao removido)." % [name, hp, MAX_HP])
	print("[DOMESTICACAO] Estado: DOMESTICADO")
	print("[ALIADO] %s domesticado" % name)
	print("[ALIADO] Modo: SEGUINDO")
	remove_from_group("wild_dino")
	add_to_group("domesticated") # alvo dos selvagens, aliado do jogador (Spec 004)
	name = "DinoDomesticado"
	prompt_label.text = ""
	$Visual.set_ally()
	get_tree().call_group("audio_director", "effect", true)
	_update_label()
	domesticated.emit(self)

func set_prompt(text: String) -> void:
	prompt_label.text = text

# RF-AGE-007/RF-AGE-008: comportamento de aliado (seguir/ficar + defesa por area).
func _process_ally(delta: float) -> void:
	var player := _find_player()

	# F alterna seguir/ficar. is_action_just_pressed garante uma unica troca por pressao.
	if player != null and Input.is_action_just_pressed("command_stay") \
			and _flat_offset(player.global_position).length() <= ALLY_COMMAND_RANGE:
		if not DayNightManager.can_command_allies():
			# Spec 005 RF-AGE-009: com a onda em andamento nao e permitido reposicionar.
			print("[ALIADO] Comando F ignorado: reposicionar nao e permitido durante a noite/fim de jogo.")
			command_rejected.emit()
		else:
			_target = null
			_returning_to_post = false
			_release_slot() # RF-NAV-005: o slot de seguir/defesa nao vale no novo modo
			if ally_state == AllyState.FOLLOWING:
				ally_state = AllyState.STAYING
				_stay_position = global_position
				print("[ALIADO] Modo alterado: FICAR")
				print("[ALIADO] Posição de defesa definida: %s" % _stay_position)
			else:
				ally_state = AllyState.FOLLOWING
				print("[ALIADO] Modo alterado: SEGUINDO")

	match ally_state:
		AllyState.FOLLOWING:
			_ally_follow(player)
		AllyState.STAYING:
			_ally_defend(delta)

# RF-NAV-005: cada aliado tem o proprio slot ao redor do Player. Com histerese:
# parado no slot, so volta a andar quando o slot se afasta ALLY_SLOT_RESUME.
func _ally_follow(player: Node3D) -> void:
	_face_target = null
	var desired := Vector3.ZERO
	if player != null:
		var goal: Variant = _slot_goal(player, &"follow")
		var stop := SLOT_ARRIVAL
		if goal == null:
			# Todos os slots ocupados: comportamento anterior (para a 2,5 m do Player).
			goal = player.global_position
			stop = ALLY_FOLLOW_STOP_DISTANCE
		var dist := _flat_offset(goal).length()
		if _ally_moving and dist <= stop:
			_ally_moving = false
		elif not _ally_moving and dist > maxf(ALLY_SLOT_RESUME, stop):
			_ally_moving = true
		if _ally_moving:
			desired = _navigate_to(goal, BASE_SPEED, stop)
	_drive(desired)

func _ally_defend(delta: float) -> void:
	# Alvo atual deixa de valer se morreu, foi domesticado (saiu de "wild_dino") ou
	# saiu do raio de defesa em volta do ponto de "ficar" (RF-AGE-008).
	if _target != null:
		if not is_instance_valid(_target):
			_target = null # derrotado (queue_free)
		elif not _is_valid_defense_target(_target):
			if _target.is_in_group("wild_dino"):
				print("[ALIADO] Alvo saiu da área - retornando")
			_target = null
	_retarget_left -= delta
	if _target == null and _retarget_left <= 0.0:
		_retarget_left = RETARGET_INTERVAL # Spec 010: busca por grupos limitada
		_target = _find_nearest_wild_dino_in_radius(_stay_position, DEFENSE_RADIUS)
		if _target != null:
			print("[ALIADO] Inimigo detectado: %s" % _target.name)
			_attack_announced = false
			_returning_to_post = true

	var desired := Vector3.ZERO
	_face_target = null
	if _target != null:
		# RF-NAV-005: aliados que defendem dividem os slots ao redor do hostil.
		var to_target := _flat_offset(_target.global_position)
		desired = _approach(_target, &"attack", BASE_SPEED, ATTACK_REACH)
		if to_target.length() <= ATTACK_REACH:
			_face_target = _target
			if not _attack_announced:
				_attack_announced = true
				print("[ALIADO] Atacando: %s" % _target.name)
			_try_attack(_target)
	else:
		_release_slot()
		var to_stay := _flat_offset(_stay_position)
		if to_stay.length() > 0.3:
			if _returning_to_post:
				_returning_to_post = false
				print("[ALIADO] Retornando à posição de defesa")
			desired = _navigate_to(_stay_position, BASE_SPEED, 0.3)
		else:
			_returning_to_post = false

	_drive(desired)

func _is_valid_defense_target(target: Node3D) -> bool:
	return target != self and target.is_in_group("wild_dino") \
		and _flat_offset_from(_stay_position, target.global_position).length() <= DEFENSE_RADIUS

func _find_player() -> Node3D:
	if not is_instance_valid(_player_ref) or not _player_ref.is_inside_tree():
		_player_ref = get_tree().get_first_node_in_group("player") as Node3D
	return _player_ref

# ---------------------------------------------------------------------------
# Spec 010 — navegacao, slots e avoidance
# ---------------------------------------------------------------------------

# RF-NAV-003: vai ate o slot proprio ao redor de `target`. Sem slot livre (aneis
# cheios), cai no comportamento anterior: ir direto ao alvo e parar no alcance.
func _approach(target: Node3D, kind: StringName, speed: float, fallback_stop: float) -> Vector3:
	var goal: Variant = _slot_goal(target, kind)
	if goal == null:
		return _navigate_to(target.global_position, speed, fallback_stop)
	return _navigate_to(goal, speed, SLOT_ARRIVAL)

# Reserva/mantem o slot e devolve o ponto dele (ou null sem vaga).
func _slot_goal(target: Node3D, kind: StringName) -> Variant:
	if _slot_target != target or _slot_kind != kind:
		_release_slot()
		_slot_target = target
		_slot_kind = kind
		_nav_goal = Vector3.INF
		_slot_review_left = SLOT_REVIEW_INTERVAL
	var map := nav_agent.get_navigation_map()
	var slot: Variant = ApproachSlots.claim(target, kind, self, map if _nav_ready() else RID())
	_slot_review_left -= _frame_delta
	if slot != null and _slot_review_left <= 0.0:
		_slot_review_left = SLOT_REVIEW_INTERVAL
		if slot.x > 0:
			slot = ApproachSlots.upgrade(target, kind, self, map) # anel de espera -> anel 0
		elif _nav_ready() and _nav_goal != Vector3.INF and not nav_agent.is_target_reachable():
			# RF-NAV-006: slot ficou atras de obstaculo; troca por outro e recalcula.
			slot = ApproachSlots.claim(target, kind, self, map, slot)
			_nav_goal = Vector3.INF
	if slot == null:
		return null
	return ApproachSlots.slot_position(target, kind, slot)

func _release_slot() -> void:
	if is_instance_valid(_slot_target):
		ApproachSlots.release(_slot_target, _slot_kind, self)
	_slot_target = null
	_slot_kind = &""

# RF-NAV-002: velocidade desejada (so XZ) seguindo o caminho da navmesh. Sem
# navmesh disponivel (cena sem NavigationRegion3D), usa a IA direta anterior.
func _navigate_to(goal: Vector3, speed: float, stop_distance: float) -> Vector3:
	var flat := _flat_offset(goal)
	if flat.length() <= stop_distance:
		return Vector3.ZERO
	if _settled_goal != Vector3.INF:
		# Ver _update_stuck: parado perto de um destino bloqueado ate ele mudar.
		if _settled_goal.distance_to(goal) < REPATH_DISTANCE and flat.length() <= SLOT_SETTLE_RADIUS:
			return Vector3.ZERO
		_settled_goal = Vector3.INF
	if not _nav_ready():
		return flat.normalized() * speed
	# Caminho novo so quando o destino anda de verdade (e com intervalo minimo).
	if _nav_goal == Vector3.INF or (_repath_left <= 0.0 and _nav_goal.distance_to(goal) > REPATH_DISTANCE):
		# O alvo vai na altura da superficie da navmesh (que fica acima do chao
		# fisico); sem isso a diferenca de altura faz o agente julgar todo destino
		# "inalcancavel" (target_desired_distance e medido em 3D).
		var surface := NavigationServer3D.map_get_closest_point(nav_agent.get_navigation_map(), goal)
		nav_agent.target_position = Vector3(goal.x, surface.y, goal.z)
		_nav_goal = goal
		_repath_left = REPATH_MIN_INTERVAL
	if nav_agent.is_navigation_finished():
		return Vector3.ZERO # chegou ao ponto alcancavel mais proximo do destino
	var step := _flat_offset(nav_agent.get_next_path_position())
	if step.length() < 0.01:
		return Vector3.ZERO
	return step.normalized() * speed

func _nav_ready() -> bool:
	if _nav_available:
		return true
	_nav_check_left -= _frame_delta
	if _nav_check_left > 0.0:
		return false
	_nav_check_left = 1.0 # mapa sem regiao: reconfere 1x por segundo, nunca por quadro
	var map := nav_agent.get_navigation_map()
	_nav_available = map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0 \
		and not NavigationServer3D.map_get_regions(map).is_empty()
	return _nav_available

# RF-NAV-003: avoidance do NavigationAgent3D. A velocidade desejada vai para o
# servidor; move_and_slide roda no retorno (velocity_computed), com a gravidade
# ja calculada em _physics_process. Sem navmesh, move direto como antes.
func _drive(desired: Vector3) -> void:
	_update_stuck(desired)
	if desired.length_squared() < 0.0001:
		# Parado no slot/posto: fica firme (sem ser empurrado pelo avoidance) e os
		# outros contornam. Evita tremedeira e que alguem seja tirado do alcance.
		_hold_still()
		return
	if _nav_ready() and nav_agent.avoidance_enabled:
		nav_agent.max_speed = maxf(_current_speed(), BASE_SPEED)
		_avoidance_pending = true
		nav_agent.velocity = Vector3(desired.x, 0.0, desired.z)
	else:
		_apply_velocity(desired)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if not _avoidance_pending:
		return # quadro sem pedido (pausa, fim de jogo, canalizacao): nao move
	_avoidance_pending = false
	_apply_velocity(safe_velocity)

func _apply_velocity(horizontal: Vector3) -> void:
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if _face_target != null and is_instance_valid(_face_target):
		_face(_flat_offset(_face_target.global_position))
	elif Vector2(horizontal.x, horizontal.z).length() > FACE_MIN_SPEED:
		_face(Vector3(horizontal.x, 0.0, horizontal.z))
	move_and_slide()

# Parado sem avoidance (slot/posto/canalizacao): os outros continuam desviando dele.
func _hold_still() -> void:
	_avoidance_pending = false
	if _nav_ready():
		nav_agent.velocity = Vector3.ZERO
	velocity.x = 0.0
	velocity.z = 0.0
	if _face_target != null and is_instance_valid(_face_target):
		_face(_flat_offset(_face_target.global_position))
	move_and_slide()

# RF-NAV-006: querendo andar e sem progresso por STUCK_CHECK_INTERVAL = preso.
# Recalcula o caminho e, se estava indo para um slot, troca de slot.
func _update_stuck(desired: Vector3) -> void:
	if desired.length() < 0.1:
		_stuck_left = STUCK_CHECK_INTERVAL
		_stuck_origin = global_position
		return
	_stuck_left -= _frame_delta
	if _stuck_left > 0.0:
		return
	if _flat_offset(_stuck_origin).length() >= STUCK_MIN_PROGRESS:
		_stuck_count = 0
	elif _nav_goal != Vector3.INF and _flat_offset(_nav_goal).length() <= SLOT_SETTLE_RADIUS \
			and (_slot_target == null or _slot_kind == &"follow"):
		# Bloqueado ja perto do destino (slot de seguir/posto ocupado por outra
		# criatura parada): aceita "perto o suficiente" e para, sem trocar de slot
		# nem oscilar. Slots de ataque/base nao: parar a 1 m poderia ficar fora
		# do alcance do golpe, entao esses trocam de slot (abaixo).
		_settled_goal = _nav_goal
	else:
		_stuck_count += 1
		if _stuck_count == 1: # um log por episodio, nunca por segundo
			print("[NAV] %s sem progresso: recalculando caminho%s (desejada=%.1f m/s, real=%.1f m/s)" % [
				name, " e trocando de slot" if _slot_target != null else "", desired.length(), Vector2(velocity.x, velocity.z).length()])
		_nav_goal = Vector3.INF
		if is_instance_valid(_slot_target):
			var map := nav_agent.get_navigation_map() if _nav_ready() else RID()
			var current: Variant = ApproachSlots.slot_of(_slot_target, _slot_kind, self)
			ApproachSlots.claim(_slot_target, _slot_kind, self, map, current)
	_stuck_left = STUCK_CHECK_INTERVAL
	_stuck_origin = global_position

func _find_nearest_wild_dino_in_radius(center: Vector3, radius: float) -> Node3D:
	var nearest: Node3D = null
	var nearest_dist := radius
	for candidate in get_tree().get_nodes_in_group("wild_dino"):
		var dino := candidate as Node3D
		if dino == null or not is_instance_valid(dino):
			continue
		var dist := _flat_offset_from(center, dino.global_position).length()
		if dist <= nearest_dist:
			nearest = dino
			nearest_dist = dist
	return nearest

func _find_nearest_target() -> Node3D:
	var nearest: Node3D = null
	var nearest_dist := DETECTION_RANGE
	for group_name in ["player", "domesticated"]:
		for candidate in get_tree().get_nodes_in_group(group_name):
			var body := candidate as Node3D
			if body == null or not is_instance_valid(body):
				continue
			if territorial and _flat_offset_from(home_position, body.global_position).length() > leash_radius:
				continue # encontro territorial nao persegue para fora da sua area
			var dist := _flat_offset(body.global_position).length()
			if dist <= nearest_dist:
				nearest = body
				nearest_dist = dist
	return nearest

func _try_attack(target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		return
	if _attack_cooldown_left > 0.0:
		return # RF-AGE-004: cooldown ainda ativo, ataque nao e acionado
	if not target.has_method("take_damage"):
		return
	$Visual.strike()
	_attack_cooldown_left = ATTACK_COOLDOWN
	print("%s atacou %s." % [name, target.name])
	target.take_damage(_current_attack_damage())

# RF-AGE-018: dano/velocidade sempre calculados a partir do valor-base; nunca
# acumulam entre noites. Aliados (is_domesticated) nunca recebem o buff, mesmo
# chamando _try_attack/_current_attack_damage na defesa por area (RF-AGE-008).
func _current_attack_damage() -> float:
	if is_domesticated:
		return BASE_ATTACK_DAMAGE
	if DayNightManager.is_night():
		return BASE_ATTACK_DAMAGE * DayNightManager.night_damage_multiplier
	return BASE_ATTACK_DAMAGE

func _current_speed() -> float:
	if DayNightManager.is_night():
		return BASE_SPEED * DayNightManager.night_speed_multiplier
	return BASE_SPEED

func _flat_offset(world_pos: Vector3) -> Vector3:
	var offset := world_pos - global_position
	offset.y = 0.0
	return offset

func _flat_offset_from(origin: Vector3, world_pos: Vector3) -> Vector3:
	var offset := world_pos - origin
	offset.y = 0.0
	return offset

func _face(flat_dir: Vector3) -> void:
	if flat_dir.length_squared() > 0.0001:
		look_at(global_position + flat_dir, Vector3.UP)

## Spec 015 (RF-TER-003): o encontro diurno que guarda um territorio selvagem.
## So muda o rotulo; HP, IA e domesticacao sao os do WildDino normal.
var guardian_of := ""

func set_guardian(territory_name: String) -> void:
	guardian_of = territory_name
	_update_label()

func _update_label() -> void:
	var status := "ALIADO" if is_domesticated else ("GUARDIÃO" if guardian_of != "" else ("SELVAGEM" if is_domesticable else "CARNOTAURO • NÃO DOMESTICÁVEL"))
	hp_label.text = "%s  ·  %d/%d" % [status, maxi(int(hp), 0), int(MAX_HP)]
	hp_label.modulate = Color("a5e7c3") if is_domesticated else Color("fff0cf")
