@abstract class_name QuestObjective extends Interaction

@abstract func execute_quest(q: Quest) -> void;
@export var quest_types: Dictionary[String, bool];

func on_interact() -> void:
	super.on_interact();
	if can_interact():
		DataManager.instance.get_scene_by_name("quest_creation_ui").queue(_on_create_quest_window_loaded);
		
func get_filtered_quest_types() -> Array[String]:
	var valid_types: Array[String];
	for q in quest_types.keys():
		if quest_types[q]:
			valid_types.append(q);
	return valid_types;
	
func _on_create_quest_window_loaded(window_info: SceneInfo) -> void:
	window_instance = SceneManager.add(window_info);
	var quest_creation: QuestCreationUI = (window_instance.node as DraggableControl).content as QuestCreationUI;
	if not quest_creation.quest_created.is_connected(Config.gamestate.add_quest):
		quest_creation.quest_created.connect(Config.gamestate.add_quest)
		quest_creation.force_data(self)
	window_instance.on_enter.emit();
