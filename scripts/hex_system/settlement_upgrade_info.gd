class_name SettlementUpgradeInfo
extends Resource

@export_range(2, 10, 1) var target_level: int = 2
@export var item_cost: Dictionary[ItemInfo, int] = {}
@export var required_services: Array[StringName] = []
@export var unlock_translation_key: String = ""

func get_unlock_text() -> String:
	if unlock_translation_key == "":
		return ""
	var translated := tr(unlock_translation_key)
	return "" if translated == unlock_translation_key else translated
