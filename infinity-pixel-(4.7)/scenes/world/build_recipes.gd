extends RefCounted

# Spec: docs/specs/013d-inventario-construcao-cura.md — RF-CON-001 (PROVISORIO)
# Receitas de construcao (fonte unica de custo/limite/zona). Pagas com MADEIRA e
# PEDRA (ResourceStock). Torres continuam em Pontos de Defesa (DefenseSlots).
# Base reutilizavel: uma estrutura nova (cerca, portao...) e so mais uma entrada.

const CAMPFIRE := &"campfire"
const TRAP := &"trap"

const RECIPES := {
	CAMPFIRE: {
		"name": "FOGUEIRA DE CURA",
		"built": "FOGUEIRA CONSTRUÍDA",
		"wood": 20, "stone": 12,
		"limit": 1, # RF-CON-004: uma so
		"zone": "base", # so na BuildZone (Spec 012)
		"radius": 1.1, # m livres ao redor (validacao de sobreposicao)
		"script": "res://scenes/world/healing_campfire.gd",
	},
	TRAP: {
		"name": "ARMADILHA DE ESPINHOS",
		"built": "ARMADILHA CONSTRUÍDA",
		"wood": 15, "stone": 6,
		"limit": 3, # RF-CON-006: no maximo 3 ativas
		"zone": "route", # sobre as rotas noturnas (Spec 012)
		"radius": 0.9,
		"script": "res://scenes/world/spike_trap.gd",
	},
}

static func order() -> Array:
	return [CAMPFIRE, TRAP]

static func get_recipe(id: StringName) -> Dictionary:
	return RECIPES.get(id, {})
