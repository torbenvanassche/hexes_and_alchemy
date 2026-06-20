class_name LootTable extends Resource

@export var entries: Array[LootTableEntry] = []

func roll() -> Dictionary[ItemInfo, int]:
	var loot: Dictionary[ItemInfo, int] = {}
	for entry in entries:
		if entry == null or entry.item == null:
			continue

		var amount := entry.roll_amount()
		if amount <= 0:
			continue

		loot[entry.item] = loot.get(entry.item, 0) + amount
	return loot
