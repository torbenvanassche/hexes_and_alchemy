class_name QuestBoard extends Interaction

func interact() -> void:
	DataManager.instance.get_scene_by_name("quest_list_ui").queue(_open_window)
	
func can_interact() -> bool:
	var settlement: Settlement = Manager.instance.get_settlement(self);
	
	var ui_is_open := not window_instance || not SceneManager.is_visible(window_instance);
	var active_settlement_board: bool = settlement && settlement.interactions.any(func(interaction: Interaction) -> bool: return interaction is Tavern);
	return ui_is_open && active_settlement_board;
	
func _open_window(window_info: SceneInfo) -> void:
	window_instance = SceneManager.add(window_info, false);
	window_instance.on_enter.emit();

func _on_area_exit(other: Area3D) -> void:
	super(other);
