class_name PlayerInteractor
extends Node

@export var interactor_path: NodePath = ^"../interactor"

var current_triggers: Array[Interaction] = []
var interactor: Area3D
var selected_hex: HexBase

signal hex_picked(hex: HexBase)

func _ready() -> void:
	interactor = get_node_or_null(interactor_path) as Area3D
	if interactor == null:
		return
	
	interactor.area_entered.connect(add_trigger)
	interactor.area_exited.connect(remove_trigger)

func has_trigger() -> bool:
	return current_triggers.size() != 0

func interact() -> bool:
	if not has_trigger():
		return false
	
	current_triggers[0].on_interact()
	return true

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
	
	selected_hex = picked_hex
	hex_picked.emit(picked_hex)
	
	if grid is MainGrid and (grid as MainGrid).target_position != null:
		(grid as MainGrid).target_position.global_position = picked_hex.global_position
	
	return picked_hex

func add_trigger(other: Area3D) -> void:
	if other.has_meta("target"):
		var target := other.get_meta("target") as Interaction
		if target != null:
			current_triggers.append(target)
	elif (other as Node3D) is Interaction:
		current_triggers.append(other)

func remove_trigger(other: Area3D) -> void:
	if other.has_meta("target"):
		current_triggers.erase(other.get_meta("target") as Interaction)
	elif (other as Node3D) is Interaction:
		current_triggers.erase(other)
