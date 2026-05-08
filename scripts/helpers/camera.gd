class_name SpringArmFollowCamera
extends Node3D

var target: Node3D

# Follow
@export var follow_speed := 8.0

# =========================
# Camera Zoom System
# =========================

@export var zoom := 0.0 # 0 = close, 1 = top-down
@export var zoom_speed := 3.0
@export var zoom_step := 0.08
@export var zoom_smoothness := 10.0
var target_zoom := 0.0

# Default (close view)
@export var min_distance := 4.0
@export var min_height := 1.5
@export var min_pitch_deg := -15.0

# Apex (bird's-eye view)
@export var max_distance := 8.0 # <-- defines apex distance
@export var max_height := 5.0
@export var max_pitch_deg := -40.0

# Rotation
@export var default_yaw_offset_deg := 30.0
@export var rotation_step_deg := 60.0
@export var rotation_speed := 12.0
var target_yaw := 0.0

# Panning
@export var pan_speed := 6.0
@export var max_pan_distance := 4.0
@export var snap_speed := 12.0
@export var snap_threshold := 0.05

var pan_offset := Vector3.ZERO
var snapping := false

var snap_camera_on_player_moving: bool = true

# Nodes
var spring_arm: SpringArm3D
var camera: Camera3D

# =========================
# Setup
# =========================

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

# =========================
# Main Loop
# =========================

func _physics_process(delta: float) -> void:
	if not target:
		return

	_handle_rotation_input()

	if snapping:
		_snap_to_center(delta)
	elif not Manager.instance.input_moves_player():
		_update_pan(delta)

	# Reduce pan when zoomed out
	var effective_pan = pan_offset * (1.0 - zoom)
	
	#zoom smoothing
	zoom = lerp(zoom, target_zoom, delta * zoom_smoothness)

	var desired_position = target.global_position + effective_pan
	global_position = global_position.lerp(
		desired_position,
		delta * follow_speed
	)

	rotation.y = lerp_angle(rotation.y, target_yaw, delta * rotation_speed)

	_apply_zoom()

# =========================
# Zoom
# =========================

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

# =========================
# Rotation
# =========================

func _handle_rotation_input() -> void:
	if Input.is_action_just_pressed("camera_rotate_left"):
		target_yaw += deg_to_rad(rotation_step_deg)

	elif Input.is_action_just_pressed("camera_rotate_right"):
		target_yaw -= deg_to_rad(rotation_step_deg)

	target_yaw = wrapf(target_yaw, -PI, PI)

# =========================
# Panning
# =========================

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

# =========================
# Utility
# =========================

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
