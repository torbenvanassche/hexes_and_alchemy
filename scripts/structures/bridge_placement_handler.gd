extends RefCounted

func can_place(_structure_info: PlaceableStructureInfo, hex: HexBase, _inventory: ContentGroup) -> bool:
	if not _is_valid_center(hex):
		return false
	for direction_index in range(3):
		if not _get_bridge_pair(hex, direction_index).is_empty():
			return true
	return false

func can_place_rotation(_structure_info: PlaceableStructureInfo, hex: HexBase, _inventory: ContentGroup, rotation_y: float) -> bool:
	if not _is_valid_center(hex):
		return false
	var direction_index := _get_direction_index(hex, rotation_y)
	return direction_index >= 0 and not _get_bridge_pair(hex, direction_index).is_empty()

func get_rotation_y(_structure_info: PlaceableStructureInfo, hex: HexBase) -> float:
	if not _is_valid_center(hex):
		return 0.0
	for direction_index in range(3):
		if _get_bridge_pair(hex, direction_index).is_empty():
			continue
		var neighbor := _get_grid().get_hex_at_cube_id(
			hex.cube_id + DataManager.instance.CUBE_DIRS[direction_index]
		)
		var direction := neighbor.global_position - hex.global_position
		return -Vector2.RIGHT.angle_to(Vector2(direction.x, direction.z))
	return 0.0

func get_placement_offset(_structure_info: PlaceableStructureInfo, hex: HexBase, rotation_y: float) -> Vector3:
	if not _is_valid_center(hex):
		return Vector3.ZERO
	var resolved_rotation := rotation_y
	if resolved_rotation != resolved_rotation:
		resolved_rotation = get_rotation_y(_structure_info, hex)
	var direction_index := _get_direction_index(hex, resolved_rotation)
	var pair := _get_bridge_pair(hex, direction_index)
	if pair.is_empty():
		return Vector3.ZERO
	var height_units := int(pair["height_units"])
	return Vector3.UP * float(height_units - hex.elevation_units) * hex.elevation_unit_height

func _is_valid_center(hex: HexBase) -> bool:
	if hex == null or not hex.is_explored or hex.scene_instance == null:
		return false
	var hex_info := hex.scene_instance.scene_info as HexInfo
	return (
		hex_info != null
		and hex_info.traversal_tags.has(HexInfo.TraversalTag.BOAT)
		and not hex_info.traversal_tags.has(HexInfo.TraversalTag.WALK)
	)

func _get_bridge_pair(hex: HexBase, direction_index: int) -> Dictionary:
	var grid := _get_grid()
	if grid == null or direction_index < 0:
		return {}
	var direction_count := DataManager.instance.CUBE_DIRS.size()
	var opposite_index := posmod(direction_index + 3, direction_count)
	var forward := grid.get_hex_at_cube_id(
		hex.cube_id + DataManager.instance.CUBE_DIRS[direction_index]
	)
	var backward := grid.get_hex_at_cube_id(
		hex.cube_id + DataManager.instance.CUBE_DIRS[opposite_index]
	)
	if not _is_valid_bank(forward) or not _is_valid_bank(backward):
		return {}
	var forward_height := forward.get_edge_elevation_units_for_method(
		opposite_index, HexInfo.TraversalTag.WALK
	)
	var backward_height := backward.get_edge_elevation_units_for_method(
		direction_index, HexInfo.TraversalTag.WALK
	)
	if forward_height != backward_height:
		return {}
	if forward_height <= 0 or forward_height <= hex.elevation_units:
		return {}
	return {
		"forward": forward,
		"backward": backward,
		"height_units": forward_height,
	}

func _is_valid_bank(hex: HexBase) -> bool:
	return (
		hex != null
		and hex.is_explored
		and hex.structure == null
		and hex.is_traversable(HexInfo.TraversalTag.WALK)
	)

func _get_direction_index(hex: HexBase, rotation_y: float) -> int:
	if hex == null:
		return -1
	var grid := _get_grid()
	if grid == null:
		return -1
	var selected_direction := Vector2.RIGHT.rotated(-rotation_y).normalized()
	var best_index := -1
	var best_dot := -INF
	for direction_index in DataManager.instance.CUBE_DIRS.size():
		var neighbor := grid.get_hex_at_cube_id(
			hex.cube_id + DataManager.instance.CUBE_DIRS[direction_index]
		)
		if neighbor == null:
			continue
		var offset := neighbor.global_position - hex.global_position
		var direction := Vector2(offset.x, offset.z).normalized()
		var dot := selected_direction.dot(direction)
		if dot > best_dot:
			best_dot = dot
			best_index = direction_index
	return best_index if best_dot > 0.99 else -1

func _get_grid() -> HexGrid:
	var active_scene := SceneManager.get_active_scene()
	if active_scene == null:
		return null
	return active_scene.node as HexGrid
