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

static func cube_distance(a: Vector3i, b: Vector3i) -> int:
	return (abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z)) / 2

static func get_world_polygon(csgPolygon: CSGPolygon3D) -> PackedVector2Array:
	var poly := csgPolygon.polygon
	var result := PackedVector2Array()

	for p in poly:
		var world := csgPolygon.global_transform * Vector3(p.x, p.y, 0)
		result.append(Vector2(world.x, world.z))
	return result

static func world_to_offset(world_pos: Vector3, inner_radius: float, spacing_extra: float, pointy_top: bool) -> Vector2i:
	var spacing := get_spacing(inner_radius, spacing_extra, pointy_top)

	if pointy_top:
		var gx := int(round(world_pos.x / spacing.x))
		var gz_offset := (gx & 1) * (spacing.y / 2.0)
		var gy := int(round((world_pos.z - gz_offset) / spacing.y))
		return Vector2i(gx, gy)
	else:
		var gy := int(round(world_pos.z / spacing.y))
		var gx_offset := (gy & 1) * (spacing.x / 2.0)
		var gx := int(round((world_pos.x - gx_offset) / spacing.x))
		return Vector2i(gx, gy)

static func get_hex_polygon(center: Vector3, inner_radius: float, pointy_top: bool) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var outer_radius := inner_radius / cos(deg_to_rad(30.0))
	var start_angle_deg := -30.0 if pointy_top else 0.0
	
	for i in range(6):
		var angle := deg_to_rad(start_angle_deg + 60.0 * i)
		polygon.append(Vector2(
			center.x + cos(angle) * outer_radius,
			center.z + sin(angle) * outer_radius
		))
	
	return polygon

static func is_point_in_hex(world_pos: Vector3, center: Vector3, inner_radius: float, pointy_top: bool) -> bool:
	return Geometry2D.is_point_in_polygon(
		Vector2(world_pos.x, world_pos.z),
		get_hex_polygon(center, inner_radius, pointy_top)
	)
