extends Interaction

func interact() -> void:
	DataManager.instance.get_scene_by_name("gameplay_main").queue(_on_transition)
	Manager.instance.player_instance.return_to_cached_position();
	
func _on_transition(s: SceneInfo) -> void:
	SceneManager.transition(s)
