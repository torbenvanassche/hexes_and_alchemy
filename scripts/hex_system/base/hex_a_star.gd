class_name HexAStar
extends AStar2D

var grid: HexGrid
var method: HexInfo.TraversalTag

var cube_to_id: Dictionary[Vector3i, int] = {}
var id_to_cube: Dictionary[int, Vector3i] = {}

static var obstacles: Array[Obstacle] = []

func _init(hex_grid: HexGrid, traverse_method: HexInfo.TraversalTag = HexInfo.TraversalTag.WALK) -> void:
	grid = hex_grid
	method = traverse_method

func _is_blocked(a: Vector3i, b: Vector3i) -> bool:
	for o in obstacles:
		if (o.cube_id == a and o.adjacent_id == b) or (o.cube_id == b and o.adjacent_id == a):
			return true
	return false

func rebuild() -> void:
	clear()
	cube_to_id.clear()
	id_to_cube.clear()
	
	for cube_id: Vector3i in grid.tiles.keys():
		var scene_instance: SceneInstance = grid.tiles[cube_id]
		var hex: HexBase = scene_instance.node

		if hex == null:
			continue

		if not hex.is_traversable(method):
			continue

		var point_id := _cube_to_astar_id(cube_id)

		cube_to_id[cube_id] = point_id
		id_to_cube[point_id] = cube_id

		add_point(point_id, Vector2(hex.global_position.x, hex.global_position.z), hex.movement_cost)

	# rebuild connections (OBSTACLES RESPECTED)
	for cube_id: Vector3i in cube_to_id.keys():
		var from_id := cube_to_id[cube_id]

		for dir in DataManager.instance.CUBE_DIRS:
			var neighbor_cube := cube_id + dir

			if not cube_to_id.has(neighbor_cube):
				continue

			if _is_blocked(cube_id, neighbor_cube):
				continue

			var to_id := cube_to_id[neighbor_cube]

			if not are_points_connected(from_id, to_id):
				connect_points(from_id, to_id, true)

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

			if not are_points_connected(point_id, neighbor_id):
				connect_points(point_id, neighbor_id, true)
				connect_points(neighbor_id, point_id, true)

	for dir in DataManager.instance.CUBE_DIRS:
		var neighbor_cube := cube_id + dir

		if not grid.tiles.has(neighbor_cube):
			continue

		if _is_blocked(cube_id, neighbor_cube):
			continue

		var neighbor_scene: SceneInstance = grid.tiles[neighbor_cube]
		var neighbor: HexBase = neighbor_scene.node

		if neighbor == null:
			continue

		var neighbor_id := _cube_to_astar_id(neighbor_cube)

		if not neighbor.is_traversable():
			if has_point(neighbor_id):
				if are_points_connected(neighbor_id, point_id):
					disconnect_points(neighbor_id, point_id)
		else:
			if has_point(point_id) and has_point(neighbor_id):
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
