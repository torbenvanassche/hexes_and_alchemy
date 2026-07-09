@abstract class_name QuestObjective extends Interaction

@abstract func execute_quest(q: Quest) -> void;
var state_machine: StateMachine = StateMachine.new();

## Bitmap Columns
@export var quest_types: Array[String];
@export var bitmap: BitMap;
@export var quest_supply_requirements: Array[QuestSupplyRequirement] = []
@export var quest_profiles: Array[QuestProfile] = []

func _on_visibility_changed() -> void:
	super._on_visibility_changed();
	if can_interact() && is_visible_in_tree():
		Manager.instance.quests.quest_availability_changed.emit();

func on_interact() -> void:
	super.on_interact();
	if can_interact():
		DataManager.instance.get_scene_by_name("quest_creation_ui").queue(_on_create_quest_window_loaded);
		
func get_filtered_quest_types(active_state: int = state_machine.get_current_state_index()) -> Array[String]:
	var available_types := _get_configured_quest_types()
	var active_state_name := state_machine.get_current_state()
	if not quest_profiles.is_empty():
		return _filter_profile_states(available_types, active_state_name)
	if not bitmap or bitmap.get_size() == Vector2i.ZERO:
		return _filter_profile_states(available_types, active_state_name);
	
	var valid_types: Array[String];
	var bitmap_types := available_types
	for b in bitmap.get_size().x:
		if b >= bitmap_types.size():
			continue
		if bitmap.get_bit(b, active_state):
			valid_types.append(bitmap_types[b]);
	return _filter_profile_states(valid_types, active_state_name);

func get_profile(quest_type_key: String) -> QuestProfile:
	for profile in quest_profiles:
		if profile != null and profile.matches(quest_type_key):
			return profile
	return null

func get_supply_requirement(quest_type_key: String) -> QuestSupplyRequirement:
	for requirement in quest_supply_requirements:
		if requirement != null and requirement.matches(quest_type_key):
			return requirement
	return null

func get_required_supplies(quest_type_key: String) -> Dictionary[ItemInfo, int]:
	var profile := get_profile(quest_type_key)
	if profile != null:
		return profile.get_required_supplies()
	var requirement := get_supply_requirement(quest_type_key)
	if requirement != null:
		return requirement.supplies
	return {}

func has_required_supplies(quest_type_key: String, inventory: ContentGroup) -> bool:
	var profile := get_profile(quest_type_key)
	if profile != null:
		return profile.has_available_supplies(inventory)
	var requirement := get_supply_requirement(quest_type_key)
	return requirement == null or requirement.has_available_supplies(inventory)

func assign_required_supplies(quest: Quest, inventory: ContentGroup) -> bool:
	if quest == null:
		return false

	var profile := get_profile(quest.quest_key)
	if profile != null:
		return profile.assign_required_supplies(quest, inventory)
	var requirement := get_supply_requirement(quest.quest_key)
	return requirement == null or requirement.assign_to_quest(quest, inventory)

func quest_has_required_supplies(quest: Quest) -> bool:
	if quest == null:
		return false
	var profile := get_profile(quest.quest_key)
	if profile != null:
		return profile.quest_has_supplies(quest)
	var requirement := get_supply_requirement(quest.quest_key)
	return requirement == null or requirement.quest_has_supplies(quest)

func get_quest_duration(quest_type_key: String, fallback: float) -> float:
	var profile := get_profile(quest_type_key)
	if profile == null:
		return fallback
	return maxf(0.0, profile.duration_seconds)

func get_quest_behaviour(quest_type_key: String, fallback: String = "") -> String:
	var profile := get_profile(quest_type_key)
	if profile == null:
		return fallback if fallback != "" else quest_type_key
	return profile.get_behaviour()

func roll_quest_outcome(quest_type_key: String) -> QuestOutcome:
	var profile := get_profile(quest_type_key)
	if profile == null:
		return null
	return profile.roll_outcome()

func get_quest_profile_description(quest_type_key: String) -> String:
	var profile := get_profile(quest_type_key)
	if profile == null:
		return ""
	return profile.get_description()

func get_quest_profile_risk(quest_type_key: String) -> String:
	var profile := get_profile(quest_type_key)
	if profile == null:
		return ""
	return profile.get_risk_label()

func get_quest_profile_expected_reward(quest_type_key: String) -> String:
	var profile := get_profile(quest_type_key)
	if profile == null:
		return ""
	return profile.get_expected_reward_label()

func get_quest_profile_reward_preview(quest_type_key: String) -> Array[Dictionary]:
	var profile := get_profile(quest_type_key)
	if profile == null:
		return []
	return profile.get_reward_preview()

func _get_configured_quest_types() -> Array[String]:
	if quest_profiles.is_empty():
		return quest_types

	var configured_types: Array[String] = []
	for profile in quest_profiles:
		if profile != null and profile.quest_key != "":
			configured_types.append(profile.quest_key)
	return configured_types

func _filter_profile_states(types: Array[String], active_state_name: String) -> Array[String]:
	if quest_profiles.is_empty():
		return types

	var filtered: Array[String] = []
	for quest_type in types:
		var profile := get_profile(quest_type)
		if profile == null or profile.is_available_for_state(active_state_name):
			filtered.append(quest_type)
	return filtered
	
func _on_create_quest_window_loaded(window_info: SceneInfo) -> void:
	window_instance = SceneManager.add(window_info, false);
	var quest_creation: QuestCreationUI = (window_instance.node as DraggableControl).content as QuestCreationUI;
	if not quest_creation.quest_created.is_connected(Manager.instance.quests.add_quest):
		quest_creation.quest_created.connect(Manager.instance.quests.add_quest)
	quest_creation.force_data(self)
	window_instance.on_enter.emit();
