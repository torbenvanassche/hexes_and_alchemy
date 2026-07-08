class_name QuestProfile extends Resource

@export var quest_key: String = ""
@export var behaviour: String = ""
@export var translation_key_name: String = ""
@export_multiline var description_key: String = ""
@export var risk_key: String = "QUEST_RISK_SAFE"
@export var expected_reward_key: String = ""
@export var duration_seconds: float = 5.0
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

func get_modifier(key: String, fallback: Variant = null) -> Variant:
	if modifiers.has(key):
		return modifiers[key]
	return fallback
