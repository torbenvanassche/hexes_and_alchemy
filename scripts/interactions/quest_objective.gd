@abstract class_name QuestObjective extends Interaction

@abstract func execute_quest(q: Quest) -> void;
var state_machine: StateMachine = StateMachine.new();

## Bitmap Columns
@export var quest_types: Array[String];
@export var bitmap: BitMap;
@export var quest_supply_requirements: Array[QuestSupplyRequirement] = []

func _on_visibility_changed() -> void:
	super._on_visibility_changed();
	if can_interact() && is_visible_in_tree():
		Config.gamestate.quest_availability_changed.emit();

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
	for b in bitmap.get_size().x:
		if bitmap.get_bit(b, active_state):
			valid_types.append(quest_types[b]);
	return valid_types;

func get_supply_requirement(quest_type_key: String) -> QuestSupplyRequirement:
	for requirement in quest_supply_requirements:
		if requirement != null and requirement.matches(quest_type_key):
			return requirement
	return null

func get_required_supplies(quest_type_key: String) -> Dictionary[ItemInfo, int]:
	var requirement := get_supply_requirement(quest_type_key)
	if requirement != null:
		return requirement.supplies
	return {}

func has_required_supplies(quest_type_key: String, inventory: ContentGroup) -> bool:
	var requirement := get_supply_requirement(quest_type_key)
	return requirement == null or requirement.has_available_supplies(inventory)

func assign_required_supplies(quest: Quest, inventory: ContentGroup) -> bool:
	if quest == null:
		return false

	var requirement := get_supply_requirement(quest.quest_key)
	return requirement == null or requirement.assign_to_quest(quest, inventory)

func quest_has_required_supplies(quest: Quest) -> bool:
	if quest == null:
		return false
	var requirement := get_supply_requirement(quest.quest_key)
	return requirement == null or requirement.quest_has_supplies(quest)
	
func _on_create_quest_window_loaded(window_info: SceneInfo) -> void:
	window_instance = SceneManager.add(window_info);
	var quest_creation: QuestCreationUI = (window_instance.node as DraggableControl).content as QuestCreationUI;
	if not quest_creation.quest_created.is_connected(Config.gamestate.add_quest):
		quest_creation.quest_created.connect(Config.gamestate.add_quest)
	quest_creation.force_data(self)
	window_instance.on_enter.emit();
