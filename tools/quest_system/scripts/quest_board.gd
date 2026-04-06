class_name QuestBoard extends Interaction

var window_instance: SceneInstance;

func interact() -> void:
	DataManager.instance.get_scene_by_name("quest_list_ui").queue(_open_window)
	
func can_interact() -> bool:
	return not window_instance || not SceneManager.is_visible(window_instance)
	
func _open_window(window_info: SceneInfo) -> void:
	window_instance = SceneManager.add(window_info, false);
	var quest_list_ui: QuestListUI = (window_instance.node as DraggableControl).content as QuestListUI;
	window_instance.on_enter.emit();

func _on_area_exit(other: Area3D) -> void:
	if window_instance:
		window_instance.hide();
	super(other);
