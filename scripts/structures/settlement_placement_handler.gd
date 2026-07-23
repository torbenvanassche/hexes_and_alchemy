extends RefCounted

func can_place(_structure_info: PlaceableStructureInfo, hex: HexBase, _inventory: ContentGroup) -> bool:
	var settlement := _get_settlement_for_hex(hex)
	if settlement == null:
		return false
	if settlement.level < _structure_info.required_settlement_level:
		return false
	if not hex.is_traversable(HexInfo.TraversalTag.WALK):
		return false
	return _get_facing_neighbor(settlement, hex, get_rotation_y(_structure_info, hex)) != null

func can_place_rotation(_structure_info: PlaceableStructureInfo, hex: HexBase, _inventory: ContentGroup, rotation_y: float) -> bool:
	var settlement := _get_settlement_for_hex(hex)
	if settlement == null:
		return false
	if settlement.level < _structure_info.required_settlement_level:
		return false
	return _get_facing_neighbor(settlement, hex, rotation_y) != null

func get_rotation_y(_structure_info: PlaceableStructureInfo, hex: HexBase) -> float:
	var settlement := _get_settlement_for_hex(hex)
	if settlement == null:
		return 0.0

	for direction: Vector3i in DataManager.instance.CUBE_DIRS:
		var neighbor := _get_neighbor(hex, direction)
		if _is_valid_facing_neighbor(settlement, hex, neighbor):
			var offset := neighbor.global_position - hex.global_position
			return -Vector2.RIGHT.angle_to(Vector2(offset.x, offset.z))

	return 0.0

func _get_settlement_for_hex(hex: HexBase) -> Settlement:
	if hex == null or Manager.instance == null:
		return null

	var active_scene := SceneManager.get_active_scene()
	if active_scene == null:
		return null
	var grid := active_scene.node as HexGrid
	if grid == null:
		return null

	for settlement: Settlement in Manager.instance.settlements:
		if settlement == null or not is_instance_valid(settlement):
			continue
		if not grid.is_ancestor_of(settlement):
			continue
		if settlement.contains_hex(grid, hex):
			return settlement
	return null

func _get_facing_neighbor(settlement: Settlement, hex: HexBase, rotation_y: float) -> HexBase:
	var selected_direction := Vector2.RIGHT.rotated(-rotation_y).normalized()
	var best_neighbor: HexBase = null
	var best_dot := -INF

	for direction: Vector3i in DataManager.instance.CUBE_DIRS:
		var neighbor := _get_neighbor(hex, direction)
		if not _is_valid_facing_neighbor(settlement, hex, neighbor):
			continue

		var offset := neighbor.global_position - hex.global_position
		var neighbor_direction := Vector2(offset.x, offset.z).normalized()
		var dot := selected_direction.dot(neighbor_direction)
		if dot > best_dot:
			best_dot = dot
			best_neighbor = neighbor

	return best_neighbor if best_dot > 0.99 else null

func _is_valid_facing_neighbor(settlement: Settlement, hex: HexBase, neighbor: HexBase) -> bool:
	if settlement == null or hex == null or neighbor == null:
		return false
	if not neighbor.is_traversable(HexInfo.TraversalTag.WALK):
		return false

	var active_scene := SceneManager.get_active_scene()
	if active_scene == null:
		return false
	var grid := active_scene.node as HexGrid
	if grid == null:
		return false
	if not settlement.contains_hex(grid, neighbor):
		return false
	return not settlement.has_boundary_between(grid, hex, neighbor)

func _get_neighbor(hex: HexBase, direction: Vector3i) -> HexBase:
	if hex == null:
		return null
	var active_scene := SceneManager.get_active_scene()
	if active_scene == null:
		return null
	var grid := active_scene.node as HexGrid
	if grid == null:
		return null
	return grid.get_hex_at_cube_id(hex.cube_id + direction)
