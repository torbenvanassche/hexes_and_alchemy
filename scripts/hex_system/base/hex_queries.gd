class_name HexQueries
extends RefCounted

static func find_at_world(grid: HexGrid, world_pos: Vector3, max_distance: float = 1.2) -> HexBase:
	var approx_cube := grid.world_to_cube_id(world_pos)
	var candidates: Array[HexBase] = [];
	var candidate_hex := grid.get_hex_at_cube_id(approx_cube);
	if candidate_hex != null:
		candidates.append(candidate_hex);
	
	for dir in DataManager.instance.CUBE_DIRS:
		var neighbor_hex := grid.get_hex_at_cube_id(approx_cube + dir)
		if neighbor_hex != null and not candidates.has(neighbor_hex):
			candidates.append(neighbor_hex);
	
	var containing_candidates: Array[HexBase] = [];
	for hex in candidates:
		if GridUtils.is_point_in_hex(world_pos, hex.global_position, grid.RADIUS_IN, grid.pointy_top):
			containing_candidates.append(hex);
	
	var search_pool := containing_candidates if not containing_candidates.is_empty() else candidates;
	if search_pool.is_empty():
		return null;
	
	var closest_hex: HexBase = null;
	var closest_distance := INF;
	for hex in search_pool:
		var distance := Vector2(hex.global_position.x, hex.global_position.z).distance_squared_to(
			Vector2(world_pos.x, world_pos.z)
		)
		if distance < closest_distance:
			closest_distance = distance;
			closest_hex = hex;
	
	if closest_hex == null:
		return null;
	
	if containing_candidates.is_empty():
		if max_distance <= 0.0:
			return null;
		
		var best_dist := max_distance * max_distance;
		if closest_distance > best_dist:
			return null;
	
	return closest_hex;

static func can_traverse(
	from_hex: HexBase,
	to_hex: HexBase,
	method: HexInfo.TraversalTag = HexInfo.TraversalTag.WALK
) -> bool:
	if from_hex == null or to_hex == null:
		return false
	if not from_hex.is_traversable(method) or not to_hex.is_traversable(method):
		return false

	var from_edge := DataManager.instance.CUBE_DIRS.find(to_hex.cube_id - from_hex.cube_id)
	if from_edge < 0:
		return false
	var to_edge := posmod(from_edge + 3, DataManager.instance.CUBE_DIRS.size())
	if not from_hex.can_traverse_edge(from_edge, method):
		return false
	if not to_hex.can_traverse_edge(to_edge, method):
		return false

	return (
		from_hex.get_edge_elevation_units_for_method(from_edge, method)
		== to_hex.get_edge_elevation_units_for_method(to_edge, method)
	)

static func in_radius(grid: HexGrid, center: Vector3i, radius: int) -> Array[SceneInstance]:
	var result: Array[SceneInstance] = [];
	for dx in range(-radius, radius + 1):
		for dy in range(
			max(-radius, -dx - radius),
			min(radius, -dx + radius) + 1
		):
			var dz := -dx - dy
			var cube := center + Vector3i(dx, dy, dz)

			if grid.tiles.has(cube):
				result.append(grid.tiles[cube]);
	return result;
	
