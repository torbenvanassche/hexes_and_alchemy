@abstract class_name QuestObjective extends Interaction

@abstract func execute_quest(q: Quest) -> void;
var state_machine: StateMachine = StateMachine.new();

## Bitmap Columns
@export var quest_types: Array[String];
@export var bitmap: BitMap;

func on_interact() -> void:
	super.on_interact();
	if can_interact():
		DataManager.instance.get_scene_by_name("quest_creation_ui").queue(_on_create_quest_window_loaded);
		
func get_filtered_quest_types(active_state: int = state_machine.get_current_state_index()) -> Array[String]:
	if not bitmap:
		return quest_types;
	if bitmap.get_size() == Vector2i.ZERO:
		return quest_types;
	
	var valid_types: Array[String];
	for b in bitmap.get_size().y:
		if bitmap.get_bit(active_state, b):
			valid_types.append(quest_types[b]);
	return valid_types;
	
func _on_create_quest_window_loaded(window_info: SceneInfo) -> void:
	window_instance = SceneManager.add(window_info);
	var quest_creation: QuestCreationUI = (window_instance.node as DraggableControl).content as QuestCreationUI;
	if not quest_creation.quest_created.is_connected(Config.gamestate.add_quest):
		quest_creation.quest_created.connect(Config.gamestate.add_quest)
		quest_creation.force_data(self)
	window_instance.on_enter.emit();
