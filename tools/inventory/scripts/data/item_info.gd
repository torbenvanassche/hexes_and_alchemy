class_name ItemInfo extends Resource

@export var unique_id: String;
@export var translation_key_name: String;
@export var translation_key_description: String;
@export var texture: Texture2D;
@export var buy_value: int = 2;
@export var sell_value: int = 1;
@export var recipe: Dictionary[ItemInfo, int];

func has_recipe() -> bool:
	return not recipe.is_empty()

func get_display_name() -> String:
	return _translate_with_fallback(translation_key_name, unique_id.capitalize())

func get_description() -> String:
	return _translate_with_fallback(translation_key_description, "")

func get_buy_value() -> int:
	return maxi(2, buy_value)

func get_sell_value() -> int:
	return maxi(1, mini(sell_value, get_buy_value() - 1))

func _translate_with_fallback(key: String, fallback: String) -> String:
	if key == "":
		return fallback
	var translated := tr(key)
	if translated == key:
		return fallback
	return translated
