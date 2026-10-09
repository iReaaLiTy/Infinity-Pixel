extends Node3D

# Spec 017A — arte nova do Refugio (gerada por tools/build_refuge_art.gd).
# So visual: nenhum corpo fisico e fora de navigation_source. O brilho noturno
# vem do DayNightVisual pelo grupo night_glow, como torres, armadilhas e marcos.
# Cada malha que brilha guarda meta "glow" = Vector2(energia de dia, a noite).

var _glow: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("night_glow") # Spec 014: DayNightVisual chama set_night_glow()
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mi.has_meta("glow"):
			# Copia por instancia: a noite do jogo nunca vaza para o menu.
			mi.material_override = mi.material_override.duplicate()
			_glow.append(mi)
	set_night_glow(0.0)

func set_night_glow(f: float) -> void:
	for mi in _glow:
		var energy: Vector2 = mi.get_meta("glow")
		(mi.material_override as StandardMaterial3D).emission_energy_multiplier = lerpf(energy.x, energy.y, f)
