class_name SpringArmFollowCamera
extends Node3D

var target: Node3D

# Follow
@export var follow_speed := 8.0

# Camera parameters
@export var camera_distance := 6.0
@export var camera_height := 2.5
@export var camera_pitch_deg := -15.0

# Panning
@export var pan_speed := 6.0
@export var max_pan_distance := 4.0
@export var snap_speed := 12.0
@export var snap_threshold := 0.05
var snapping := false

var pan_offset := Vector3.ZERO

var spring_arm: SpringArm3D
var camera: Camera3D


func _ready() -> void:
	_build_camera_hierarchy()
	Manager.instance.camera = self;


func _build_camera_hierarchy() -> void:
	# Pivot = this node
	spring_arm = SpringArm3D.new()
	spring_arm.name = "SpringArm3D"
	add_child(spring_arm)

	spring_arm.spring_length = camera_distance
	spring_arm.position = Vector3(0, camera_height, 0)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	spring_arm.add_child(camera)

	camera.rotation_degrees.x = camera_pitch_deg
	camera.current = true

func _physics_process(delta: float) -> void:
	if not target:
		return

	if Input.is_action_just_pressed("camera_reset"):
		snapping = true

	if snapping:
		_snap_to_center(delta)
	else:
		_update_pan(delta)

	var desired_position = target.global_position + pan_offset
	global_position = global_position.lerp(
		desired_position,
		delta * follow_speed
	)
	
func _snap_to_center(delta: float) -> void:
	pan_offset = pan_offset.lerp(Vector3.ZERO, delta * snap_speed)

	if pan_offset.length() <= snap_threshold:
		pan_offset = Vector3.ZERO
		snapping = false
	
func _update_pan(delta: float) -> void:
	var input := Vector2(
		Input.get_action_strength("camera_pan_right")
			- Input.get_action_strength("camera_pan_left"),
		Input.get_action_strength("camera_pan_forward")
			- Input.get_action_strength("camera_pan_backward")
	)

	if input == Vector2.ZERO:
		return

	var move := (Vector3.RIGHT * input.x + Vector3.FORWARD * input.y).normalized()
	pan_offset += move * pan_speed * delta

	if pan_offset.length() > max_pan_distance:
		pan_offset = pan_offset.normalized() * max_pan_distance
