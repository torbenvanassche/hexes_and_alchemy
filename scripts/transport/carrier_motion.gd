class_name CarrierMotion
extends Node3D

## Presentation only: routing, cargo and ground position stay on the root.
## Saddle and packs share the same small motion as the static horse mesh.
@export var moving_parts: Array[NodePath] = [NodePath("Model"), NodePath("Saddle"), NodePath("Cargo")]
@export_range(0.0, 0.04, 0.001) var bob_height := 0.012
@export_range(0.2, 2.0, 0.05) var stride_distance := 0.9
@export var turn_response := 8.0
@export var settle_response := 12.0
@export var roll_degrees := 0.8
@export var pitch_degrees := 0.6

var _parts: Array[Node3D] = []
var _rest_transforms: Array[Transform3D] = []
var _phase := 0.0
var _travelled := 0.0
var _motion_weight := 0.0
var _target_yaw := 0.0
var _heading_set := false

func _ready() -> void:
	for path: NodePath in moving_parts:
		var part := get_node_or_null(path) as Node3D
		if part != null:
			_parts.append(part)
			_rest_transforms.append(part.transform)

func face_heading(yaw: float) -> void:
	_target_yaw = yaw
	if not _heading_set:
		rotation.y = yaw
		_heading_set = true

func face_travel_direction(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length_squared() > 0.000001:
		face_heading(atan2(direction.x, direction.z))

func record_distance(distance: float) -> void:
	_travelled += maxf(0.0, distance)

func update_motion(delta: float, moving: bool) -> void:
	_phase = fposmod(_phase + TAU * _travelled / maxf(0.01, stride_distance), TAU)
	var target_weight := 1.0 if moving and _travelled > 0.000001 else 0.0
	_travelled = 0.0
	var elapsed := maxf(0.0, delta)
	rotation.y = lerp_angle(rotation.y, _target_yaw, 1.0 - exp(-turn_response * elapsed))
	_motion_weight = lerpf(_motion_weight, target_weight, 1.0 - exp(-settle_response * elapsed))
	var lift := (0.5 - 0.5 * cos(_phase)) * bob_height * _motion_weight
	var angles := Vector3(sin(_phase * 2.0) * deg_to_rad(pitch_degrees), 0.0, sin(_phase) * deg_to_rad(roll_degrees)) * _motion_weight
	var motion := Transform3D(Basis.from_euler(angles), Vector3(0, lift, 0))
	for index in _parts.size():
		_parts[index].transform = motion * _rest_transforms[index]
