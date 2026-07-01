class_name PlayerMovement
extends Node

@export var move_speed := 6.0
@export var acceleration := 10.0
@export var dash_modifier := 1.5
@export_range(0.0, 1.5, 0.01) var water_edge_stop_distance := 0.3
@export_range(0, 8, 1) var exploration_radius := 2

enum MovementMode {
	WALK,
	WATER
}

var movement_mode := MovementMode.WALK
var player: PlayerController
var _last_explored_hex: Vector3i = Vector3i.ZERO
var _has_explored_hex := false
var _last_traversable_hex: HexBase
var _last_safe_position := Vector3.ZERO
var _has_safe_position := false

func _ready() -> void:
	player = get_parent() as PlayerController

func physics_process(delta: float) -> void:
	if player == null:
		return
	
	if Manager.instance.input_moves_player():
		_handle_movement(delta)
		player.move_and_slide()

func _handle_movement(delta: float) -> void:
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
	)

	if input.length() > 1.0:
		input = input.normalized()

	var cam_basis := Manager.instance.spring_arm_camera.global_transform.basis

	var forward := -cam_basis.z
	forward.y = 0
	forward = forward.normalized()

	var right := cam_basis.x
	right.y = 0
	right = right.normalized()

	var move_dir := (right * input.x + forward * input.y)

	var target_velocity := move_dir * move_speed
	if Input.is_action_pressed("move_sprint"):
		target_velocity *= dash_modifier
	
	var next_velocity := player.velocity
	next_velocity.x = lerp(player.velocity.x, target_velocity.x, delta * acceleration)
	next_velocity.z = lerp(player.velocity.z, target_velocity.z, delta * acceleration)

	if move_dir.length() > 0.01:
		var grid := SceneManager.get_active_scene().node as HexGrid
		if grid:
			if not _can_move_to_next_hex(grid, move_dir, next_velocity, delta):
				return
		else:
			Debug.message("Active scene is not a hexgrid, cannot walk")
			return

	player.velocity.x = next_velocity.x
	player.velocity.z = next_velocity.z

	if move_dir.length() > 0.1:
		var target_rot := atan2(move_dir.x, move_dir.z)
		player.rotation.y = lerp_angle(player.rotation.y, target_rot, delta * 10.0)

func _can_move_to_next_hex(grid: HexGrid, move_dir: Vector3, next_velocity: Vector3, delta: float) -> bool:
	var current_hex := update_navigation_state(grid)
	
	if current_hex == null:
		_stop()
		return false
	
	var next_position := player.global_position + Vector3(next_velocity.x, 0.0, next_velocity.z) * delta
	var target_hex := grid.get_hex_at_world_position(next_position, 0.0)
	var edge_probe_position := next_position + move_dir.normalized() * water_edge_stop_distance
	var edge_probe_hex := grid.get_hex_at_world_position(edge_probe_position, 0.0)
	
	if target_hex == null:
		target_hex = current_hex
	
	if edge_probe_hex == null:
		edge_probe_hex = target_hex
	
	if target_hex != current_hex and not _is_hex_traversable(target_hex):
		_stop()
		return false
	
	if edge_probe_hex != current_hex and not _is_hex_traversable(edge_probe_hex):
		_stop()
		return false
	
	if not _is_hex_traversable(current_hex):
		_stop()
		return false
	
	return true

func _stop() -> void:
	player.velocity.x = 0.0
	player.velocity.z = 0.0

func update_navigation_state(grid: HexGrid) -> HexBase:
	if player == null or grid == null:
		return null
	
	var raw_current_hex := grid.get_hex_at_world_position(player.global_position, 0.0)
	if raw_current_hex != null:
		if _is_hex_traversable(raw_current_hex):
			remember_safe_navigation(raw_current_hex)
		elif _has_safe_position:
			player.global_position = _last_safe_position
			raw_current_hex = _last_traversable_hex
	
	var current_hex: HexBase = raw_current_hex if raw_current_hex != null and _is_hex_traversable(raw_current_hex) else _last_traversable_hex
	if current_hex != null:
		grid.generate_chunks_around_grid_id(current_hex.grid_id)
	explore_visible_tiles(grid, current_hex)
	return current_hex

func remember_safe_navigation(hex: HexBase) -> void:
	if player == null or hex == null:
		return
	
	_last_traversable_hex = hex
	_last_safe_position = player.global_position
	_has_safe_position = true

func explore_visible_tiles(grid: HexGrid, center_hex: HexBase) -> void:
	if grid == null or center_hex == null:
		return
	
	if _has_explored_hex and _last_explored_hex == center_hex.cube_id:
		return
	
	_has_explored_hex = true
	_last_explored_hex = center_hex.cube_id
	
	for nearby_tile in grid.get_tiles_in_radius(center_hex.cube_id, exploration_radius):
		(nearby_tile.node as HexBase).is_explored = true

func get_hex() -> HexBase:
	if player == null:
		return null
	
	var grid := SceneManager.get_active_scene().node as HexGrid
	if grid == null:
		return null
	
	var current_hex := grid.get_hex_at_world_position(player.global_position, 0.0)
	if current_hex != null and _is_hex_traversable(current_hex):
		remember_safe_navigation(current_hex)
		return current_hex
	
	if is_instance_valid(_last_traversable_hex):
		return _last_traversable_hex
	return null

func set_movement_mode(mode: MovementMode) -> void:
	if movement_mode == mode:
		return
	
	movement_mode = mode
	_last_traversable_hex = null
	_last_safe_position = Vector3.ZERO
	_has_safe_position = false

func _is_hex_traversable(hex: HexBase) -> bool:
	if hex == null:
		return false
	return hex.is_traversable(_get_traversal_tag())

func _get_traversal_tag() -> HexInfo.TraversalTag:
	match movement_mode:
		MovementMode.WATER:
			return HexInfo.TraversalTag.BOAT
		_:
			return HexInfo.TraversalTag.WALK
