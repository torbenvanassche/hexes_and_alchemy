class_name HexAStar
extends AStar2D

var grid: HexGrid
var method: HexInfo.TraversalTag = HexInfo.TraversalTag.WALK

var cube_to_id: Dictionary[Vector3i, int] = {}
var id_to_cube: Dictionary[int, Vector3i] = {}

static var obstacles: Array[Obstacle] = []
static var _obstacle_revision := 0
var _indexed_obstacle_revision := -1
var _blocked_edges: Dictionary[Vector4i, bool] = {}

func _init(hex_grid: HexGrid, traverse_method: HexInfo.TraversalTag = HexInfo.TraversalTag.WALK) -> void:
	grid = hex_grid
	method = traverse_method

func _is_blocked(a: Vector3i, b: Vector3i) -> bool:
	if _indexed_obstacle_revision != _obstacle_revision:
		_blocked_edges.clear()
		for obstacle: Obstacle in obstacles:
			if not is_instance_valid(obstacle) or not grid.is_ancestor_of(obstacle):
				continue
			_blocked_edges[_edge_key(obstacle.cube_id, obstacle.adjacent_id)] = true
		_indexed_obstacle_revision = _obstacle_revision
	return _blocked_edges.has(_edge_key(a, b))

func _edge_key(a: Vector3i, b: Vector3i) -> Vector4i:
	# Cube z is -x-y; canonical endpoint order makes the lookup undirected.
	if a.x > b.x or (a.x == b.x and a.y > b.y):
		return Vector4i(b.x, b.y, a.x, a.y)
	return Vector4i(a.x, a.y, b.x, b.y)

func _clear_navigation() -> void:
	clear()
	cube_to_id.clear()
	id_to_cube.clear()

func rebuild() -> void:
	_clear_navigation()
	for coordinate: Vector3i in grid.tiles: _add_navigation_point(coordinate)
	for coordinate: Vector3i in cube_to_id: _connect_navigation_point(coordinate)

func rebuild_budgeted(budget: GenerationBudget) -> void:
	_clear_navigation()
	for coordinate: Vector3i in grid.tiles:
		await budget.checkpoint()
		_add_navigation_point(coordinate)
	for coordinate: Vector3i in cube_to_id:
		await budget.checkpoint()
		_connect_navigation_point(coordinate)

func _add_navigation_point(coordinate: Vector3i) -> void:
	var hex := grid.get_hex_at_cube_id(coordinate)
	if hex == null or not hex.is_inside_tree() or not hex.is_traversable(method): return
	var point_id := _cube_to_astar_id(coordinate)
	cube_to_id[coordinate] = point_id
	id_to_cube[point_id] = coordinate
	add_point(point_id, Vector2(hex.global_position.x, hex.global_position.z), hex.movement_cost)

func _connect_navigation_point(coordinate: Vector3i) -> void:
	var from_id := cube_to_id[coordinate]
	var hex := grid.get_hex_at_cube_id(coordinate)
	for direction: Vector3i in DataManager.instance.CUBE_DIRS:
		var neighbor := coordinate + direction
		if not cube_to_id.has(neighbor) or _is_blocked(coordinate, neighbor): continue
		if not grid.can_traverse_between(hex, grid.get_hex_at_cube_id(neighbor), method): continue
		var to_id := cube_to_id[neighbor]
		if not are_points_connected(from_id, to_id): connect_points(from_id, to_id, true)

func update_hex(hex: HexBase) -> void:
	var cube_id := hex.cube_id
	var point_id := _cube_to_astar_id(cube_id)

	if has_point(point_id):
		remove_point(point_id)

	cube_to_id.erase(cube_id)
	id_to_cube.erase(point_id)

	if hex.is_traversable(method):
		cube_to_id[cube_id] = point_id
		id_to_cube[point_id] = cube_id

		add_point(point_id, Vector2(hex.global_position.x, hex.global_position.z), hex.movement_cost)

		for dir in DataManager.instance.CUBE_DIRS:
			var neighbor_cube := cube_id + dir

			if not cube_to_id.has(neighbor_cube):
				continue

			if _is_blocked(cube_id, neighbor_cube):
				continue

			var neighbor_id := cube_to_id[neighbor_cube]
			var neighbor: HexBase = grid.tiles[neighbor_cube].node
			if not grid.can_traverse_between(hex, neighbor, method):
				continue

			if not are_points_connected(point_id, neighbor_id):
				connect_points(point_id, neighbor_id, true)

func get_hex_path(start_cube: Vector3i, end_cube: Vector3i) -> Array[HexBase]:
	var result: Array[HexBase] = []

	if not cube_to_id.has(start_cube) or not cube_to_id.has(end_cube):
		return result

	var start_id := cube_to_id[start_cube]
	var end_id := cube_to_id[end_cube]

	var id_path := get_id_path(start_id, end_id)

	for point_id in id_path:
		var cube_id := id_to_cube[point_id]

		if grid.tiles.has(cube_id):
			var hex: HexBase = grid.tiles[cube_id].node
			if hex:
				result.append(hex)

	return result

func get_reachable_distances(start_cube: Vector3i, max_distance: int) -> Dictionary[Vector3i, int]:
	var distances: Dictionary[Vector3i, int] = {}
	if not cube_to_id.has(start_cube):
		return distances

	var frontier: Array[int] = [int(cube_to_id[start_cube])]
	distances[start_cube] = 0
	var index := 0
	while index < frontier.size():
		var current_id := frontier[index]
		index += 1
		var current_cube := id_to_cube[current_id]
		var current_distance := distances[current_cube]
		if current_distance >= max_distance:
			continue

		for neighbor_id_variant in get_point_connections(current_id):
			var neighbor_id := int(neighbor_id_variant)
			if not id_to_cube.has(neighbor_id):
				continue
			var neighbor_cube := id_to_cube[neighbor_id]
			if distances.has(neighbor_cube):
				continue
			distances[neighbor_cube] = current_distance + 1
			frontier.append(neighbor_id)
	return distances

func get_hex_path_for_methods(
	start_cube: Vector3i,
	end_cube: Vector3i,
	traversal_methods: Array
) -> Array[HexBase]:
	if traversal_methods.is_empty():
		return []
	if traversal_methods.size() == 1 and traversal_methods[0] == method:
		return get_hex_path(start_cube, end_cube)

	var path_cube_to_id: Dictionary[Vector3i, int] = {}
	var path_id_to_cube: Dictionary[int, Vector3i] = {}
	var pathfinder := AStar2D.new()

	for cube_id: Vector3i in grid.tiles.keys():
		var scene_instance: SceneInstance = grid.tiles[cube_id]
		var hex := scene_instance.node as HexBase
		if hex == null or not _is_traversable_by_any_method(hex, traversal_methods):
			continue

		var point_id := _cube_to_astar_id(cube_id)
		path_cube_to_id[cube_id] = point_id
		path_id_to_cube[point_id] = cube_id
		pathfinder.add_point(point_id, Vector2(hex.global_position.x, hex.global_position.z), hex.movement_cost)

	for cube_id: Vector3i in path_cube_to_id.keys():
		var from_id: int = path_cube_to_id[cube_id]
		for dir: Vector3i in DataManager.instance.CUBE_DIRS:
			var neighbor_cube := cube_id + dir
			if not path_cube_to_id.has(neighbor_cube):
				continue
			if _is_blocked(cube_id, neighbor_cube):
				continue
			var from_hex := grid.tiles[cube_id].node as HexBase
			var to_hex := grid.tiles[neighbor_cube].node as HexBase
			if not grid.can_traverse_between_for_methods(from_hex, to_hex, traversal_methods):
				continue

			var to_id: int = path_cube_to_id[neighbor_cube]
			if not pathfinder.are_points_connected(from_id, to_id):
				pathfinder.connect_points(from_id, to_id, true)

	var result: Array[HexBase] = []
	if not path_cube_to_id.has(start_cube) or not path_cube_to_id.has(end_cube):
		return result

	var id_path := pathfinder.get_id_path(path_cube_to_id[start_cube], path_cube_to_id[end_cube])
	for point_id in id_path:
		var cube_id: Vector3i = path_id_to_cube[point_id]
		var scene_instance := grid.tiles.get(cube_id) as SceneInstance
		if scene_instance == null:
			continue
		var hex := scene_instance.node as HexBase
		if hex != null:
			result.append(hex)

	return result

func _is_traversable_by_any_method(hex: HexBase, traversal_methods: Array) -> bool:
	for traversal_method in traversal_methods:
		if hex.is_traversable(traversal_method):
			return true
	return false

func _cube_to_astar_id(c: Vector3i) -> int:
	return (((c.x & 0x1FFFFF) << 42) | ((c.y & 0x1FFFFF) << 21) | (c.z & 0x1FFFFF))


func apply_obstacle(obstacle: Obstacle) -> void:
	# Registration may update an existing obstacle's coordinates.
	_obstacle_revision += 1
	var a := obstacle.cube_id
	var b := obstacle.adjacent_id

	var a_id := _cube_to_astar_id(a)
	var b_id := _cube_to_astar_id(b)

	if has_point(a_id) and has_point(b_id):
		if are_points_connected(a_id, b_id):
			disconnect_points(a_id, b_id)
		if are_points_connected(b_id, a_id):
			disconnect_points(b_id, a_id)

	if not obstacles.has(obstacle):
		obstacles.append(obstacle)

func remove_obstacle(obstacle: Obstacle, rebuild_now: bool = true) -> void:
	if obstacle == null:
		return
	obstacles.erase(obstacle)
	_obstacle_revision += 1
	if rebuild_now:
		rebuild()
