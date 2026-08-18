class_name QuestProfile extends Resource

@export var quest_key: String = ""
@export var behaviour: String = ""
@export var required_role: String = ""
@export var translation_key_name: String = ""
@export_multiline var description_key: String = ""
@export var risk_key: String = "QUEST_RISK_SAFE"
@export var expected_reward_key: String = ""
@export var duration_seconds: float = 5.0
@export var minimum_rank: AdventurerRank.Rank = AdventurerRank.Rank.F
@export_range(0, 100, 1) var rank_experience_reward: int = 1
@export var available_states: Array[String] = []
@export var required_supplies: Dictionary[ItemInfo, int] = {}
@export var required_supply_effect_keys: Dictionary[ItemInfo, String] = {}
## Additional supplies for each mine depth beyond the first. Used by mine-deepening quests.
@export var required_supplies_per_level: Dictionary[ItemInfo, int] = {}
@export var optional_supports: Array[QuestSupportDefinition] = []
@export var outcomes: Array[QuestOutcome] = []
@export var modifiers: Dictionary = {}

@export_group("World Progress")
@export var completion_spot_stage: SpotProgress.Stage = SpotProgress.Stage.UNKNOWN
@export var occupied_completion_spot_stage: SpotProgress.Stage = SpotProgress.Stage.UNKNOWN
@export var occupation_must_be_revealed := true
@export var objective_state_spot_stage_overrides: Dictionary[String, int] = {}

@export_group("Occupation")
@export var requires_revealed_occupation := false
@export var blocked_by_active_occupation := false
@export_range(0.0, 10.0, 0.05, "or_greater") var occupation_danger_weight_multiplier := 1.0

@export_group("Guild Impact")
@export_range(-10, 10, 1) var guild_reputation_reward: int = 1
@export_range(-10, 10, 1) var notoriety_reward: int = 0
@export_range(-10, 10, 1) var stewardship_change: int = 0
@export_range(-10, 10, 1) var regional_hazard_change: int = 0

func matches(quest_type_key: String) -> bool:
	return quest_key == quest_type_key

func get_behaviour() -> String:
	if behaviour != "":
		return behaviour
	return quest_key

func get_required_role() -> String:
	return required_role

func is_available_for_state(state_name: String) -> bool:
	return available_states.is_empty() or available_states.has(state_name)

func is_available_for_occupation(has_active_occupation: bool, occupation_is_revealed: bool) -> bool:
	if requires_revealed_occupation and not (has_active_occupation and occupation_is_revealed):
		return false
	if blocked_by_active_occupation and has_active_occupation and occupation_is_revealed:
		return false
	return true

func get_display_name() -> String:
	if translation_key_name == "":
		return quest_key.capitalize()
	var translated := tr(translation_key_name)
	if translated == translation_key_name:
		return quest_key.capitalize()
	return translated

func get_description() -> String:
	if description_key == "":
		return ""
	var translated := tr(description_key)
	if translated == description_key:
		return ""
	return translated

func get_risk_label() -> String:
	if risk_key == "":
		return ""
	var translated := tr(risk_key)
	if translated == risk_key:
		return risk_key.capitalize()
	return translated

func get_expected_reward_label() -> String:
	if expected_reward_key == "":
		return ""
	var translated := tr(expected_reward_key)
	if translated == expected_reward_key:
		return ""
	return translated

func get_reward_preview() -> Array[Dictionary]:
	if outcomes.is_empty():
		return []

	var item_ranges: Dictionary[ItemInfo, Vector2i] = {}
	var item_seen_counts: Dictionary[ItemInfo, int] = {}
	var valid_outcome_count := 0

	for outcome in outcomes:
		if outcome == null:
			continue

		valid_outcome_count += 1
		var ranges := outcome.get_preview_ranges()
		if ranges.is_empty():
			continue

		for item: ItemInfo in ranges.keys():
			if item == null:
				continue

			var amount_range: Vector2i = ranges[item]
			var current: Vector2i = item_ranges.get(item, Vector2i(-1, 0))
			var min_amount := amount_range.x if current.x == -1 else mini(current.x, amount_range.x)
			item_ranges[item] = Vector2i(min_amount, maxi(current.y, amount_range.y))
			item_seen_counts[item] = int(item_seen_counts.get(item, 0)) + 1

	if valid_outcome_count == 0:
		return []

	var preview: Array[Dictionary] = []
	for item: ItemInfo in item_ranges.keys():
		if item == null:
			continue

		var amount_range: Vector2i = item_ranges[item]
		if int(item_seen_counts.get(item, 0)) < valid_outcome_count:
			amount_range.x = 0

		preview.append({
			"item": item,
			"min": amount_range.x,
			"max": amount_range.y,
		})

	preview.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var item_a := a.get("item") as ItemInfo
		var item_b := b.get("item") as ItemInfo
		if item_a == null or item_b == null:
			return item_a != null
		return item_a.get_display_name().nocasecmp_to(item_b.get_display_name()) < 0
	)
	return preview

func get_minimum_rank() -> AdventurerRank.Rank:
	return AdventurerRank.clamp_rank(minimum_rank)

func get_rank_experience_reward(minimum_rank_override: int = -1) -> int:
	var reward := maxi(0, rank_experience_reward)
	if minimum_rank_override < 0:
		return reward
	return maxi(reward, int(AdventurerRank.clamp_rank(minimum_rank_override)) + 1)

func get_required_supplies() -> Dictionary[ItemInfo, int]:
	return required_supplies

func get_required_supply_effect(item: ItemInfo) -> String:
	if item == null or not required_supply_effect_keys.has(item):
		return ""
	var effect_key := str(required_supply_effect_keys[item])
	if effect_key == "":
		return ""
	var translated := tr(effect_key)
	return "" if translated == effect_key else translated

func get_optional_supports() -> Array[QuestSupportDefinition]:
	var supports: Array[QuestSupportDefinition] = []
	for support in optional_supports:
		if support != null and support.id != &"":
			supports.append(support)
	return supports

func get_required_supplies_for_level(level: int) -> Dictionary[ItemInfo, int]:
	var result: Dictionary[ItemInfo, int] = {}
	for item: ItemInfo in required_supplies.keys():
		result[item] = int(required_supplies[item])
	var extra_levels := maxi(0, level - 1)
	for item: ItemInfo in required_supplies_per_level.keys():
		result[item] = int(result.get(item, 0)) + int(required_supplies_per_level[item]) * extra_levels
	return result

func has_available_supplies_for_level(inventory: ContentGroup, level: int) -> bool:
	return inventory != null and inventory.has_all(get_required_supplies_for_level(level))

func assign_required_supplies_for_level(quest: Quest, inventory: ContentGroup, level: int) -> bool:
	var requirements := get_required_supplies_for_level(level)
	if quest == null or inventory == null or not inventory.has_all(requirements):
		return false
	for item: ItemInfo in requirements.keys():
		var amount := int(requirements[item])
		if amount <= 0:
			continue
		inventory.remove(item, amount)
		quest.add_supply(item, amount)
	return true

func quest_has_supplies_for_level(quest: Quest, level: int) -> bool:
	return quest != null and quest.supplies != null and quest.supplies.has_all(get_required_supplies_for_level(level))

func has_available_supplies(inventory: ContentGroup) -> bool:
	if required_supplies.is_empty():
		return true
	return inventory != null and inventory.has_all(required_supplies)

func assign_required_supplies(quest: Quest, inventory: ContentGroup) -> bool:
	if quest == null:
		return false
	if not has_available_supplies(inventory):
		return false

	for item: ItemInfo in required_supplies.keys():
		var amount := int(required_supplies[item])
		if amount <= 0:
			continue
		inventory.remove(item, amount)
		quest.add_supply(item, amount)
	return true

func quest_has_supplies(quest: Quest) -> bool:
	if quest == null:
		return false
	if required_supplies.is_empty():
		return true
	return quest.supplies != null and quest.supplies.has_all(required_supplies)

func roll_outcome(danger_multiplier: float = 1.0) -> QuestOutcome:
	var valid_outcomes: Array[QuestOutcome] = []
	var cumulative: Array[float] = []
	var total_weight := 0.0
	var clamped_danger_multiplier := maxf(0.0, danger_multiplier)

	for outcome in outcomes:
		if outcome == null:
			continue
		var resolved_weight := outcome.weight
		if outcome.is_dangerous:
			resolved_weight *= clamped_danger_multiplier
		if resolved_weight <= 0.0:
			continue
		total_weight += resolved_weight
		valid_outcomes.append(outcome)
		cumulative.append(total_weight)

	if valid_outcomes.is_empty():
		return null

	var roll := randf() * total_weight
	for i in cumulative.size():
		if roll <= cumulative[i]:
			return valid_outcomes[i]

	return valid_outcomes[-1]

func get_float_modifier(key: String, fallback: float) -> float:
	return float(modifiers.get(key, fallback))

func get_int_modifier(key: String, fallback: int) -> int:
	return int(modifiers.get(key, fallback))

func get_completion_spot_stage(objective: QuestObjective) -> SpotProgress.Stage:
	if objective != null and objective.has_occupation():
		if not occupation_must_be_revealed or objective.is_occupation_revealed():
			if occupied_completion_spot_stage != SpotProgress.Stage.UNKNOWN:
				return occupied_completion_spot_stage
	if objective != null and objective.state_machine != null:
		var state_name := objective.state_machine.get_current_state()
		if objective_state_spot_stage_overrides.has(state_name):
			return int(objective_state_spot_stage_overrides[state_name])
	return completion_spot_stage
