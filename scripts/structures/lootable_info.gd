class_name LootableStructureInfo extends StructureInfo

@export var item: ItemInfo;
@export var min_item_amount: int = 1
@export var max_item_amount: int = 5
@export var loot_table: LootTable

func roll_loot() -> Dictionary[ItemInfo, int]:
	if loot_table != null:
		return loot_table.roll()

	var loot: Dictionary[ItemInfo, int] = {}
	if item != null:
		loot[item] = randi_range(min_item_amount, max(min_item_amount, max_item_amount))
	return loot
