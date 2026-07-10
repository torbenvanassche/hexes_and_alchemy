class_name QuestProfile extends Resource

@export var quest_key: String = ""
@export var behaviour: String = ""
@export var translation_key_name: String = ""
@export_multiline var description_key: String = ""
@export var risk_key: String = "QUEST_RISK_SAFE"
@export var expected_reward_key: String = ""
@export var duration_seconds: float = 5.0
@export var minimum_rank: AdventurerRank.Rank = AdventurerRank.Rank.F
@export_range(0, 100, 1) var rank_experience_reward: int = 1
@export var available_states: Array[String] = []
@export var required_supplies: Dictionary[ItemInfo, int] = {}
@export var outcomes: Array[QuestOutcome] = []
@export var modifiers: Dictionary = {}

func matches(quest_type_key: String) -> bool:
	return quest_key == quest_type_key

func get_behaviour() -> String:
	if behaviour != "":
		return behaviour
	return quest_key

func is_available_for_state(state_name: String) -> bool:
	return available_states.is_empty() or available_states.has(state_name)

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

		var ranges := outcome.get_preview_ranges()
		if ranges.is_empty():
			continue

		valid_outcome_count += 1
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

func get_rank_experience_reward() -> int:
	return maxi(0, rank_experience_reward)

func get_required_supplies() -> Dictionary[ItemInfo, int]:
	return required_supplies

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

func roll_outcome() -> QuestOutcome:
	var valid_outcomes: Array[QuestOutcome] = []
	var cumulative: Array[float] = []
	var total_weight := 0.0

	for outcome in outcomes:
		if outcome == null or outcome.weight <= 0.0:
			continue
		total_weight += outcome.weight
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
