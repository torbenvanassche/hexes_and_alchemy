class_name Market extends Interaction

var window_instance: SceneInstance;

func interact() -> void:
	DataManager.instance.get_scene_by_name("market_ui").queue(_open_window)
	
func can_interact() -> bool:
	return not window_instance || not SceneManager.is_visible(window_instance)
	
func _open_window(window_info: SceneInfo) -> void:
	window_instance = SceneManager.add(window_info, false);
	await get_tree().process_frame;
	(window_instance.node as DraggableControl).visible = true;
