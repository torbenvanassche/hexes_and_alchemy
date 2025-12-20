class_name PlayerController
extends CharacterBody3D

@export var move_speed := 6.0
@export var acceleration := 10.0

func _physics_process(delta: float) -> void:
	if Manager.instance.input_moves_player():
		_handle_movement(delta)
		move_and_slide()

func _handle_movement(delta: float) -> void:
	var input := Vector2(
		Input.get_action_strength("move_right")
			- Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward")
			- Input.get_action_strength("move_backward")
	)

	if input.length() > 1.0:
		input = input.normalized()

	var cam_basis := Manager.instance.camera.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0
	forward = forward.normalized()

	var right := cam_basis.x
	right.y = 0
	right = right.normalized()

	var move_dir := (right * input.x + forward * input.y)
	
	if move_dir.length() > 0.01:
		var desired_velocity := move_dir.normalized() * move_speed
		var next_pos := global_position + desired_velocity * delta

		var hex := Manager.instance.hex_grid.get_hex_at_world_position(next_pos)
		if hex == null or not hex.is_walkable(self):
			velocity = Vector3(0, velocity.y, 0)
			return

	var target_velocity := move_dir * move_speed
	velocity.x = lerp(velocity.x, target_velocity.x, delta * acceleration)
	velocity.z = lerp(velocity.z, target_velocity.z, delta * acceleration)
	
	if move_dir.length() > 0.1:
		var target_rot := atan2(move_dir.x, move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 10.0)
