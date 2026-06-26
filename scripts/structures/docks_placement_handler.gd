extends RefCounted

func can_place(_structure_info: PlaceableStructureInfo, hex: HexBase, _inventory: ContentGroup) -> bool:
	return _get_water_neighbor(hex) != null

func can_place_rotation(_structure_info: PlaceableStructureInfo, hex: HexBase, _inventory: ContentGroup, rotation_y: float) -> bool:
	return _get_water_neighbor_at_rotation(hex, rotation_y) != null

func get_rotation_y(_structure_info: PlaceableStructureInfo, hex: HexBase) -> float:
	var water_neighbor := _get_water_neighbor(hex)
	if water_neighbor == null:
		return 0.0

	var direction := water_neighbor.global_position - hex.global_position
	return -Vector2.RIGHT.angle_to(Vector2(direction.x, direction.z))

func _get_water_neighbor(hex: HexBase) -> HexBase:
	if hex == null or not hex.is_traversable(HexInfo.TraversalTag.WALK):
		return null

	var grid := SceneManager.get_active_scene().node as HexGrid
	if grid == null:
		return null

	for direction: Vector3i in DataManager.instance.CUBE_DIRS:
		var neighbor := grid.get_hex_at_cube_id(hex.cube_id + direction)
		if neighbor != null and neighbor.is_traversable(HexInfo.TraversalTag.BOAT):
			return neighbor

	return null

func _get_water_neighbor_at_rotation(hex: HexBase, rotation_y: float) -> HexBase:
	if hex == null or not hex.is_traversable(HexInfo.TraversalTag.WALK):
		return null

	var grid := SceneManager.get_active_scene().node as HexGrid
	if grid == null:
		return null

	var selected_direction := Vector2.RIGHT.rotated(-rotation_y).normalized()
	for direction: Vector3i in DataManager.instance.CUBE_DIRS:
		var neighbor := grid.get_hex_at_cube_id(hex.cube_id + direction)
		if neighbor == null or not neighbor.is_traversable(HexInfo.TraversalTag.BOAT):
			continue

		var neighbor_offset := neighbor.global_position - hex.global_position
		var neighbor_direction := Vector2(neighbor_offset.x, neighbor_offset.z).normalized()
		if selected_direction.dot(neighbor_direction) > 0.99:
			return neighbor

	return null
