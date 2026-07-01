class_name PlayerInteractor
extends Area3D

var current_triggers: Array[Interaction] = []
var selected_hex: HexBase

signal hex_picked(hex: HexBase)

func _ready() -> void:
	area_entered.connect(add_trigger)
	area_exited.connect(remove_trigger)

func has_trigger() -> bool:
	return current_triggers.size() != 0

func _refresh_interaction_prompt() -> void:
	var prompt_target := _get_closest_trigger(true)
	Manager.instance.interaction_prompt.show_rect(prompt_target)

func interact() -> bool:
	if not has_trigger():
		return false
	
	var closest_trigger := _get_closest_trigger(false)
	if closest_trigger == null:
		return false

	closest_trigger.on_interact()
	_refresh_interaction_prompt()
	return true

func _get_closest_trigger(prompt_only: bool) -> Interaction:
	var closest_trigger: Interaction = null
	var closest_distance := INF
	var origin := _get_interaction_origin()

	for trigger: Interaction in current_triggers:
		if not is_instance_valid(trigger):
			continue
		if prompt_only and (not trigger.show_interaction_prompt or not trigger.can_interact()):
			continue

		var target_position := trigger.global_position
		if is_instance_valid(trigger.hex):
			target_position = trigger.hex.global_position

		var distance := origin.distance_squared_to(target_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_trigger = trigger

	return closest_trigger

func _get_interaction_origin() -> Vector3:
	var parent := get_parent() as Node3D
	if parent != null:
		return parent.global_position

	return Vector3.ZERO

func pick_hex_from_mouse() -> HexBase:
	return _get_hex_from_mouse(true)

func peek_hex_from_mouse() -> HexBase:
	return _get_hex_from_mouse(false)

func _get_hex_from_mouse(update_selection: bool) -> HexBase:
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
		if update_selection:
			selected_hex = null
		return null
	
	var picked_hex := grid.get_hex_at_world_position(hit_position, 0.0)
	if picked_hex == null:
		if update_selection:
			selected_hex = null
		return null

	if update_selection:
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
	_refresh_interaction_prompt()

func remove_trigger(other: Area3D) -> void:
	if other.has_meta("target"):
		current_triggers.erase(other.get_meta("target") as Interaction)
	elif (other as Node3D) is Interaction:
		current_triggers.erase(other)
	_refresh_interaction_prompt()
