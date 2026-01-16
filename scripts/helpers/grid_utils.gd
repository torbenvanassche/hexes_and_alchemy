class_name GridUtils extends Node

static func offset_to_cube(grid: Vector2i, pointy_top: bool) -> Vector3i:
	if pointy_top:
		var x: int = grid.x
		var z: int = grid.y - ((grid.x - (grid.x & 1)) >> 1)
		var y: int = -x - z
		return Vector3i(x, y, z)
	else:
		var x: int = grid.x - ((grid.y - (grid.y & 1)) >> 1)
		var z: int = grid.y
		var y: int = -x - z
		return Vector3i(x, y, z)

static func get_spacing(inner_radius: float, spacing: float, pointy_top: bool) -> Vector2:
	if pointy_top:
		return Vector2(3.0 * inner_radius / 2.0 + spacing, sqrt(3.0) * inner_radius + spacing)
	else:
		return Vector2(sqrt(3.0) * inner_radius + spacing, 3.0 * inner_radius / 2.0 + spacing)

static func cube_distance(a: Vector3i, b: Vector3i) -> float:
	return a.distance_to(b)
