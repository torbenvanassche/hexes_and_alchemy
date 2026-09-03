class_name LootTable extends Resource

@export var entries: Array[LootTableEntry] = []
@export_group("Single Choice Bonus")
## At most one item from this pool is added when the bonus roll succeeds.
@export var choice_pool: Array[ItemInfo] = []
@export_range(0.0, 1.0, 0.01) var choice_chance := 0.0

func roll() -> Dictionary[ItemInfo, int]:
	var loot: Dictionary[ItemInfo, int] = {}
	for entry in entries:
		if entry == null or entry.item == null:
			continue

		var amount := entry.roll_amount()
		if amount <= 0:
			continue

		loot[entry.item] = loot.get(entry.item, 0) + amount
	var choice := _roll_choice()
	if choice != null:
		loot[choice] = loot.get(choice, 0) + 1
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
	if choice_chance > 0.0:
		for item in choice_pool:
			if item != null:
				preview[item] = Vector2i(0, maxi(1, preview.get(item, Vector2i.ZERO).y))
	return preview

func _roll_choice() -> ItemInfo:
	if choice_pool.is_empty() or choice_chance <= 0.0 or randf() > choice_chance:
		return null
	var total_weight := 0.0
	var weighted_items: Array[ItemInfo] = []
	var cumulative_weights: Array[float] = []
	for item in choice_pool:
		if item == null:
			continue
		var weight: float = item.get_reward_weight() if item is EquipmentInfo else 1.0
		if weight <= 0.0:
			continue
		total_weight += weight
		weighted_items.append(item)
		cumulative_weights.append(total_weight)
	if weighted_items.is_empty():
		return null
	var roll := randf() * total_weight
	for index in cumulative_weights.size():
		if roll <= cumulative_weights[index]:
			return _create_reward_item(weighted_items[index])
	return _create_reward_item(weighted_items[-1])

func _create_reward_item(item: ItemInfo) -> ItemInfo:
	if item is EquipmentInfo and (item as EquipmentInfo).tier == EquipmentInfo.Tier.RELIC:
		return (item as EquipmentInfo).create_randomized_relic()
	return item
