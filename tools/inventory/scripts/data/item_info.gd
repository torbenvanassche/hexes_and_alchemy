class_name ItemInfo extends Resource

@export var unique_id: String;
@export var translation_key_name: String;
@export var translation_key_description: String;
@export var texture: Texture2D;
@export var base_value: int = 1;

func get_display_name() -> String:
	return _translate_with_fallback(_get_translation_key("NAME"), unique_id.capitalize())

func get_description() -> String:
	return _translate_with_fallback(_get_translation_key("DESCRIPTION"), "")

func _get_translation_key(suffix: String) -> String:
	var configured_key := translation_key_name if suffix == "NAME" else translation_key_description
	if configured_key != "":
		return configured_key
	return "ITEM_%s_%s" % [unique_id.to_upper(), suffix]

func _translate_with_fallback(key: String, fallback: String) -> String:
	var translated := tr(key)
	if translated == key:
		return fallback
	return translated
