extends CharacterBody3D

# Spec: docs/specs/001-controle-jogador.md
# RF-AGE-001 — Movimento do personagem (PROVISORIO)
# RF-AGE-002 — Ataque corpo a corpo do personagem (PROVISORIO)
# Spec: docs/specs/007-camera-estrategica.md
# RF-CAM-003 — WASD relativo a camera (PROVISORIO)
# RF-CAM-004 — Mira do ataque pelo cursor (PROVISORIO)
# Spec: docs/specs/011-vida-morte-respawn-jogador.md
# RF-VID-001 a 005 — HP, invulnerabilidade, morte, respawn e protecao (PROVISORIO)

signal health_changed(current: float, maximum: float)
signal died
signal respawned
## Correcao do playtest: clique num alvo fora do alcance (sem dano; so aviso).
signal attack_out_of_range(target: Node3D)

const SPEED := 6.0 # RF-AGE-001 valor inicial. Teto de teste: ate 8 m/s.
const GRAVITY := 9.8
# Spec 013C (RF-CMB-001): valor unico do golpe do Player (criaturas e recursos).
# Era 20; 15 deixa o WildDino 80 -> 65 -> 50 -> 35 -> 20 (elegivel).
const ATTACK_DAMAGE := 15.0
const ATTACK_COOLDOWN := 0.6 # RF-AGE-002: golpe que acerta (balanceamento 09/10/2026: era 0,8)
const WHIFF_COOLDOWN := 0.3 # RF-CMB-002: golpe no vazio recupera mais rapido
const ATTACK_BUFFER := 0.35 # s: clique ate esse tempo antes do fim do cooldown e guardado
const CREATURES := 1 << 2 # Spec 009: camada 3
const INTERACTABLES := 1 << 4 # Spec 009: camada 5 (reserva) -> recursos coletaveis (013C)
const MIN_AIM_DISTANCE := 0.2 # cursor quase em cima do jogador: mantem a direcao atual
const TURN_SPEED := 14.0 # suavizacao da orientacao visual (maior = vira mais rapido)
const ATTACK_FACE_HOLD := 0.3 # s em que o modelo encara o golpe antes de voltar ao movimento
# Correcao do playtest (direcao do golpe): o modelo VIRA rapido para o golpe
# (~0,1 s) em vez de saltar; o golpe logico sai no instante do clique.
const ATTACK_TURN_SPEED := 40.0
# Escolha do alvo pela intencao do clique: criaturas/recursos cujo corpo
# (projetado na tela) esta a ate PICK_RADIUS_PX do cursor (em 720p) e a ate
# PICK_MAX_DISTANCE m do jogador. Nao e auto-mira: so desempata o clique.
const PICK_RADIUS_PX := 70.0
const PICK_MAX_DISTANCE := 7.0
const REACH := 2.0 # alcance do golpe (borda da caixa de ataque), m
const CombatFX := preload("res://scenes/visuals/combat_fx.gd")
const PROTECTION_BLINK := 0.16 # s: periodo do pisca da protecao pos-respawn (RF-VID-005)

# Spec 011: valores iniciais de prototipo, ajustaveis no Inspector.
@export var max_hp := 100.0 # RF-VID-001
@export var hit_invulnerability := 1.0 # RF-VID-002: janela apos um hit valido (s; balanceamento 09/10/2026: era 0,6)
@export var respawn_delay := 2.0 # RF-VID-004: morto ate renascer (s)
@export var respawn_protection := 1.5 # RF-VID-005: invulneravel apos renascer (s)
## Ponto de respawn (Marker3D). Sem ele, usa a posicao inicial do Player.
@export var respawn_point_path: NodePath

@onready var camera: Camera3D = $StrategicCamera
@onready var attack_area: Area3D = $AttackArea3D
@onready var attack_cooldown: Timer = $AttackCooldownTimer
@onready var visual: Node3D = $Visual
@onready var respawn_timer: Timer = $RespawnTimer
@onready var nav_obstacle: NavigationObstacle3D = $NavigationObstacle3D
@onready var channel: Node = $DomesticationChannel

# A mira so passa a seguir o cursor depois que o mouse se mexe pela primeira vez,
# para nao girar o jogador para um cursor parado em canto qualquer da tela.
var _aim_active := false
var _attack_queued := false # RF-CMB-002: um clique guardado durante o fim do cooldown
var _queued_screen_pos := Vector2.ZERO # onde o clique guardado foi feito (mira no alvo dele)
var attack_count := 0 # golpes executados (diagnostico/testes: 1 clique = 1 golpe)
var last_attack_yaw := 0.0 # direcao logica do ultimo golpe (diagnostico/testes)
var picked_target: Node3D # alvo escolhido pelo ultimo clique (ou null)
var _attack_yaw := 0.0

# Separacao de orientacoes:
# - rotation.y do Player = direcao LOGICA do ataque (cursor); a AttackArea3D e filha.
# - _facing_yaw = orientacao VISUAL no mundo, guiada pela direcao do movimento.
# O Visual e contra-rotacionado para que o yaw do raiz nao o arraste junto.
var _facing_yaw := 0.0
var _attack_face_time := 0.0

# Spec 011 — estado de vida
var current_hp := 0.0
var is_dead := false
var _invulnerable_left := 0.0
var _protection_left := 0.0 # parte "pos-respawn" da invulnerabilidade (pisca o Visual)
var _spawn_transform: Transform3D
var _collision_layer := 0

func _ready() -> void:
	add_to_group("player") # alvo detectavel pelo dinossauro selvagem (Spec 002)
	add_to_group("damageable") # ADR 0001
	_facing_yaw = rotation.y
	_collision_layer = collision_layer
	var marker := get_node_or_null(respawn_point_path) as Node3D
	_spawn_transform = marker.global_transform if marker != null else global_transform
	current_hp = max_hp
	respawn_timer.timeout.connect(_respawn)
	attack_cooldown.timeout.connect(_on_attack_ready)

# Spec 013D (RF-CON-005): cura da Fogueira. Nunca passa de max_hp; morto nao cura.
func heal(amount: float) -> void:
	if is_dead or not is_finite(amount) or amount <= 0.0 or current_hp >= max_hp:
		return
	current_hp = minf(current_hp + amount, max_hp)
	print("[Player] curou %.0f. HP: %.0f/%.0f" % [amount, current_hp, max_hp])
	health_changed.emit(current_hp, max_hp)

func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0

func respawn_time_left() -> float:
	return respawn_timer.time_left if is_dead else 0.0

# ADR 0001 / RF-VID-001..003: contrato unico de dano. Dano invalido (<= 0, NaN,
# infinito), Player morto ou dentro da janela de invulnerabilidade: ignorado.
func take_damage(amount: float) -> void:
	if is_dead or _invulnerable_left > 0.0 or not is_finite(amount) or amount <= 0.0:
		return
	current_hp = clampf(current_hp - amount, 0.0, max_hp)
	print("[Player] recebeu %.1f de dano. HP: %.1f/%.0f" % [amount, current_hp, max_hp])
	health_changed.emit(current_hp, max_hp)
	if current_hp <= 0.0:
		_die()
		return
	_invulnerable_left = hit_invulnerability
	visual.flash() # RF-VID-002: feedback discreto (pulso do modelo); a HUD tinge a barra

# RF-VID-003: morte acontece uma vez; o mundo continua (sem pausar a arvore).
func _die() -> void:
	if is_dead:
		return
	is_dead = true
	_invulnerable_left = 0.0
	_protection_left = 0.0
	velocity = Vector3.ZERO
	channel.reset_channel() # cancela a domesticacao no mesmo quadro
	_attack_queued = false
	# Sai do grupo "player": a IA (busca por grupos, Spec 010) troca de alvo sozinha
	# — onda volta ao refugio, territorial volta para casa. Sem corpo solido nem
	# obstaculo de avoidance enquanto morto.
	remove_from_group("player")
	collision_layer = 0
	nav_obstacle.avoidance_enabled = false
	visual.visible = false
	print("[Player] morreu. Respawn em %.1f s." % respawn_delay)
	respawn_timer.start(respawn_delay) # Timer do Player: pausa junto com a arvore
	died.emit()

# RF-VID-004/005: volta ao ponto de spawn com HP cheio e protecao temporaria.
func _respawn() -> void:
	if not is_dead:
		return
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_facing_yaw = rotation.y
	_attack_face_time = 0.0
	current_hp = max_hp
	is_dead = false
	collision_layer = _collision_layer
	nav_obstacle.avoidance_enabled = true
	visual.visible = true
	add_to_group("player")
	_invulnerable_left = respawn_protection
	_protection_left = respawn_protection
	attack_cooldown.stop()
	print("[Player] renasceu com %.0f/%.0f HP (protecao %.1f s)." % [current_hp, max_hp, respawn_protection])
	health_changed.emit(current_hp, max_hp)
	respawned.emit()

# _unhandled_input (e nao _input): cliques consumidos por botoes/paineis da
# interface nunca chegam aqui, entao clicar na UI nao ataca o mundo (RF-CAM-004).
func _unhandled_input(event: InputEvent) -> void:
	if not DayNightManager.can_play() or is_dead:
		return
	if event is InputEventMouseMotion:
		_aim_active = true
	elif event.is_action_pressed("attack") and not event.is_echo() and not channel.blocks_attack():
		# Spec 013D: posicionando construcao, o clique confirma a obra, nao ataca.
		var placer := get_tree().get_first_node_in_group("build_placer")
		if placer != null and placer.is_placing():
			return
		# Spec 013C (RF-CMB-002): 1 clique = 1 tentativa, resolvida NESTE quadro.
		# Antes: com a mira girando, o golpe esperava 2 quadros (sem cooldown ainda,
		# um 2o clique podia gerar outro golpe) e usava a sobreposicao da Area3D
		# do passo anterior. Agora: mira -> consulta de forma imediata -> dano.
		_aim_at_click(event.position)
		if attack_cooldown.is_stopped():
			_try_attack()
		elif attack_cooldown.time_left <= ATTACK_BUFFER:
			# Causa do "clique duplo": o golpe no vazio (dino ainda a ~3 m) iniciava
			# 0,8 s de cooldown e o clique seguinte, ja no alcance, era descartado.
			# Agora o vazio recupera em 0,3 s e um clique no fim do cooldown fica
			# guardado (no maximo um) e sai assim que o cooldown acaba.
			_attack_queued = true
			_queued_screen_pos = event.position

func _on_attack_ready() -> void:
	if _attack_queued:
		_attack_queued = false
		_aim_at_click(_queued_screen_pos) # o mesmo alvo do clique guardado
		_try_attack()

func _physics_process(delta: float) -> void:
	# Janelas de protecao contam no passo de fisica: pausam junto com a arvore.
	_invulnerable_left = maxf(0.0, _invulnerable_left - delta)
	if _protection_left > 0.0:
		_protection_left = maxf(0.0, _protection_left - delta)
		visual.visible = _protection_left <= 0.0 or fmod(_protection_left, PROTECTION_BLINK) > PROTECTION_BLINK * 0.35
	if is_dead:
		return # RF-VID-003: sem movimento nem mira enquanto morto

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta

	var input_dir := Vector3.ZERO
	if DayNightManager.can_play(): # RF-AGE-016: fim de sessao bloqueia movimento
		if Input.is_physical_key_pressed(KEY_W):
			input_dir.z -= 1.0
		if Input.is_physical_key_pressed(KEY_S):
			input_dir.z += 1.0
		if Input.is_physical_key_pressed(KEY_A):
			input_dir.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			input_dir.x += 1.0
	input_dir = input_dir.normalized()

	# RF-CAM-003: a direcao vem da camera (fixa), nao da rotacao do jogador,
	# que agora segue a mira do cursor.
	var move_dir: Vector3 = camera.planar_direction(input_dir) if input_dir != Vector3.ZERO else Vector3.ZERO

	velocity.x = move_dir.x * SPEED
	velocity.z = move_dir.z * SPEED

	move_and_slide()

	if _aim_active and DayNightManager.can_play():
		_aim_at_screen(get_viewport().get_mouse_position())

	_update_facing(move_dir, delta)

# Orientacao visual: segue a direcao de entrada (nao a velocity, que desvia ao
# deslizar em paredes e causaria jitter). Parado, mantem a ultima orientacao.
func _update_facing(move_dir: Vector3, delta: float) -> void:
	_attack_face_time = maxf(0.0, _attack_face_time - delta)
	if _attack_face_time > 0.0:
		_facing_yaw = lerp_angle(_facing_yaw, _attack_yaw, 1.0 - exp(-ATTACK_TURN_SPEED * delta))
	elif move_dir != Vector3.ZERO:
		var target_yaw := atan2(-move_dir.x, -move_dir.z) # frente do modelo = -Z
		_facing_yaw = lerp_angle(_facing_yaw, target_yaw, 1.0 - exp(-TURN_SPEED * delta))
	_facing_yaw = wrapf(_facing_yaw, -PI, PI)
	# Global yaw do Visual = rotation.y (mira) + local yaw -> local = facing - mira.
	visual.rotation.y = wrapf(_facing_yaw - rotation.y, -PI, PI)

# RF-CAM-004: gira o jogador (e com ele a AttackArea3D) para o ponto do chao sob o cursor.
func _aim_at_screen(screen_pos: Vector2) -> void:
	var point = camera.screen_to_ground(screen_pos, global_position.y)
	if point == null:
		return
	var dir: Vector3 = point - global_position
	dir.y = 0.0
	if dir.length() < MIN_AIM_DISTANCE:
		return
	rotation.y = atan2(-dir.x, -dir.z) # frente do jogador = -Z

# RF-CMB-002: no clique, se o cursor esta SOBRE uma criatura/recurso atacavel, a
# mira vai para o corpo dele. Projetar no chao um clique feito no corpo (1 m+ de
# altura) cai atras do alvo e desviava a mira em ate ~30 graus.
func _aim_at_click(screen_pos: Vector2) -> void:
	picked_target = _pick_target(screen_pos)
	if picked_target != null:
		var dir: Vector3 = picked_target.global_position - global_position
		dir.y = 0.0
		if dir.length() >= MIN_AIM_DISTANCE:
			rotation.y = atan2(-dir.x, -dir.z)
			return
	_aim_at_screen(screen_pos)

## Alvo pretendido pelo clique. 1) o raio do cursor acerta o corpo de uma
## criatura/recurso; 2) senao, o corpo mais proximo do cursor NA TELA (copa da
## arvore, rocha, criatura). A copa e muito maior que a capsula do tronco: antes
## o clique nela caia no chao atras da arvore e o golpe saia torto.
func _pick_target(screen_pos: Vector2) -> Node3D:
	var from := camera.project_ray_origin(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(screen_pos) * 200.0, CREATURES | INTERACTABLES, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and _is_attackable(hit.collider):
		return hit.collider
	var scale := get_viewport().get_visible_rect().size.y / 720.0
	var best: Node3D = null
	var best_score := INF
	for body in get_tree().get_nodes_in_group("damageable"):
		# So corpos que a caixa do golpe tambem atingiria (criaturas e recursos):
		# o Refugio e "damageable" (inimigos o ferem), mas nunca e alvo do jogador.
		if not body is CollisionObject3D or (body.collision_layer & (CREATURES | INTERACTABLES)) == 0 \
				or not _is_attackable(body) or body.get("depleted") == true:
			continue
		var d := _flat_distance(body)
		if d > PICK_MAX_DISTANCE:
			continue
		var height := 2.8 if body.get("kind") == "wood" else (1.1 if body.get("kind") == "stone" else 1.5)
		var px := INF
		for k in 4: # segmento vertical do corpo, projetado na tela
			var p: Vector3 = body.global_position + Vector3(0, 0.2 + height * k / 3.0, 0)
			if camera.is_position_behind(p):
				continue
			px = minf(px, camera.unproject_position(p).distance_to(screen_pos) / scale)
		if px > PICK_RADIUS_PX:
			continue
		# Criatura vence recurso quando os dois estao sob o cursor; depois, o
		# mais perto do cursor e, por fim, o mais perto do jogador.
		var score := px + d * 4.0 - (20.0 if body.is_in_group("wild_dino") else 0.0)
		if score < best_score:
			best_score = score
			best = body
	return best

func _flat_distance(body: Node3D) -> float:
	return Vector2(body.global_position.x - global_position.x, body.global_position.z - global_position.z).length()

## Raio aproximado do corpo (borda), para saber se esta ao alcance do golpe.
static func _body_radius(body) -> float:
	match body.get("kind"):
		"stone": return 0.8
		"wood": return 0.35
	return 0.5

func _is_attackable(body) -> bool:
	# RF-AGE-006: dinossauro domesticado e aliado, o jogador nao o fere.
	return is_instance_valid(body) and body != self and body.is_in_group("damageable") \
		and not body.is_in_group("domesticated") and body.has_method("take_damage")

func _try_attack() -> void:
	# Revalida no momento de executar, inclusive ataque guardado pelo cooldown.
	# E da domesticacao bloqueia; E da recuperacao do marco nao (o golpe a cancela).
	var placer := get_tree().get_first_node_in_group("build_placer")
	if channel.blocks_attack() or (placer != null and placer.is_placing()):
		_attack_queued = false
		return
	if is_dead or not DayNightManager.can_play() or not attack_cooldown.is_stopped():
		return # RF-VID-003: morto nao ataca. RF-AGE-002: cooldown ainda ativo
	attack_count += 1
	last_attack_yaw = rotation.y
	# O modelo vira rapido para o golpe (sem saltar) e o encara por um instante;
	# depois volta a seguir o movimento. O golpe logico ja sai nesta direcao.
	_attack_yaw = rotation.y
	_attack_face_time = ATTACK_FACE_HOLD
	visual.strike()
	CombatFX.slash(self, global_position + Vector3(0, 0.9, 0), rotation.y)
	get_tree().call_group("audio_director", "effect", false)
	# Consulta de forma IMEDIATA com a caixa da AttackArea3D na rotacao atual: nao
	# depende da sobreposicao calculada no passo de fisica anterior.
	var box: CollisionShape3D = attack_area.get_node("CollisionShape3D")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box.shape
	query.transform = box.global_transform
	query.collision_mask = CREATURES | INTERACTABLES
	query.exclude = [get_rid()]
	var hits := 0
	var seen := {}
	for result in get_world_3d().direct_space_state.intersect_shape(query, 16):
		var body = result.collider
		if _is_attackable(body) and not seen.has(body):
			seen[body] = true
			body.take_damage(ATTACK_DAMAGE)
			hits += 1
	# O alvo escolhido pelo clique, se estiver ao alcance, sempre leva o golpe
	# (mesmo colado ao jogador ou na quina da caixa). Fora do alcance: so aviso.
	var aim := picked_target
	picked_target = null
	if is_instance_valid(aim) and _is_attackable(aim) and aim.get("depleted") != true and not seen.has(aim):
		if _flat_distance(aim) <= REACH + _body_radius(aim) + 0.1:
			aim.take_damage(ATTACK_DAMAGE)
			hits += 1
		else:
			attack_out_of_range.emit(aim)
			CombatFX.ring(self, aim.global_position, Color(1, 1, 1), 1.3, 0.35)
	attack_cooldown.start(ATTACK_COOLDOWN if hits > 0 else WHIFF_COOLDOWN)
	print("[Player] ataque acionado — alvos atingidos: %d" % hits) # feedback temporario de playtest
