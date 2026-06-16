class_name QuestBoard extends Interaction

func on_interact() -> void:
	if _has_available_quest_locations():
		super()
		return

	_notify_no_available_quests()

func interact() -> void:
	if not _has_available_quest_locations():
		_notify_no_available_quests()
		return

	DataManager.instance.get_scene_by_name("quest_list_ui").queue(_open_window)
	
func can_interact() -> bool:
	var settlement: Settlement = Manager.instance.get_settlement(self);
	
	var ui_is_closed := not window_instance || not SceneManager.is_visible(window_instance);
	var active_settlement_board: bool = settlement && settlement.interactions.any(func(interaction: Interaction) -> bool: return interaction is Tavern);
	return ui_is_closed && active_settlement_board && _has_available_quest_locations();
	
func _open_window(window_info: SceneInfo) -> void:
	window_instance = SceneManager.add(window_info, false);
	window_instance.on_enter.emit();

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
	var tiles_in_radius: Array[SceneInstance] = grid.get_tiles_in_radius(hex.cube_id, Config.gamestate.max_quest_distance)
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
		if quest_objective.get_filtered_quest_types().is_empty():
			continue
		if not quest_objective.can_interact():
			continue

		available_locations.append(quest_hex)

	return available_locations

func _ensure_hex(grid: HexGrid) -> void:
	if hex != null:
		return

	var cube_id = grid.world_to_cube_id(global_position)
	if grid.tiles.has(cube_id):
		hex = grid.tiles[cube_id].node

func _notify_no_available_quests() -> void:
	if Manager.instance && Manager.instance.toast:
		Manager.instance.toast.notify("Quest board debug: no visible, interactable quest locations are available.")

func _on_area_exit(other: Area3D) -> void:
	super(other);
