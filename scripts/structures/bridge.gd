extends Node3D

@export_range(0.01, 1.0, 0.01) var walkway_center_half_width := 0.08

func supports_traversal(method: HexInfo.TraversalTag) -> bool:
	return method == HexInfo.TraversalTag.WALK

func can_traverse_edge(edge: int, method: HexInfo.TraversalTag, _hex: HexBase) -> bool:
	if not supports_traversal(method):
		return false
	var grid := _get_grid(_hex)
	if grid == null:
		return false
	var neighbor := grid.get_hex_at_cube_id(
		_hex.cube_id + DataManager.instance.CUBE_DIRS[edge]
	)
	if neighbor == null:
		return false
	var bridge_axis := Vector2(global_basis.x.x, global_basis.x.z).normalized()
	var offset := neighbor.global_position - _hex.global_position
	var edge_direction := Vector2(offset.x, offset.z).normalized()
	return absf(bridge_axis.dot(edge_direction)) > 0.99

func get_edge_elevation_units(_edge: int, _method: HexInfo.TraversalTag, hex: HexBase) -> int:
	return hex.elevation_units + roundi(position.y / hex.elevation_unit_height)

func get_surface_height_at(_world_position: Vector3, _method: HexInfo.TraversalTag, _hex: HexBase) -> float:
	return global_position.y

func can_stand_at(world_position: Vector3, method: HexInfo.TraversalTag, _hex: HexBase) -> bool:
	if not supports_traversal(method):
		return false
	var local_position := global_transform.affine_inverse() * world_position
	return absf(local_position.z) <= walkway_center_half_width

func _get_grid(hex: HexBase) -> HexGrid:
	var current := hex.get_parent()
	while current != null:
		if current is HexGrid:
			return current as HexGrid
		current = current.get_parent()
	return null
