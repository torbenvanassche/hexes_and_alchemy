class_name InputSettings
extends RefCounted

const SECTION := "keybinds"
const CONTROLLER_SECTION := "controller_keybinds"

var _config: ConfigFile

func _init(config: ConfigFile) -> void:
	_config = config
	_ensure_defaults()

func _ensure_defaults() -> void:
	var changed := false
	for action: String in InputManager.mappable_actions:
		if _config.has_section_key(SECTION, action):
			continue
		var events := InputMap.action_get_events(action)
		if events.is_empty():
			continue

		var event := events[0]
		var value := _event_to_string(event)
		_config.set_value(SECTION, action, value)
		changed = true
	if _migrate_misassigned_navigation_bindings():
		changed = true
	if changed and is_instance_valid(Manager.instance):
		Manager.instance.save()

func _migrate_misassigned_navigation_bindings() -> bool:
	if not _config.has_section_key(SECTION, "inventory") or not _config.has_section_key(SECTION, "hub"):
		return false
	var inventory_binding := str(_config.get_value(SECTION, "inventory")).to_lower()
	var hub_binding := str(_config.get_value(SECTION, "hub")).to_lower()
	if inventory_binding != "w" or hub_binding != "y":
		return false
	for action: String in ["inventory", "hub"]:
		var events := InputMap.action_get_events(action)
		if not events.is_empty():
			_config.set_value(SECTION, action, _event_to_string(events[0]))
	return true

func change_keybinding(action: StringName, event: InputEvent) -> void:
	var controller := event is InputEventJoypadButton or event is InputEventJoypadMotion
	_config.set_value(CONTROLLER_SECTION if controller else SECTION, action, _event_to_string(event))

func apply_bindings() -> void:
	var bindings := load_keybindings()
	for action: String in bindings:
		InputManager.set_action(action, bindings[action])
	if _config.has_section(CONTROLLER_SECTION):
		for action: String in _config.get_section_keys(CONTROLLER_SECTION):
			InputManager.set_action(action, _string_to_event(str(_config.get_value(CONTROLLER_SECTION, action))))

func reset_bindings() -> void:
	_config.erase_section(SECTION)
	_config.erase_section(CONTROLLER_SECTION)
	for action: String in InputManager.mappable_actions:
		_restore_default_events(action)
	# Controller cancel is mirrored to Godot's interface cancel action.
	_restore_default_events("ui_cancel")
	_ensure_defaults()
	InputManager.bindings_changed.emit()

func _restore_default_events(action: String) -> void:
	var binding: Dictionary = ProjectSettings.get_setting("input/" + action, {})
	if not binding.has("events") or not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for event: InputEvent in binding["events"]:
		InputMap.action_add_event(action, event.duplicate())

func load_keybindings() -> Dictionary[String, InputEvent]:
	var result: Dictionary[String, InputEvent] = {}
	for action in _config.get_section_keys(SECTION):
		result[action] = _string_to_event(
			_config.get_value(SECTION, action)
		)
	return result

func _event_to_string(event: InputEvent) -> String:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		return "key:%d:%d:%d:%d:%d" % [code, int(event.shift_pressed), int(event.ctrl_pressed), int(event.alt_pressed), int(event.meta_pressed)]
	elif event is InputEventMouseButton:
		return "mouse_%d" % event.button_index
	elif event is InputEventJoypadButton:
		return "joy_button_%d" % event.button_index
	elif event is InputEventJoypadMotion:
		return "joy_axis_%d_%s" % [event.axis, str(signf(event.axis_value))]
	return ""

func _string_to_event(value: String) -> InputEvent:
	if value.begins_with("key:"):
		var key := InputEventKey.new()
		key.physical_keycode = value.get_slice(":", 1).to_int()
		key.shift_pressed = value.get_slice(":", 2) == "1"
		key.ctrl_pressed = value.get_slice(":", 3) == "1"
		key.alt_pressed = value.get_slice(":", 4) == "1"
		key.meta_pressed = value.get_slice(":", 5) == "1"
		return key
	if value.begins_with("joy_button_"):
		var button := InputEventJoypadButton.new()
		button.button_index = value.get_slice("_", 2).to_int()
		return button
	if value.begins_with("joy_axis_"):
		var axis := InputEventJoypadMotion.new()
		axis.axis = value.get_slice("_", 2).to_int()
		axis.axis_value = value.get_slice("_", 3).to_float()
		return axis
	if value.begins_with("mouse_"):
		var e := InputEventMouseButton.new()
		e.button_index = value.get_slice("_", 1).to_int() as MouseButton;
		return e

	var ev := InputEventKey.new()
	ev.keycode = OS.find_keycode_from_string(value)
	return ev
