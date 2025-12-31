extends Node

@onready var mappable_actions: Dictionary = {
	"move_forward": tr("KEYBIND_MOVE_FORWARD"),
	"move_backward": tr("KEYBIND_MOVE_DOWN"),
	"move_left": tr("KEYBIND_MOVE_LEFT"),
	"move_right": tr("KEYBIND_MOVE_RIGHT"),
	"move_sprint": tr("KEYBIND_SPRINT"),
	
	"camera_pan_forward": tr("KEYBIND_CAMERA_PAN_FORWARD"),
	"camera_pan_backward": tr("KEYBIND_CAMERA_PAN_DOWN"),
	"camera_pan_left": tr("KEYBIND_CAMERA_PAN_LEFT"),
	"camera_pan_right": tr("KEYBIND_CAMERA_PAN_RIGHT"),
	
	"camera_rotate_left": tr("KEYBIND_CAMERA_ROTATE_LEFT"),
	"camera_rotate_right": tr("KEYBIND_CAMERA_ROTATE_RIGHT"),
	
	"toggle_input": tr("KEYBIND_TOGGLE_INPUT"),
	"primary_action": tr("PRIMARY_ACTION"),
	
	"cancel": tr("KEYBIND_CANCEL")
}

enum InputDevice {
	KEYBOARD_MOUSE,
	CONTROLLER
}

var current_input_device := InputDevice.KEYBOARD_MOUSE
signal input_mode_changed();

var action_to_remap: StringName;
var is_remapping: bool = false;
var remapping_button: InputDisplayer = null;
var dictionary_path: String = "res://addons/input_prompts/input_prompts.json"

var keys: Dictionary:
	get:
		if !keys:
			keys = FileUtils.load_json(dictionary_path)
		return keys;

func get_key(key: String) -> Array:
	if Manager.instance.current_input_device == Manager.instance.InputDevice.KEYBOARD_MOUSE:
		if keys.keyboard.has(key):
			return keys.keyboard[key]
		elif keys.mouse.has(key):
			return keys.mouse[key]
	elif keys.controller.has(key):
			return keys.controller[key]
	return [];
	
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		current_input_device = InputDevice.CONTROLLER
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		current_input_device = InputDevice.KEYBOARD_MOUSE
	input_mode_changed.emit();

func set_action(action: StringName, event: InputEvent) -> void:
	InputMap.action_erase_events(action);
	InputMap.action_add_event(action, event)

func replace_action(action: StringName, event: InputEvent) -> void:
	set_action(action, event)
	remapping_button.set_key(event.as_text().trim_suffix(" (Physical)").to_lower(), event)
	Config.input.change_keybinding(action_to_remap, event)
	
	is_remapping = false;
	action_to_remap = "";
	remapping_button = null;
	
func is_device(input_device: InputDevice) -> bool:
	return current_input_device == input_device;

func _matches_device(e: InputEvent) -> bool:
	match current_input_device:
		InputDevice.KEYBOARD_MOUSE:
			return not (e is InputEventJoypadButton or e is InputEventJoypadMotion)
		InputDevice.CONTROLLER:
			return e is InputEventJoypadButton or e is InputEventJoypadMotion
	return false

func get_keybind(action: String) -> InputEvent:
	for e in InputMap.action_get_events(action):
		if _matches_device(e):
			return e
	return null

func event_to_key(event: InputEvent) -> String:
	if event is InputEventKey:
		return OS.get_keycode_string(event.keycode).to_lower()

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT: return "left mouse button"
			MOUSE_BUTTON_RIGHT: return "right mouse button"
			MOUSE_BUTTON_MIDDLE: return "mouse"
			MOUSE_BUTTON_WHEEL_UP: return "scroll up"
			MOUSE_BUTTON_WHEEL_DOWN: return "scroll down"
	return ""

func get_input_icon(action: String) -> Array[int]:
	var dict_key: String = event_to_key(get_keybind(action));
	var rV: Array[int];
	rV.assign(get_key(dict_key))
	return rV;
