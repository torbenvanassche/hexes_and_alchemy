@abstract class_name QuestObjective extends Interaction

@abstract func execute_quest(q: Quest) -> void;

func on_interact() -> void:
	super.on_interact();
	if can_interact():
		DataManager.instance.get_scene_by_name("quest_creation_ui").queue(_on_create_quest_window_loaded);
	
