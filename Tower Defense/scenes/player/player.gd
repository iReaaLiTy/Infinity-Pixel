extends CharacterBody3D

# Spec: docs/specs/001-controle-jogador.md
# RF-AGE-001 — Movimento do personagem (PROVISORIO)
# RF-AGE-002 — Ataque corpo a corpo do personagem (PROVISORIO)

const SPEED := 6.0 # RF-AGE-001 valor inicial. Teto de teste: ate 8 m/s.
const GRAVITY := 9.8
const MOUSE_SENSITIVITY := 0.003
const ATTACK_DAMAGE := 20.0 # RF-AGE-002 valor inicial. Teto de teste: ate 35.
const CAMERA_PITCH_MIN_DEG := -60.0
const CAMERA_PITCH_MAX_DEG := 30.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var attack_area: Area3D = $AttackArea3D
@onready var attack_cooldown: Timer = $AttackCooldownTimer

func _ready() -> void:
	add_to_group("player") # alvo detectavel pelo dinossauro selvagem (Spec 002)
	add_to_group("damageable") # ADR 0001
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# PROVISORIO: vida e morte/respawn do jogador ainda nao estao definidos numa Spec
# (ver technical-decisions.md: morte nao e derrota). Por enquanto so registra o dano.
func take_damage(amount: float) -> void:
	print("[Player] recebeu %.0f de dano (sem HP definido ainda)." % amount)

func _input(event: InputEvent) -> void:
	if not DayNightManager.can_play() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x - event.relative.y * MOUSE_SENSITIVITY, deg_to_rad(-55), deg_to_rad(10))
	elif event.is_action_pressed("attack") and not Input.is_action_pressed("domesticate"):
		_try_attack()

func _physics_process(delta: float) -> void:
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

	var move_dir: Vector3 = transform.basis * input_dir
	move_dir.y = 0.0

	velocity.x = move_dir.x * SPEED
	velocity.z = move_dir.z * SPEED

	move_and_slide()

func _try_attack() -> void:
	if not DayNightManager.can_play() or not attack_cooldown.is_stopped():
		return # RF-AGE-002: cooldown ainda ativo, ataque nao e acionado
	attack_cooldown.start()
	$Visual.strike()
	get_tree().call_group("audio_director", "effect", false)
	var hits := 0
	# consulta direta no momento do golpe, em vez de depender de sinais de entrada/saida
	for body in attack_area.get_overlapping_bodies():
		# RF-AGE-006: dinossauro domesticado e aliado, o jogador nao o fere.
		if body != self and body.is_in_group("damageable") and not body.is_in_group("domesticated") and body.has_method("take_damage"):
			body.take_damage(ATTACK_DAMAGE)
			hits += 1
	print("[Player] ataque acionado — alvos atingidos: %d" % hits) # feedback temporario de playtest
