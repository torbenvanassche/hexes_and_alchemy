class_name QuestBoard extends Interaction

func interact() -> void:
	DataManager.instance.get_scene_by_name("quest_list_ui").queue(_open_window)
	
func can_interact() -> bool:
	var settlement: Settlement = Manager.instance.get_settlement(self);
	
	var ui_is_closed := not window_instance || not SceneManager.is_visible(window_instance);
	var active_settlement_board: bool = settlement && settlement.interactions.any(func(interaction: Interaction) -> bool: return interaction is Tavern);
	
	var grid: HexGrid = (SceneManager.get_active_scene().node as HexGrid);
	if not hex:
		var cube_id = grid.world_to_cube_id(global_position)
		hex = grid.tiles[cube_id].node;
	
	var tiles_in_radius: Array[SceneInstance] = grid.get_tiles_in_radius(hex.cube_id, Config.gamestate.max_quest_distance);
	var possible_quests := tiles_in_radius.filter(func(x: SceneInstance) -> bool: return (x.node as HexBase).structure && (x.node as HexBase).structure.instance is QuestObjective);
	var quest_locations_in_range: bool = possible_quests.any(func(i: SceneInstance) -> bool: return i.node.structure.instance.can_interact());
	return ui_is_closed && active_settlement_board && quest_locations_in_range;
	
func _open_window(window_info: SceneInfo) -> void:
	window_instance = SceneManager.add(window_info, false);
	window_instance.on_enter.emit();

func _on_area_exit(other: Area3D) -> void:
	super(other);
