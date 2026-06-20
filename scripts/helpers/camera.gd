class_name SpringArmFollowCamera
extends Node3D

enum RotationMode {
	SNAP,
	SMOOTH
}

var target: Node3D

@export var snap_camera_on_player_moving := true

@export_group("Follow")
@export_range(0.0, 30.0, 0.1) var follow_speed := 8.0

@export_group("Zoom")
@export_range(0.0, 1.0, 0.01) var zoom := 0.0 # 0 = close, 1 = top-down
@export_range(0.01, 0.5, 0.01) var zoom_step := 0.08
@export_range(0.0, 30.0, 0.1) var zoom_smoothness := 10.0
@export_range(0.0, 4.0, 0.01) var controller_zoom_speed := 0.75
var target_zoom := 0.0

@export_subgroup("Zoom Close View")
@export_range(0.0, 50.0, 0.1) var min_distance := 4.0
@export_range(0.0, 20.0, 0.1) var min_height := 1.5
@export_range(-89.0, 0.0, 0.1) var min_pitch_deg := -15.0

@export_subgroup("Zoom Far View")
@export_range(0.0, 50.0, 0.1) var max_distance := 8.0
@export_range(0.0, 20.0, 0.1) var max_height := 5.0
@export_range(-89.0, 0.0, 0.1) var max_pitch_deg := -40.0

@export_group("Rotation")
@export var rotation_mode: RotationMode = RotationMode.SNAP
@export_range(-180.0, 180.0, 1.0) var default_yaw_offset_deg := 30.0
@export_range(0.0, 30.0, 0.1) var rotation_speed := 12.0
@export_subgroup("Rotation Snap")
@export_range(1.0, 180.0, 1.0) var rotation_step_deg := 60.0
@export_subgroup("Rotation Smooth")
@export_range(1.0, 720.0, 1.0) var smooth_rotation_turn_speed_deg := 180.0
@export_range(0.0, 1.0, 0.01) var controller_stick_deadzone := 0.2
var target_yaw := 0.0

@export_group("Panning")
@export_range(0.0, 30.0, 0.1) var pan_speed := 6.0
@export_range(0.0, 20.0, 0.1) var max_pan_distance := 4.0
@export_range(0.0, 30.0, 0.1) var snap_speed := 12.0
@export_range(0.0, 1.0, 0.01) var snap_threshold := 0.05

var pan_offset := Vector3.ZERO
var snapping := false

var spring_arm: SpringArm3D
var camera: Camera3D

func snap_camera_on_player_moved(b: bool) -> void:
	snapping = b && snap_camera_on_player_moving

func _ready() -> void:
	_build_camera_hierarchy()
	Manager.instance.spring_arm_camera = self
	target_yaw = rotation.y + deg_to_rad(default_yaw_offset_deg)

func _build_camera_hierarchy() -> void:
	spring_arm = SpringArm3D.new()
	spring_arm.name = "SpringArm3D"
	add_child(spring_arm)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	spring_arm.add_child(camera)

	camera.current = true

func _physics_process(delta: float) -> void:
	if not target:
		return

	if Input.is_action_just_pressed("camera_zoom_in"):
		target_zoom -= zoom_step
	if Input.is_action_just_pressed("camera_zoom_out"):
		target_zoom += zoom_step
	_handle_controller_zoom(delta)
	target_zoom = clamp(target_zoom, 0.0, 1.0)

	_handle_rotation_input(delta)

	if snapping:
		_snap_to_center(delta)
	elif not Manager.instance.input_moves_player():
		_update_pan(delta)
	var effective_pan = pan_offset * (1.0 - zoom)
	zoom = lerp(zoom, target_zoom, delta * zoom_smoothness)

	var desired_position = target.global_position + effective_pan
	global_position = global_position.lerp(
		desired_position,
		delta * follow_speed
	)

	rotation.y = lerp_angle(rotation.y, target_yaw, delta * rotation_speed)

	_apply_zoom()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom -= zoom_step
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom += zoom_step

		target_zoom = clamp(target_zoom, 0.0, 1.0)

func _apply_zoom() -> void:
	var distance = lerp(min_distance, max_distance, zoom)
	var height = lerp(min_height, max_height, zoom)
	var pitch = lerp(min_pitch_deg, max_pitch_deg, zoom)

	spring_arm.spring_length = distance
	spring_arm.position.y = height
	camera.rotation_degrees.x = pitch

func _handle_rotation_input(delta: float) -> void:
	var controller_rotation_input := _get_controller_axis(JOY_AXIS_RIGHT_X)
	if absf(controller_rotation_input) > controller_stick_deadzone:
		target_yaw -= controller_rotation_input * deg_to_rad(smooth_rotation_turn_speed_deg) * delta
	elif rotation_mode == RotationMode.SMOOTH:
		var rotation_input := Input.get_action_strength("camera_rotate_left") - Input.get_action_strength("camera_rotate_right")
		if absf(rotation_input) > 0.0:
			target_yaw += rotation_input * deg_to_rad(smooth_rotation_turn_speed_deg) * delta
	else:
		if Input.is_action_just_pressed("camera_rotate_left"):
			target_yaw += deg_to_rad(rotation_step_deg)
		elif Input.is_action_just_pressed("camera_rotate_right"):
			target_yaw -= deg_to_rad(rotation_step_deg)

	target_yaw = wrapf(target_yaw, -PI, PI)

func _handle_controller_zoom(delta: float) -> void:
	var controller_zoom_input := _get_controller_axis(JOY_AXIS_RIGHT_Y)
	if absf(controller_zoom_input) <= controller_stick_deadzone:
		return

	target_zoom += controller_zoom_input * controller_zoom_speed * delta

func _get_controller_axis(axis: int) -> float:
	for device in Input.get_connected_joypads():
		var value := Input.get_joy_axis(device, axis)
		if absf(value) > controller_stick_deadzone:
			return value
	return 0.0

func _snap_to_center(delta: float) -> void:
	pan_offset = pan_offset.lerp(Vector3.ZERO, delta * snap_speed)

	if pan_offset.length() <= snap_threshold:
		pan_offset = Vector3.ZERO
		snapping = false

func _update_pan(delta: float) -> void:
	var input := Vector2(
		Input.get_action_strength("camera_pan_right") - Input.get_action_strength("camera_pan_left"),
		Input.get_action_strength("camera_pan_forward") - Input.get_action_strength("camera_pan_backward")
	)

	if input == Vector2.ZERO:
		return

	var right := global_transform.basis.x
	right.y = 0
	right = right.normalized()

	var forward := -global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()

	var move := (right * input.x + forward * input.y).normalized()
	pan_offset += move * pan_speed * delta

	if pan_offset.length() > max_pan_distance:
		pan_offset = pan_offset.normalized() * max_pan_distance

func get_ray_hit_from_screen_point() -> Dictionary:
	var screen_point: Vector2 = get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(screen_point)
	var to := from + camera.project_ray_normal(screen_point) * 1000.0

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := space_state.intersect_ray(query)

	return result if result else {}

func snap_to_target() -> void:
	_snap_to_center(0)
