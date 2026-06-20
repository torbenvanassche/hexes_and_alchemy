class_name LootTableEntry extends Resource

@export var item: ItemInfo
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
@export var min_amount: int = 1
@export var max_amount: int = 1

func roll_amount() -> int:
	if item == null or chance <= 0.0:
		return 0
	if randf() > chance:
		return 0
	return randi_range(min_amount, max(min_amount, max_amount))
