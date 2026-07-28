class_name SettlementUpgradeInfo
extends Resource

@export_range(2, 10, 1) var target_level: int = 2
@export var item_cost: Dictionary[ItemInfo, int] = {}
@export var required_services: Array[StringName] = []
@export var market_buy_menu: Array[ContentSlotResource] = []
@export var unlock_translation_key: String = ""

func get_unlock_text() -> String:
	if unlock_translation_key == "":
		return ""
	var translated_text := tr(unlock_translation_key)
	return "" if translated_text == unlock_translation_key else translated_text
