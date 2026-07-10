class_name QuestBoard extends SettlementService

func on_interact() -> void:
	super()

func interact() -> void:
	DataManager.instance.get_scene_by_name("quest_list_ui").queue(_open_window)
	
func can_interact() -> bool:
	var owner_settlement: Settlement = get_settlement()
	
	var ui_is_closed: bool = window_instance == null or not SceneManager.is_visible(window_instance);
	var active_settlement_board: bool = owner_settlement != null and owner_settlement.has_service(&"Tavern");
	return ui_is_closed && active_settlement_board;
	
func _open_window(window_info: SceneInfo) -> void:
	window_instance = open_ui_window(window_info);
	open_additional_ui_windows()

func _has_available_quest_locations() -> bool:
	return not _get_available_quest_locations().is_empty()

func _get_available_quest_locations() -> Array[HexBase]:
	var grid := SceneManager.get_active_scene().node as HexGrid
	if grid == null:
		return []

	_ensure_hex(grid)
	if hex == null:
		return []

	var available_locations: Array[HexBase] = []
	var tiles_in_radius: Array[SceneInstance] = grid.get_tiles_in_radius(hex.cube_id, Manager.instance.quests.max_quest_distance)
	for tile: SceneInstance in tiles_in_radius:
		var quest_hex := tile.node as HexBase
		if quest_hex == null or quest_hex.structure == null:
			continue
		if not quest_hex.is_explored or not quest_hex.is_visible_in_tree():
			continue
		if not quest_hex.structure.structure_info.is_quest_target:
			continue

		var quest_objective := quest_hex.structure.instance as QuestObjective
		if quest_objective == null:
			continue
		if not quest_objective.is_visible_in_tree():
			continue
		var available_types := Manager.instance.quests.get_available_quest_types(
			quest_hex,
			quest_objective.get_filtered_quest_types()
		)
		if available_types.is_empty():
			continue
		if not quest_objective.can_interact():
			continue
		if not Manager.instance.quests.is_quest_location_reachable(quest_hex, grid):
			continue

		available_locations.append(quest_hex)

	return available_locations

func _ensure_hex(grid: HexGrid) -> void:
	if hex != null:
		return

	var cube_id = grid.world_to_cube_id(global_position)
	if grid.tiles.has(cube_id):
		hex = grid.tiles[cube_id].node
