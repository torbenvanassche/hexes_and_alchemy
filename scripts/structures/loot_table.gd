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

func get_preview_ranges() -> Dictionary[ItemInfo, Vector2i]:
	var preview: Dictionary[ItemInfo, Vector2i] = {}
	for entry in entries:
		if entry == null or entry.item == null or entry.chance <= 0.0:
			continue

		var min_amount := entry.min_amount if entry.chance >= 1.0 else 0
		var max_amount := maxi(entry.min_amount, entry.max_amount)
		var current := preview.get(entry.item, Vector2i.ZERO) as Vector2i;
		preview[entry.item] = Vector2i(current.x + min_amount, current.y + max_amount)
	return preview
