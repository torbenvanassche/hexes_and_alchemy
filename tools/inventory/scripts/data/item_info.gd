class_name ItemInfo extends Resource

@export var unique_id: String;
@export var translation_key_name: String;
@export var translation_key_description: String;
@export var texture: Texture2D;
@export var base_value: int = 1;
@export var recipe: Dictionary[ItemInfo, int];

func has_recipe() -> bool:
	return not recipe.is_empty()

func get_display_name() -> String:
	return _translate_with_fallback(translation_key_name, unique_id.capitalize())

func get_description() -> String:
	return _translate_with_fallback(translation_key_description, "")

func _translate_with_fallback(key: String, fallback: String) -> String:
	if key == "":
		return fallback
	var translated := tr(key)
	if translated == key:
		return fallback
	return translated
