class_name QuestTargetSelector extends RefCounted

signal target_resolved(location: HexBase)
signal target_unavailable(reason_key: String)

var quest_manager: QuestManager
var player: PlayerController

func _init(manager: QuestManager = null, player_controller: PlayerController = null) -> void:
	quest_manager = manager
	player = player_controller

func get_grid() -> HexGrid:
	var active_scene := SceneManager.get_active_scene()
	return active_scene.node as HexGrid if active_scene != null else null

func get_available_quest_locations() -> Array[HexBase]:
	var grid := get_grid()
	var player_hex := _get_player_hex()
	var locations: Array[HexBase] = []
	if grid == null or player_hex == null or quest_manager == null:
		return locations

	for hex: HexBase in grid.get_structured_hexes():
		if not is_available_quest_location(hex):
			continue
		if GridUtils.cube_distance(hex.cube_id, player_hex.cube_id) > quest_manager.max_quest_distance:
			continue
		if not quest_manager.is_quest_location_reachable(hex, grid):
			continue
		if get_postable_types(hex).is_empty():
			continue
		locations.append(hex)

	locations.sort_custom(func(a: HexBase, b: HexBase) -> bool:
		var distance_a := get_distance(a)
		var distance_b := get_distance(b)
		if distance_a == distance_b:
			return _get_sort_label(a).nocasecmp_to(_get_sort_label(b)) < 0
		return distance_a < distance_b
	)
	return locations

func is_available_quest_location(location: HexBase) -> bool:
	if location == null or location.structure == null:
		return false
	if not location.is_explored or not location.is_visible_in_tree():
		return false
	if location.structure.structure_info == null or not location.structure.structure_info.is_quest_target:
		return false
	var objective := location.structure.instance as QuestObjective
	return objective != null and objective.is_visible_in_tree() and objective.can_interact()

func can_offer_location(
	location: HexBase,
	require_reachable: bool = true,
	allow_active_location: bool = false
) -> bool:
	if not is_available_quest_location(location) or quest_manager == null:
		return false
	var grid := get_grid()
	if grid == null or _get_player_hex() == null:
		return false
	if require_reachable and not quest_manager.is_quest_location_reachable(location, grid):
		return false
	return (
		not get_postable_types(location).is_empty()
		or (allow_active_location and quest_manager.has_quests_for_location(location))
	)

func get_postable_types(location: HexBase) -> Array[String]:
	if quest_manager == null or location == null or location.structure == null:
		return []
	var objective := location.structure.instance as QuestObjective
	if objective == null:
		return []
	return quest_manager.get_postable_quest_types(
		location,
		objective.get_filtered_quest_types(objective.state_machine.get_current_state_index())
	)

func resolve_scout_target(direction_index: int, requested_distance: int) -> HexBase:
	var grid := get_grid()
	if grid == null or quest_manager == null:
		target_unavailable.emit("QUEST_CREATION_NO_SCOUTING_AVAILABLE")
		return null
	var location := quest_manager.get_scout_location_for_direction_and_distance(
		grid,
		direction_index,
		requested_distance
	)
	if location == null:
		target_unavailable.emit("QUEST_CREATION_NO_SCOUTING_AVAILABLE")
		return null
	target_resolved.emit(location)
	return location

func can_post_scout(location: HexBase) -> bool:
	var grid := get_grid()
	return (
		quest_manager != null
		and grid != null
		and location != null
		and quest_manager.is_valid_scout_location(location, grid)
		and quest_manager.is_quest_location_reachable(location, grid)
	)

func is_scout_location(location: HexBase) -> bool:
	return location != null and location.structure == null and not location.is_explored

func get_distance(location: HexBase) -> int:
	var player_hex := _get_player_hex()
	if player_hex == null or location == null:
		return 0
	return GridUtils.cube_distance(location.cube_id, player_hex.cube_id)

func get_scout_distance(location: HexBase) -> int:
	var grid := get_grid()
	if quest_manager == null or grid == null or location == null:
		return 0
	var origin := quest_manager.get_active_quest_origin_hex(grid)
	return GridUtils.cube_distance(origin.cube_id, location.cube_id) if origin != null else 0

func _get_player_hex() -> HexBase:
	return player.get_hex() if player != null else null

func _get_sort_label(location: HexBase) -> String:
	if location == null or location.structure == null or location.structure.structure_info == null:
		return ""
	return location.structure.structure_info.get_display_name()
