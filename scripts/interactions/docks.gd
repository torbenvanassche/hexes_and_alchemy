class_name Docks
extends Interaction

const BOAT_SCENE: PackedScene = preload("res://meshes/kay_fantasy_hexagon/decoration/props/boat.glb")
const BOAT_CHILD_NAME := "boat"

@export var y_offset: float = -0.213;
@export var boat_spawn_position: Node3D;
@export var land_spawn: Node3D;

func interact() -> void:
	var player := _get_player()
	if player == null:
		return
	
	if player.movement.movement_mode == PlayerMovement.MovementMode.WATER:
		_disembark_player(player)
		return
	
	_embark_player(player)

func can_interact() -> bool:
	var player := _get_player()
	if player != null and player.movement.movement_mode == PlayerMovement.MovementMode.WATER:
		return land_spawn != null
	return boat_spawn_position != null

func _get_player() -> PlayerController:
	if Manager.instance != null and Manager.instance.player_instance != null:
		return Manager.instance.player_instance
	return null

func _embark_player(player: PlayerController) -> void:
	if boat_spawn_position == null:
		return
	
	player.global_position = boat_spawn_position.global_position + Vector3.UP * y_offset
	player.velocity = Vector3.ZERO
	player.movement.set_movement_mode(PlayerMovement.MovementMode.WATER)
	_add_boat_to_player(player)
	
	if Manager.instance.spring_arm_camera != null:
		Manager.instance.spring_arm_camera.lerp_to_target()

func _disembark_player(player: PlayerController) -> void:
	if land_spawn == null:
		return
	
	player.global_position = land_spawn.global_position
	player.velocity = Vector3.ZERO
	player.movement.set_movement_mode(PlayerMovement.MovementMode.WALK)
	_remove_boat_from_player(player)
	
	if Manager.instance.spring_arm_camera != null:
		Manager.instance.spring_arm_camera.lerp_to_target()

func _add_boat_to_player(player: PlayerController) -> void:
	_remove_boat_from_player(player)
	
	var boat := BOAT_SCENE.instantiate() as Node3D
	if boat == null:
		return
	
	boat.name = BOAT_CHILD_NAME
	player.add_child(boat)

func _remove_boat_from_player(player: PlayerController) -> void:
	var old_boat := player.get_node_or_null(BOAT_CHILD_NAME)
	if old_boat == null:
		return
	
	player.remove_child(old_boat)
	old_boat.queue_free()
