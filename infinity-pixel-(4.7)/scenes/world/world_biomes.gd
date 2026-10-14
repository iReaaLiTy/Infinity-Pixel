extends RefCounted

# World 6.0 — geografia do mundo expandido (uma fonte so para os geradores de
# arte, as colisoes da expansao, as pegadas do Player e os testes).
#
# O vale antigo (48 x 52 m, |x| < 24,2; -24,2 < z < 28,2) continua no centro,
# com o Refugio, as tres rotas noturnas, os slots, os territorios e os recursos
# nos mesmos lugares. Em volta, quatro regioes:
#   FLORESTA — oeste e norte (o bosque antigo, ampliado);
#   PEDRA    — leste (a charneca rochosa antiga, ampliada);
#   AGUA     — sudoeste (lago, rio e a grande cachoeira no paredao oeste);
#   VULCAO   — sul (cinzas e lava; o vulcao fica alem do paredao sul).
# A camera estrategica olha do +Z para o -Z: na tela, o
# vulcao fica no alto (ao fundo, atras do Refugio), a agua a esquerda, a pedra
# a direita e a floresta embaixo/esquerda.

## Limites andaveis do mundo expandido (64 x 74 m = 4.736 m2, 1,87x o vale).
const BOUND_X := 32.0
const BOUND_SOUTH := -42.0
const BOUND_NORTH := 32.0

## Limites do vale antigo (referencia; nao sao mais paredes).
const OLD_BOUND_X := 24.2
const OLD_BOUND_SOUTH := -24.2
const OLD_BOUND_NORTH := 28.2

const FOREST := &"forest"
const STONE := &"stone"
const WATER := &"water"
const VOLCANO := &"volcano"
const MEADOW := &"meadow" # Refugio e campo central (terra batida/grama)

## Agua: o lago, o rio da cachoeira e o corrego que sai do lago (pontos x, z).
const LAKE_CENTER := Vector2(-22.5, -22.0)
const LAKE_RADII := Vector2(6.4, 4.8)
const WATERFALL := Vector2(-32.0, -31.0) # pe da queda, no paredao oeste
const RIVER := [Vector2(-31.5, -31.0), Vector2(-28.5, -29.0), Vector2(-25.5, -25.5)]
const STREAM := [Vector2(-28.0, -19.5), Vector2(-30.5, -15.0), Vector2(-32.0, -12.5)]
const RIVER_HALF := 1.5
const STREAM_HALF := 0.9

## Vulcao: o cone fica fora da area andavel (alem do paredao sul); dentro,
## fissuras e pocas de lava cercadas por rocha (decorativas, sem dano).
const VOLCANO_PEAK := Vector3(13.0, 0.0, -66.0)
const LAVA_POOLS := [[Vector2(16.0, -36.5), 2.0], [Vector2(25.5, -32.0), 1.4], [Vector2(5.0, -38.5), 1.2]]

## Centros das regioes (para a cor do chao e a classificacao).
const REGION_CENTERS := {
	FOREST: [Vector2(-22.0, 14.0), Vector2(-4.0, 28.0), Vector2(-27.0, -2.0)],
	STONE: [Vector2(26.0, 12.0), Vector2(17.0, 19.0), Vector2(27.0, -14.0)],
	WATER: [Vector2(-24.0, -24.0), Vector2(-28.5, -14.0)],
	VOLCANO: [Vector2(14.0, -36.0), Vector2(0.0, -37.0), Vector2(26.0, -30.0)],
}

## Peso suave de cada regiao no ponto p (0..1, somam ~1 com o campo central).
static func weights(p: Vector2) -> Dictionary:
	var w := {}
	var total := 0.0
	for id in REGION_CENTERS:
		var best := INF
		for c: Vector2 in REGION_CENTERS[id]:
			best = minf(best, c.distance_to(p))
		var v := 1.0 / (1.0 + pow(best / 9.0, 3.0))
		w[id] = v
		total += v
	# o centro do vale (Refugio, campo e rotas) puxa para o campo
	var meadow := 1.0 / (1.0 + pow(Vector2(p.x * 0.85, (p.y + 6.0) * 0.8).length() / 14.0, 4.0))
	w[MEADOW] = meadow
	total += meadow
	for id in w:
		w[id] = w[id] / maxf(total, 0.0001)
	return w

## Regiao dominante no ponto p.
static func biome_at(p: Vector2) -> StringName:
	var w := weights(p)
	var best := MEADOW
	var best_v := -1.0
	for id in w:
		if w[id] > best_v:
			best_v = w[id]
			best = id
	return best

static func segment_distance(p: Vector2, points: Array) -> float:
	var best := INF
	for i in points.size() - 1:
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1]).distance_to(p))
	return best

## Distancia (m) ate a agua mais proxima (negativa dentro da agua).
static func water_distance(p: Vector2) -> float:
	var lake := (p - LAKE_CENTER) / LAKE_RADII
	var d_lake := (lake.length() - 1.0) * minf(LAKE_RADII.x, LAKE_RADII.y)
	var d_river := segment_distance(p, RIVER) - RIVER_HALF
	var d_stream := segment_distance(p, STREAM) - STREAM_HALF
	return minf(d_lake, minf(d_river, d_stream))

## Distancia (m) ate a borda da lava mais proxima (negativa dentro).
static func lava_distance(p: Vector2) -> float:
	var best := INF
	for pool in LAVA_POOLS:
		best = minf(best, p.distance_to(pool[0]) - pool[1])
	return best

## Superficie das pegadas: margem umida, pedra, cinza vulcanica ou terra.
static func surface_at(p: Vector2) -> StringName:
	if water_distance(p) < 2.6:
		return WATER
	var b := biome_at(p)
	if b == STONE or b == VOLCANO:
		return b
	return FOREST

static func in_bounds(p: Vector2, margin := 0.0) -> bool:
	return absf(p.x) < BOUND_X - margin and p.y > BOUND_SOUTH + margin and p.y < BOUND_NORTH - margin
