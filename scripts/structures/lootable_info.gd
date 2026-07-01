class_name LootableStructureInfo extends StructureInfo

@export var loot_table: LootTable
@export var loot_once: bool = false

func roll_loot() -> Dictionary[ItemInfo, int]:
	if loot_table == null:
		return {}
	return loot_table.roll()
