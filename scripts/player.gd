class_name PlayerController
extends CharacterBody3D

@export var move_speed := 6.0
@export var acceleration := 10.0
@export var dash_modifier := 1.5;
@export_range(0.0, 1.5, 0.01) var water_edge_stop_distance := 0.3

@onready var interactor: Area3D = $interactor;
@onready var inventory: Inventory = $Inventory;

var current_triggers: Array[Interaction] = [];
var return_position: Vector3;
var _last_explored_hex: Vector3i = Vector3i.ZERO
var _has_explored_hex: bool = false
var _last_traversable_hex: HexBase
var _last_safe_position: Vector3 = Vector3.ZERO
var _has_safe_position: bool = false

var currency: int;

func _ready() -> void:
	interactor.area_entered.connect(add_trigger)
	interactor.area_exited.connect(remove_trigger)

func _physics_process(delta: float) -> void:
	if Manager.instance.input_moves_player():
		_handle_movement(delta)
		move_and_slide()
		
func _unhandled_input(_event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() != null:
		return;
		
	if Input.is_action_just_pressed("primary_action"):
		if current_triggers.size() != 0:
			current_triggers[0].on_interact();
		else:
			var picked := pick_hex_from_mouse()
	
	if Input.is_action_just_pressed("inventory"):
		_toggle_inventory()

func pick_hex_from_mouse() -> HexBase:
	var grid := SceneManager.get_active_scene().node as HexGrid
	if grid == null:
		return null
	
	var camera_controller := Manager.instance.spring_arm_camera
	if camera_controller == null or camera_controller.camera == null:
		return null
	
	var camera := camera_controller.camera
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var grid_plane := Plane(Vector3.UP, grid.global_position.y)
	var hit_position = grid_plane.intersects_ray(ray_origin, ray_direction)
	if hit_position == null:
		return null
	
	var picked_hex := grid.get_hex_at_world_position(hit_position, 0.0)
	if picked_hex == null:
		return null
	
	if grid is MainGrid and (grid as MainGrid).target_position != null:
		(grid as MainGrid).target_position.global_position = picked_hex.global_position
	
	return picked_hex

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
		target_velocity *= dash_modifier;
	
	var next_velocity := velocity
	next_velocity.x = lerp(velocity.x, target_velocity.x, delta * acceleration)
	next_velocity.z = lerp(velocity.z, target_velocity.z, delta * acceleration)

	if move_dir.length() > 0.01:
		var grid := SceneManager.get_active_scene().node as HexGrid;
		if grid:
			var raw_current_hex := grid.get_hex_at_world_position(global_position, 0.0)
			if raw_current_hex != null:
				if raw_current_hex.is_traversable():
					_remember_safe_navigation(raw_current_hex)
				elif _has_safe_position:
					global_position = _last_safe_position
					raw_current_hex = _last_traversable_hex
			
			var current_hex: HexBase = raw_current_hex if raw_current_hex != null and raw_current_hex.is_traversable() else _last_traversable_hex
			var next_position := global_position + Vector3(next_velocity.x, 0.0, next_velocity.z) * delta
			var target_hex := grid.get_hex_at_world_position(next_position, 0.0)
			var edge_probe_position := next_position + move_dir.normalized() * water_edge_stop_distance
			var edge_probe_hex := grid.get_hex_at_world_position(edge_probe_position, 0.0)
			_explore_visible_tiles(grid, current_hex)
			
			if current_hex == null:
				velocity.x = 0.0
				velocity.z = 0.0
				return
			
			if target_hex == null:
				target_hex = current_hex
			
			if edge_probe_hex == null:
				edge_probe_hex = target_hex
			
			if target_hex != current_hex and not target_hex.is_traversable():
				velocity.x = 0.0
				velocity.z = 0.0
				return
			
			if edge_probe_hex != current_hex and not edge_probe_hex.is_traversable():
				velocity.x = 0.0
				velocity.z = 0.0
				return
			
			if not current_hex.is_traversable():
				velocity.x = 0.0
				velocity.z = 0.0
				return
		else:
			Debug.message("Active scene is not a hexgrid, cannot walk")
			return;

	velocity.x = next_velocity.x
	velocity.z = next_velocity.z

	if move_dir.length() > 0.1:
		var target_rot := atan2(move_dir.x, move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 10.0)

func _remember_safe_navigation(hex: HexBase) -> void:
	_last_traversable_hex = hex
	_last_safe_position = global_position
	_has_safe_position = true

func _explore_visible_tiles(grid: HexGrid, center_hex: HexBase) -> void:
	if center_hex == null:
		return
	
	if _has_explored_hex and _last_explored_hex == center_hex.cube_id:
		return
	
	_has_explored_hex = true
	_last_explored_hex = center_hex.cube_id
	
	for nearby_tile in grid.get_tiles_in_radius(center_hex.cube_id, 2):
		(nearby_tile.node as HexBase).is_explored = true
		
func _open_inventory(window_info: SceneInfo) -> void:
	var window_instance := SceneManager.add(window_info, false);
	var inventory_ui: InventoryUI = (window_instance.node as DraggableControl).content as InventoryUI;
	inventory_ui.inventory = inventory;
	window_instance.on_enter.emit();

func _toggle_inventory() -> void:
	var inventory_window := DataManager.instance.get_scene_by_name("inventory_ui")
	for instance in inventory_window.get_live_instances():
		if SceneManager.is_visible(instance):
			(instance.node as DraggableControl).close_requested.emit();
			return
	inventory_window.queue(_open_inventory)

func add_trigger(other: Area3D) -> void:
	if other.has_meta("target"):
		current_triggers.append(other.get_meta("target"))
	else:
		if (other as Node3D) is Interaction:
			current_triggers.append(other)
	
func remove_trigger(other: Area3D) -> void:
	if other.has_meta("target"):
		current_triggers.erase(other.get_meta("target"))
	else:
		if (other as Node3D) is Interaction:
			current_triggers.erase(other)

func get_hex() -> HexBase:
	var grid := (SceneManager.get_active_scene().node as HexGrid);
	var current_hex := grid.get_hex_at_world_position(global_position, 0.0)
	if current_hex != null and current_hex.is_traversable():
		_remember_safe_navigation(current_hex)
		return current_hex
	
	if is_instance_valid(_last_traversable_hex):
		return _last_traversable_hex
	return null

func set_return_position() -> void:
	return_position = global_position;
	
func return_to_cached_position() -> void:
	global_position = return_position;
	Manager.instance.spring_arm_camera.snap_to_target();
