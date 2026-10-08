extends SceneTree

# Spec 010 (RF-NAV-001): gera scenes/world/arena_navmesh.tres a partir das
# colisoes estaticas reais da arena (Spec 009). Rodar de novo sempre que
# arte/colisoes mudarem:
#   Godot_console --headless --path . --script res://tools/bake_navmesh.gd
# O mesmo resultado sai do botao "Bake NavigationMesh" do NavigationRegion3D
# no editor, porque a configuracao fica salva no proprio recurso.

const SCENE := "res://scenes/world/prototype_area.tscn"
const OUTPUT := "res://scenes/world/arena_navmesh.tres"

func _initialize() -> void:
	_bake.call_deferred()

func _bake() -> void:
	var world := (load(SCENE) as PackedScene).instantiate()
	# Instanciada so para ler a geometria; scripts de gameplay nao precisam rodar.
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	var region := world.get_node("NavigationRegion") as NavigationRegion3D
	var navmesh := configure(NavigationMesh.new())
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navmesh, source, world)
	NavigationServer3D.bake_from_source_geometry_data(navmesh, source)
	var polygons := navmesh.get_polygon_count()
	print("[NAVMESH] vertices=%d poligonos=%d" % [navmesh.get_vertices().size(), polygons])
	if polygons == 0:
		push_error("[NAVMESH] bake vazio: confira o grupo 'navigation_source' e a mascara 9.")
		quit(1)
		return
	var err := ResourceSaver.save(navmesh, OUTPUT)
	print("[NAVMESH] salvo em %s (erro=%d), regiao=%s" % [OUTPUT, err, region.get_path()])
	quit(0 if err == OK else 1)

# Parametros documentados em docs/specs/010-navegacao-avoidance-criaturas.md.
static func configure(navmesh: NavigationMesh) -> NavigationMesh:
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_collision_mask = 1 | 8 # Spec 009: mundo + base/construcoes
	navmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	navmesh.geometry_source_group_name = &"navigation_source"
	navmesh.cell_size = 0.25 # igual ao cell_size padrao do mapa 3D
	navmesh.cell_height = 0.25
	navmesh.agent_radius = 0.5 # capsula do WildDino/Carnotauro
	navmesh.agent_height = 1.75 # 1,6 m da capsula, arredondado para multiplo de cell_height
	navmesh.agent_max_climb = 0.25
	navmesh.agent_max_slope = 45.0
	# Remove ilhas isoladas pequenas (topo de pedra de 0,85 m, topo do arco): sem
	# isso map_get_closest_point podia "projetar" um ponto em cima de uma pedra.
	# Recast: area minima = region_min_size^2 celulas (8 -> 64 celulas = 4 m2).
	navmesh.region_min_size = 8.0
	return navmesh
