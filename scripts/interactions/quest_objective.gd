@abstract class_name QuestObjective extends Interaction

@abstract func execute_quest(q: Quest) -> void;
var state_machine: StateMachine = StateMachine.new();

## Bitmap Columns
@export var quest_types: Array[String] = []
@export var bitmap: BitMap;
@export var quest_supply_requirements: Array[QuestSupplyRequirement] = []
@export var quest_profiles: Array[QuestProfile] = []

@export_group("Occupation")
@export_range(0.0, 1.0, 0.01) var occupation_chance := 0.0
@export var occupation_pool: Array[MonsterOccupationDefinition] = []

func _on_visibility_changed() -> void:
	super._on_visibility_changed();
	if can_interact() && is_visible_in_tree():
		Manager.instance.quests.quest_availability_changed.emit();

func has_visible_quest_activity() -> bool:
	return Manager.instance != null and Manager.instance.quests != null and Manager.instance.quests.has_quests_for_location(hex)

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
	
	var valid_types: Array[String] = []
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

func roll_quest_outcome(quest_or_type: Variant, danger_multiplier: float = 1.0) -> QuestOutcome:
	var quest: Quest = null
	if quest_or_type is Quest:
		quest = quest_or_type as Quest
	var quest_type_key := quest.quest_key if quest != null else str(quest_or_type)
	var profile := get_profile(quest_type_key)
	if profile == null:
		return null

	var resolved_danger_multiplier := maxf(0.0, danger_multiplier)
	if quest != null:
		if quest.has_method("get_danger_weight_multiplier"):
			resolved_danger_multiplier *= maxf(0.0, float(quest.call("get_danger_weight_multiplier")))
		else:
			resolved_danger_multiplier *= maxf(0.0, float(quest.context.get("danger_weight_multiplier", 1.0)))
	if has_occupation():
		resolved_danger_multiplier *= maxf(0.0, profile.occupation_danger_weight_multiplier)
		var occupation := get_occupation()
		if occupation != null:
			resolved_danger_multiplier *= maxf(0.0, occupation.danger_weight_multiplier)

	var outcome_definition := profile.roll_outcome(resolved_danger_multiplier)
	if outcome_definition == null:
		return null
	var resolved_outcome := outcome_definition.create_runtime_copy()
	if quest != null:
		quest.outcome = resolved_outcome
	return resolved_outcome

func get_quest_profile_description(quest_type_key: String) -> String:
	var profile := get_profile(quest_type_key)
	if profile == null:
		return ""
	return profile.get_description()

func get_quest_profile_risk(quest_type_key: String) -> String:
	var profile := get_profile(quest_type_key)
	if profile == null:
		return ""
	if has_occupation() and is_occupation_revealed():
		return tr("QUEST_RISK_DANGEROUS")
	return profile.get_risk_label()

func get_quest_profile_expected_reward(quest_type_key: String) -> String:
	var profile := get_profile(quest_type_key)
	if profile == null:
		return ""
	return profile.get_expected_reward_label()

func get_quest_context_label(_quest_type_key: String) -> String:
	var spot := get_spot_progress()
	if occupation_pool.is_empty() and occupation_chance <= 0.0 and (spot == null or not spot.occupation_selection_resolved):
		return ""
	if spot == null or not spot.occupation_selection_resolved or not spot.is_occupation_revealed():
		return tr("QUEST_CONTEXT_THREAT_UNKNOWN")
	var occupation := spot.occupation
	if occupation == null:
		if spot.stage == SpotProgress.Stage.SECURED:
			return tr("QUEST_CONTEXT_SITE_SECURED")
		return tr("QUEST_CONTEXT_NO_MONSTER_OCCUPATION")
	return tr("QUEST_CONTEXT_MONSTER_OCCUPATION") % [
		occupation.get_display_name(),
		AdventurerRank.get_display_name(occupation.get_difficulty()),
	]

func get_quest_profile_reward_preview(quest_type_key: String) -> Array[Dictionary]:
	var profile := get_profile(quest_type_key)
	if profile == null:
		return []
	return profile.get_reward_preview()

func get_quest_minimum_rank(quest_type_key: String) -> AdventurerRank.Rank:
	var profile := get_profile(quest_type_key)
	if profile == null:
		return AdventurerRank.Rank.F
	return profile.get_minimum_rank()

func get_quest_rank_experience_reward(quest_type_key: String, minimum_rank_override: int = -1) -> int:
	var profile := get_profile(quest_type_key)
	if profile == null:
		if minimum_rank_override < 0:
			return 1
		return int(AdventurerRank.clamp_rank(minimum_rank_override)) + 1
	return profile.get_rank_experience_reward(minimum_rank_override)

func get_spot_progress() -> SpotProgress:
	if hex == null or Manager.instance == null or Manager.instance.hub == null:
		return null
	return Manager.instance.hub.get_spot(hex)

func ensure_occupation_selected(rng: RandomNumberGenerator = null, notify_change: bool = true) -> MonsterOccupationDefinition:
	var spot := get_spot_progress()
	if spot == null:
		return null
	if spot.occupation_selection_resolved:
		return spot.occupation

	var resolved_chance := clampf(occupation_chance, 0.0, 1.0)
	var chance_roll := rng.randf() if rng != null else randf()
	if occupation_pool.is_empty() or resolved_chance <= 0.0 or chance_roll >= resolved_chance:
		spot.resolve_no_occupation()
		if notify_change:
			_notify_occupation_changed()
		return null

	var total_weight := 0.0
	for definition: MonsterOccupationDefinition in occupation_pool:
		if definition != null:
			total_weight += maxf(0.0, definition.spawn_weight)
	if total_weight <= 0.0:
		spot.resolve_no_occupation()
		if notify_change:
			_notify_occupation_changed()
		return null

	var selection_roll := (rng.randf() if rng != null else randf()) * total_weight
	var cumulative_weight := 0.0
	for definition: MonsterOccupationDefinition in occupation_pool:
		if definition == null or definition.spawn_weight <= 0.0:
			continue
		cumulative_weight += definition.spawn_weight
		if selection_roll <= cumulative_weight:
			spot.set_occupation(definition)
			if notify_change:
				_notify_occupation_changed()
			return definition

	var fallback := occupation_pool.filter(
		func(definition: MonsterOccupationDefinition) -> bool:
			return definition != null and definition.spawn_weight > 0.0
	).back() as MonsterOccupationDefinition
	spot.set_occupation(fallback)
	if notify_change:
		_notify_occupation_changed()
	return fallback

func set_occupation(definition: MonsterOccupationDefinition, revealed: bool = false) -> bool:
	var spot := get_spot_progress()
	if spot == null:
		return false
	spot.set_occupation(definition, revealed)
	_notify_occupation_changed()
	return true

func get_occupation() -> MonsterOccupationDefinition:
	var spot := get_spot_progress()
	return spot.occupation if spot != null else null

func has_occupation() -> bool:
	var spot := get_spot_progress()
	return spot != null and spot.has_occupation()

func is_occupation_revealed() -> bool:
	var spot := get_spot_progress()
	return spot != null and spot.is_occupation_revealed()

func reveal_occupation(rng: RandomNumberGenerator = null) -> MonsterOccupationDefinition:
	var spot := get_spot_progress()
	if spot == null:
		return null
	if not spot.occupation_selection_resolved:
		ensure_occupation_selected(rng, false)
	var revealed := spot.reveal_occupation()
	_notify_occupation_changed()
	return revealed

func clear_occupation(mark_secured: bool = true) -> MonsterOccupationDefinition:
	var spot := get_spot_progress()
	if spot == null:
		return null
	var cleared := spot.clear_occupation(mark_secured)
	_notify_occupation_changed()
	return cleared

func get_occupation_context_label() -> String:
	if not is_occupation_revealed():
		return ""
	var occupation := get_occupation()
	return occupation.get_display_name() if occupation != null else ""

func get_occupation_difficulty(include_hidden: bool = false) -> AdventurerRank.Rank:
	if not include_hidden and not is_occupation_revealed():
		return AdventurerRank.Rank.F
	var occupation := get_occupation()
	return occupation.get_difficulty() if occupation != null else AdventurerRank.Rank.F

func grant_player_inventory_rewards(rewards: Dictionary[ItemInfo, int]) -> void:
	if rewards.is_empty() or Manager.instance == null:
		return

	if Manager.instance.hub != null:
		Manager.instance.hub.deposit_items(rewards)
		for item: ItemInfo in rewards.keys():
			if item != null and int(rewards[item]) > 0:
				_notify_item_reward(item, int(rewards[item]))
		return

	if Manager.instance.player_instance == null:
		return
	var inventory := Manager.instance.player_instance.inventory
	if inventory == null:
		return

	for item: ItemInfo in rewards.keys():
		if item == null:
			continue
		var amount := maxi(0, rewards[item])
		if amount <= 0:
			continue

		var remaining := inventory.add(item, amount)
		var added := amount - remaining
		if added > 0:
			_notify_item_reward(item, added)
		if remaining > 0:
			_notify_reward(tr("QUEST_REWARD_INVENTORY_FULL") % [remaining, item.get_display_name()], Color.RED)

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
	var active_occupation := has_occupation()
	var revealed_occupation := is_occupation_revealed()
	for quest_type in types:
		var profile := get_profile(quest_type)
		if profile == null or (
			profile.is_available_for_state(active_state_name)
			and profile.is_available_for_occupation(active_occupation, revealed_occupation)
		):
			filtered.append(quest_type)
	return filtered

func _notify_occupation_changed() -> void:
	if Manager.instance == null:
		return
	if Manager.instance.hub != null:
		Manager.instance.hub.changed.emit()
	if Manager.instance.quests != null:
		Manager.instance.quests.quest_availability_changed.emit()

func _notify_reward(message: String, color: Color = Color.WHITE) -> void:
	if Manager.instance != null and Manager.instance.toast != null:
		Manager.instance.toast.notify(message, color)

func _notify_item_reward(item: ItemInfo, amount: int, color: Color = Color.WHITE) -> void:
	if Manager.instance != null and Manager.instance.toast != null:
		Manager.instance.toast.notify_item_reward(item, amount, color)
	
func _on_create_quest_window_loaded(window_info: SceneInfo) -> void:
	window_instance = SceneManager.add(window_info, false);
	var quest_creation: QuestCreationUI = (window_instance.node as DraggableControl).content as QuestCreationUI;
	if not quest_creation.quest_created.is_connected(Manager.instance.quests.add_quest):
		quest_creation.quest_created.connect(Manager.instance.quests.add_quest)
	quest_creation.force_data(self)
	window_instance.on_enter.emit();
