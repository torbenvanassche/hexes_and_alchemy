class_name LocationMarker
extends Node3D

## The scene's origin is the arrow tip, so clearance is measured from the roof.
@export_range(0.02, 0.5, 0.01) var clearance := 0.12
@export_range(0.0, 0.3, 0.01) var bob_height := 0.06
@export_range(0.5, 6.0, 0.1) var bob_period := 2.4

var target: Node3D
var _bob_phase := 0.0

func track(location: Node3D) -> void:
	if target == location:
		return
	target = location
	_bob_phase = 0.0
	_update_marker()

func _process(delta: float) -> void:
	_bob_phase = fposmod(_bob_phase + TAU * delta / bob_period, TAU)
	_update_marker()

func _update_marker() -> void:
	visible = is_instance_valid(target) and target.is_inside_tree() and target.is_visible_in_tree()
	if not visible:
		return
	var bounds := get_visible_bounds(target)
	# Only bob upward from the clearance so the tip never clips into the roof.
	var lift := bob_height * (0.5 - 0.5 * cos(_bob_phase))
	global_position = Vector3(bounds.get_center().x, bounds.end.y + clearance + lift, bounds.get_center().z)

static func get_visible_bounds(location: Node3D) -> AABB:
	var meshes: Array[Node] = location.find_children("*", "MeshInstance3D", true, false)
	if location is MeshInstance3D:
		meshes.append(location)
	var bounds := AABB(location.global_position, Vector3.ZERO)
	var found := false
	for node: MeshInstance3D in meshes:
		if node.mesh == null or not node.is_visible_in_tree():
			continue
		var mesh_bounds: AABB = node.global_transform * node.get_aabb()
		bounds = bounds.merge(mesh_bounds) if found else mesh_bounds
		found = true
	return bounds
