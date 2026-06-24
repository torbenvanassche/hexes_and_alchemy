class_name QuestSupplyRequirement extends Resource

@export var quest_type: String = ""
@export var supplies: Dictionary[ItemInfo, int] = {}

func matches(quest_type_key: String) -> bool:
	return quest_type == quest_type_key

func has_available_supplies(inventory: ContentGroup) -> bool:
	if supplies.is_empty():
		return true
	return inventory != null and inventory.has_all(supplies)

func assign_to_quest(quest: Quest, inventory: ContentGroup) -> bool:
	if quest == null or not matches(quest.quest_key):
		return false
	if not has_available_supplies(inventory):
		return false

	for item: ItemInfo in supplies.keys():
		var amount := int(supplies[item])
		if amount <= 0:
			continue
		inventory.remove(item, amount)
		quest.add_supply(item, amount)
	return true

func quest_has_supplies(quest: Quest) -> bool:
	if quest == null or not matches(quest.quest_key):
		return false
	if supplies.is_empty():
		return true
	return quest.supplies != null and quest.supplies.has_all(supplies)
