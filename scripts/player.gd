class_name PlayerController
extends CharacterBody3D

@export var move_speed := 6.0
@export var acceleration := 10.0
@export var dash_modifier := 1.5;

@onready var interactor: Area3D = $interactor;
@onready var inventory: Inventory = $Inventory;

var current_triggers: Array[Interaction] = [];
var return_position: Vector3;

func _ready() -> void:
	interactor.area_entered.connect(add_trigger)
	interactor.area_exited.connect(remove_trigger)

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("primary_action") && current_triggers.size() != 0:
		current_triggers[0].on_interact();
	
	if Manager.instance.input_moves_player():
		_handle_movement(delta)
		move_and_slide()

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

	if move_dir.length() > 0.01:
		var probe_pos := global_position + move_dir.normalized() * HexGrid.RADIUS_IN * 0.5
		var grid := SceneManager.get_active_scene().node;
		var hex: HexBase = null;
		if grid is HexGrid:
			hex = grid.get_hex_at_world_position(probe_pos)
		else:
			Debug.message("Active scene is not a hexgrid, cannot walk")
			return;
			
		if hex == null or not hex.is_walkable(self):
			velocity = Vector3.ZERO
			return;

	velocity.x = lerp(velocity.x, target_velocity.x, delta * acceleration)
	velocity.z = lerp(velocity.z, target_velocity.z, delta * acceleration)

	if move_dir.length() > 0.1:
		var target_rot := atan2(move_dir.x, move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 10.0)

func add_trigger(other: Area3D) -> void:
	if other.has_meta("target"):
		current_triggers.append(other.get_meta("target"))
	else:
		if (other as Node3D) is Interaction:
			current_triggers.append(other)
		else:
			Debug.err("No interaction defined on %s" % [other])
	
func remove_trigger(other: Area3D) -> void:
	if other.has_meta("target"):
		current_triggers.erase(other.get_meta("target"))
	else:
		if (other as Node3D) is Interaction:
			current_triggers.erase(other)
		else:
			Debug.err("No interaction defined on %s" % [other])

func get_hex() -> HexBase:
	var grid := (SceneManager.get_active_scene().node as HexGrid);
	return grid.get_hex_at_world_position(global_position)

func set_return_position() -> void:
	return_position = global_position;
	
func return_to_cached_position() -> void:
	global_position = return_position;
	Manager.instance.spring_arm_camera.snap_to_target();
