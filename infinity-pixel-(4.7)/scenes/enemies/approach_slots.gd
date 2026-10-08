extends RefCounted

# Spec: docs/specs/010-navegacao-avoidance-criaturas.md
# RF-NAV-003 — Posicoes individuais e estaveis de aproximacao (PROVISORIO)
# RF-NAV-005 — Slots individuais dos aliados (PROVISORIO)
#
# Cada alvo (Player, aliado, refugio) guarda os proprios slots em metadata, entao
# os dados somem junto com o alvo e nao ha estado global entre partidas. Um slot e
# um ponto em um anel ao redor do alvo, em angulo FIXO no mundo: nao gira com o
# alvo e nao e sorteado. Quem pede recebe o slot livre mais perto de si e fica com
# ele ate liberar (troca de alvo, morte, domesticacao ou slot bloqueado).

# kind -> aneis [quantidade, raio em m]. O anel 0 fica dentro do alcance de
# ataque (2 m do golpe; 1,5 m de chegada a base); o anel 1 e a fila de espera.
const RINGS := {
	&"attack": [[6, 1.7], [10, 3.2]],
	&"base": [[6, 1.2], [10, 2.6]], # 1,2 + chegada 0,25 < 1,5 m (chegada a base)
	&"follow": [[5, 2.6], [8, 4.0]],
}
# Slot cujo ponto ideal cai fora da navmesh (dentro de arvore/pedra) por mais
# que isso e considerado bloqueado no momento da escolha.
const MAX_SNAP_DISTANCE := 0.6
# Peso do espalhamento na escolha do slot: cada metro de arco ate o slot ocupado
# mais proximo vale SPREAD_WEIGHT metros de caminhada a mais.
const SPREAD_WEIGHT := 1.5

static func _meta_key(kind: StringName) -> StringName:
	return StringName("approach_slots_%s" % kind)

static func _table(target: Node3D, kind: StringName) -> Dictionary:
	var key := _meta_key(kind)
	if not target.has_meta(key):
		target.set_meta(key, {})
	return target.get_meta(key)

# Ponto ideal do slot no plano do alvo (sem projetar na navmesh).
static func slot_position(target: Node3D, kind: StringName, slot: Vector2i) -> Vector3:
	var ring: Array = RINGS[kind][slot.x]
	var count: int = ring[0]
	var radius: float = ring[1]
	var phase := 0.5 if slot.x % 2 == 1 else 0.0 # anel externo intercalado com o interno
	var angle := TAU * (float(slot.y) + phase) / float(count)
	return target.global_position + Vector3(sin(angle), 0.0, cos(angle)) * radius

static func holder_of(target: Node3D, kind: StringName, slot: Vector2i) -> Node:
	var id: int = _table(target, kind).get(slot, 0)
	var holder := instance_from_id(id) if id != 0 else null
	return holder if is_instance_valid(holder) and holder.is_inside_tree() else null

static func slot_of(target: Node3D, kind: StringName, claimer: Node) -> Variant:
	var table := _table(target, kind)
	for slot in table:
		if table[slot] == claimer.get_instance_id():
			return slot
	return null

# Devolve o slot (Vector2i: anel, indice) de `claimer`, reservando o livre mais
# proximo se ainda nao tiver um. `exclude` evita voltar a um slot que acabou de
# falhar (bloqueado/preso). Retorna null se todos os aneis estiverem cheios.
static func claim(target: Node3D, kind: StringName, claimer: Node3D, map: RID = RID(), exclude: Variant = null) -> Variant:
	var current: Variant = slot_of(target, kind, claimer)
	if current != null and current != exclude:
		return current
	release(target, kind, claimer)
	var table := _table(target, kind)
	var rings: Array = RINGS[kind]
	for ring_index in rings.size():
		var count: int = rings[ring_index][0]
		var radius: float = rings[ring_index][1]
		var taken: Array[int] = []
		for i in count:
			if holder_of(target, kind, Vector2i(ring_index, i)) != null:
				taken.append(i)
		var best: Variant = null
		var best_score := INF
		for i in count:
			var slot := Vector2i(ring_index, i)
			if slot == exclude or taken.has(i):
				continue
			var point := slot_position(target, kind, slot)
			if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
				var on_mesh := NavigationServer3D.map_get_closest_point(map, point)
				if Vector2(on_mesh.x - point.x, on_mesh.z - point.z).length() > MAX_SNAP_DISTANCE:
					continue # dentro de obstaculo agora
			var d := Vector2(point.x - claimer.global_position.x, point.z - claimer.global_position.z).length()
			# Espalhar: premia o slot mais longe (em arco) dos ja ocupados, para
			# cercar o alvo em vez de empilhar todos do lado de onde vieram.
			var gap_steps := count / 2.0
			for t in taken:
				var steps := absi(i - t)
				gap_steps = minf(gap_steps, mini(steps, count - steps))
			var score := d - SPREAD_WEIGHT * gap_steps * (TAU * radius / count)
			if score < best_score:
				best = slot
				best_score = score
		if best != null:
			table[best] = claimer.get_instance_id()
			return best
	return null

static func release(target: Node3D, kind: StringName, claimer: Node) -> void:
	if not is_instance_valid(target):
		return
	var table := _table(target, kind)
	for slot in table.keys():
		if table[slot] == claimer.get_instance_id():
			table.erase(slot)

# Quem esta no anel de espera passa para o anel 0 quando abrir vaga ali.
static func upgrade(target: Node3D, kind: StringName, claimer: Node3D, map: RID = RID()) -> Variant:
	var current: Variant = slot_of(target, kind, claimer)
	if current == null or current.x == 0:
		return current
	var count: int = RINGS[kind][0][0]
	for i in count:
		if holder_of(target, kind, Vector2i(0, i)) == null:
			release(target, kind, claimer)
			var slot: Variant = claim(target, kind, claimer, map)
			return slot
	return current

# Slots ocupados por criaturas validas: {Vector2i: Node} (testes/diagnostico).
static func holders(target: Node3D, kind: StringName) -> Dictionary:
	var out := {}
	var table := _table(target, kind)
	for slot in table:
		var holder := holder_of(target, kind, slot)
		if holder != null:
			out[slot] = holder
	return out
