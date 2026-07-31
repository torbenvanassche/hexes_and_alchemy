class_name HexSlope
extends HexBase

enum HexEdge {
	EDGE_0,
	EDGE_1,
	EDGE_2,
	EDGE_3,
	EDGE_4,
	EDGE_5,
}

@export_group("Slope Asset Profile")
@export var asset_uphill_edge: HexEdge = HexEdge.EDGE_0
@export_range(1, 2, 1) var slope_rise_units := 1
@export_flags("EDGE_0", "EDGE_1", "EDGE_2", "EDGE_3", "EDGE_4", "EDGE_5") var connector_mask := (1 << HexEdge.EDGE_0) | (1 << HexEdge.EDGE_3)
@export_flags("EDGE_0", "EDGE_1", "EDGE_2", "EDGE_3", "EDGE_4", "EDGE_5") var navigation_only_mask := 0
@export var edge_height_offsets := PackedInt32Array([1, 0, 0, 0, 0, 0])

const EDGE_DIRECTIONS: Array[Vector3] = [
	Vector3(1.0, 0.0, 0.0),
	Vector3(0.5, 0.0, -0.8660254),
	Vector3(-0.5, 0.0, -0.8660254),
	Vector3(-1.0, 0.0, 0.0),
	Vector3(-0.5, 0.0, 0.8660254),
	Vector3(0.5, 0.0, 0.8660254),
]
const SURFACE_COLLISION_LAYER := 1 << 3
static var _surface_collision_shape_cache: Dictionary = {}

func _ready() -> void:
	super()
	_add_surface_collision()

func get_uphill_edge(rotation_steps: int = 0) -> int:
	return posmod(int(asset_uphill_edge) + rotation_steps, 6)

func get_downhill_edge(rotation_steps: int = 0) -> int:
	return posmod(get_uphill_edge(rotation_steps) + 3, 6)

func get_edge_elevation_units(edge: int) -> int:
	var local_edge := _get_local_edge(edge)
	return elevation_units + _get_edge_height_offset(local_edge)

func can_traverse_edge(edge: int, method: HexInfo.TraversalTag) -> bool:
	if not is_traversable(method):
		return false
	var local_edge := _get_local_edge(edge)
	var edge_mask := 1 << local_edge
	return (connector_mask & edge_mask) != 0 or (navigation_only_mask & edge_mask) != 0

func get_surface_height_at(world_position: Vector3) -> float:
	var local_position := to_local(world_position)
	var uphill_direction := EDGE_DIRECTIONS[int(asset_uphill_edge)]
	var slope_progress := clampf((local_position.dot(uphill_direction) + 1.0) * 0.5, 0.0, 1.0)
	return global_position.y + slope_progress * float(slope_rise_units) * elevation_unit_height

func _get_rotation_steps() -> int:
	return posmod(roundi(rotation.y / (TAU / 6.0)), 6)

func _get_local_edge(world_edge: int) -> int:
	return posmod(world_edge - _get_rotation_steps(), 6)

func _get_edge_height_offset(local_edge: int) -> int:
	if local_edge < 0 or local_edge >= edge_height_offsets.size():
		return 0
	return clampi(edge_height_offsets[local_edge], 0, slope_rise_units)

func _add_surface_collision() -> void:
	if ground_hex_mesh == null or ground_hex_mesh.mesh == null:
		return

	var mesh_rid := ground_hex_mesh.mesh.get_rid()
	var surface_shape := _surface_collision_shape_cache.get(mesh_rid) as Shape3D
	if surface_shape == null:
		surface_shape = ground_hex_mesh.mesh.create_trimesh_shape()
		_surface_collision_shape_cache[mesh_rid] = surface_shape

	var body := StaticBody3D.new()
	body.name = "SlopeSurface"
	body.collision_layer = SURFACE_COLLISION_LAYER
	body.collision_mask = 0
	body.set_meta("slope_surface", true)

	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = surface_shape
	body.add_child(collision_shape)
	ground_hex_mesh.add_child(body)
	static_body = body
