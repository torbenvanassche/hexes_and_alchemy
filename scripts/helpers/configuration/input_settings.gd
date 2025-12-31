class_name InputSettings
extends RefCounted

const SECTION := "keybinds"

var _config: ConfigFile

func _init(config: ConfigFile) -> void:
	_config = config
	_ensure_defaults()

func _ensure_defaults() -> void:
	if _config.has_section(SECTION):
		return

	for action: String in InputManager.mappable_actions:
		var events := InputMap.action_get_events(action)
		if events.is_empty():
			continue

		var event := events[0]
		var value := _event_to_string(event)
		_config.set_value(SECTION, action, value)

func change_keybinding(action: StringName, event: InputEvent) -> void:
	_config.set_value(SECTION, action, _event_to_string(event))

func load_keybindings() -> Dictionary:
	var result := {}
	for action in _config.get_section_keys(SECTION):
		result[action] = _string_to_event(
			_config.get_value(SECTION, action)
		)
	return result

func _event_to_string(event: InputEvent) -> String:
	if event is InputEventKey:
		return OS.get_keycode_string(event.physical_keycode).to_lower()
	elif event is InputEventMouseButton:
		return "mouse_%d" % event.button_index
	return ""

func _string_to_event(value: String) -> InputEvent:
	if value.begins_with("mouse_"):
		var e := InputEventMouseButton.new()
		e.button_index = value.get_slice("_", 1).to_int() as MouseButton;
		return e

	var ev := InputEventKey.new()
	ev.keycode = OS.find_keycode_from_string(value)
	return ev
