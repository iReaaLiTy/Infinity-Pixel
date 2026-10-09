extends RefCounted

# Dados do vale compartilhados por tools/build_first_map.gd (marcadores e
# malhas-dado das trilhas, lidas pelos testes) e tools/build_valley_art.gd
# (chao e trilhas desenhados). Uma fonte so: a arte nunca sai do lugar das rotas.

## Trilhas: grupo em WorldRegions, nome, pontos (x, z), largura funcional (m).
const PATHS := [
	{"group": "NightRoutes", "name": "RuinRoad", "points": [Vector2(0,-13), Vector2(0,-5), Vector2(0,4), Vector2(0,14), Vector2(0,26)], "width": 4.6},
	{"group": "NightRoutes", "name": "WestTrail", "points": [Vector2(0,-9), Vector2(-7,-5), Vector2(-13,0), Vector2(-21,2)], "width": 3.8},
	{"group": "NightRoutes", "name": "EastTrail", "points": [Vector2(0,-9), Vector2(7,-5), Vector2(14,0), Vector2(21,2)], "width": 3.8},
	# As duas trilhas selvagens saem da estrada na mesma bifurcacao.
	{"group": "WildZone", "name": "GladeTrail", "points": [Vector2(0,6), Vector2(-6,8), Vector2(-10,10), Vector2(-12,17)], "width": 2.8},
	{"group": "WildZone", "name": "HeathTrail", "points": [Vector2(0,6), Vector2(7,9), Vector2(13,13), Vector2(14,22)], "width": 2.6},
]
const FORK := Vector2(0, 6)
const FORK_SIZE := Vector2(5.2, 4.2)

const REFUGE := Vector2(0, -15)
const BUILD_ZONE := Vector2(7, -15)
const BUILD_ZONE_SIZE := Vector2(8, 10)
const DEFENSE_POST := Vector2(0, -7)

## Regioes (centro, tamanho) — as mesmas manchas da Spec 012.
const WOODLAND := [Vector2(-12, 16), Vector2(19, 22)]
const HEATH := [Vector2(15, 17), Vector2(16, 21)]
const GLADE := [Vector2(-10, 10), Vector2(10, 10)]
const MEADOW := [Vector2(0, 0), Vector2(33, 18)]

## Limites andaveis (os Boundary de ArenaArt).
const BOUND_X := 24.2
const BOUND_SOUTH := -24.2
const BOUND_NORTH := 28.2

## Entradas das ondas noturnas (WaveManager: EnemySpawnPoint + deslocamentos).
const ENTRIES := [Vector2(-20, 2), Vector2(20, 2), Vector2(0, 23)]

## Distancia de p ate a linha central de uma trilha.
static func path_distance(p: Vector2, points: Array) -> float:
	var best := INF
	for i in points.size() - 1:
		var c := Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1])
		best = minf(best, c.distance_to(p))
	return best

## Distancia "elipse" normalizada: 1 = na borda da mancha (centro, tamanho).
static func patch_distance(p: Vector2, patch: Array) -> float:
	var half: Vector2 = patch[1] * 0.5
	var d: Vector2 = (p - patch[0]) / half
	return d.length()

static func in_build_zone(p: Vector2, margin := 0.0) -> bool:
	var half := BUILD_ZONE_SIZE * 0.5 + Vector2.ONE * margin
	return absf(p.x - BUILD_ZONE.x) <= half.x and absf(p.y - BUILD_ZONE.y) <= half.y
