extends StaticBody3D

# Alvo de teste temporario para validar RF-AGE-002 (ataque do jogador).
# Nao pertence a nenhuma Spec — sera substituido pelo dinossauro selvagem
# real quando 002-dinossauro-selvagem.md entrar em implementacao.

@export var max_hp: float = 100.0

var hp: float

func _ready() -> void:
	hp = max_hp
	add_to_group("damageable")

func take_damage(amount: float) -> void:
	hp -= amount
	print("%s recebeu %.0f de dano. HP: %.0f/%.0f" % [name, amount, hp, max_hp])
	if hp <= 0.0:
		print("%s foi derrotado." % name)
		queue_free()
