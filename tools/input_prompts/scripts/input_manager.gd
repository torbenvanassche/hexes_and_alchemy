extends Node

@onready var mappable_actions: Dictionary = {
	"move_forward": "KEYBIND_MOVE_FORWARD",
	"move_backward": "KEYBIND_MOVE_DOWN",
	"move_left": "KEYBIND_MOVE_LEFT",
	"move_right": "KEYBIND_MOVE_RIGHT",
	"move_sprint": "KEYBIND_SPRINT",
	
	"camera_pan_forward": "KEYBIND_CAMERA_PAN_FORWARD",
	"camera_pan_backward": "KEYBIND_CAMERA_PAN_DOWN",
	"camera_pan_left": "KEYBIND_CAMERA_PAN_LEFT",
	"camera_pan_right": "KEYBIND_CAMERA_PAN_RIGHT",
	
	"camera_rotate_left": "KEYBIND_CAMERA_ROTATE_LEFT",
	"camera_rotate_right": "KEYBIND_CAMERA_ROTATE_RIGHT",
	
	"toggle_input": "KEYBIND_TOGGLE_INPUT",
	"primary_action": "KEYBIND_PRIMARY_ACTION",
	
	"cancel": "KEYBIND_CANCEL"
}

enum InputDevice {
	KEYBOARD_MOUSE,
	CONTROLLER
}

var current_input_device := InputDevice.KEYBOARD_MOUSE;
signal input_mode_changed();

var action_to_remap: StringName;
var is_remapping: bool = false;
var remapping_button: InputDisplayer = null;

var dictionary_path: String = "res://tools/input_prompts/input_prompts.json";
@onready var keyboard_image: Texture2D = preload("res://tools/input_prompts/textures/kb_mouse_inputs.png");
@onready var controller_image: Texture2D = preload("res://tools/input_prompts/textures/xbox-controller_inputs.png");

var keys: Dictionary:
	get:
		if !keys:
			keys = FileUtils.load_json(dictionary_path);
		return keys;
		
func get_icon_size() -> Vector2i:
	return Vector2i(keys.rect_size[0], keys.rect_size[1]);
	
func get_rect(coord: Vector2i) -> Rect2:
	return Rect2(coord.x * get_icon_size().x, coord.y * get_icon_size().y, get_icon_size().x, get_icon_size().y);
		
func get_input_texture() -> AtlasTexture:
	var a := AtlasTexture.new();
	if current_input_device == InputDevice.KEYBOARD_MOUSE:
		a.atlas = keyboard_image;
	else:
		a.atlas = controller_image;
	return a.duplicate(true);

func get_key(key: String) -> Array:
	if current_input_device == InputDevice.KEYBOARD_MOUSE:
		if keys.keyboard.has(key):
			return keys.keyboard[key]
		elif keys.mouse.has(key):
			return keys.mouse[key]
	elif keys.controller.has(key):
			return keys.controller[key]
	return [];
	
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		current_input_device = InputDevice.CONTROLLER;
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		current_input_device = InputDevice.KEYBOARD_MOUSE;
	input_mode_changed.emit();

func set_action(action: StringName, event: InputEvent) -> void:
	InputMap.action_erase_events(action);
	InputMap.action_add_event(action, event);

func replace_action(action: StringName, event: InputEvent) -> void:
	set_action(action, event);
	remapping_button.set_key(event_to_key(event), event);
	Manager.instance.input.change_keybinding(action_to_remap, event);
	
	is_remapping = false;
	action_to_remap = "";
	remapping_button = null;
	
func is_device(input_device: InputDevice) -> bool:
	return current_input_device == input_device;

func _matches_device(e: InputEvent) -> bool:
	match current_input_device:
		InputDevice.KEYBOARD_MOUSE:
			return not (e is InputEventJoypadButton or e is InputEventJoypadMotion);
		InputDevice.CONTROLLER:
			return e is InputEventJoypadButton or e is InputEventJoypadMotion;
	return false;

func get_keybind(action: String) -> InputEvent:
	for e in InputMap.action_get_events(action):
		if _matches_device(e):
			return e;
	return null;

func event_to_key(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event := event as InputEventKey;
		var code := key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode;
		return OS.get_keycode_string(code).to_lower();

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT: return "left mouse button";
			MOUSE_BUTTON_RIGHT: return "right mouse button";
			MOUSE_BUTTON_MIDDLE: return "mouse";
			MOUSE_BUTTON_WHEEL_UP: return "scroll up";
			MOUSE_BUTTON_WHEEL_DOWN: return "scroll down";

	if event is InputEventJoypadButton:
		match event.button_index:
			JOY_BUTTON_A: return "joypad_a";
			JOY_BUTTON_B: return "joypad_b";
			JOY_BUTTON_X: return "joypad_x";
			JOY_BUTTON_Y: return "joypad_y";
			JOY_BUTTON_BACK: return "joypad_back";
			JOY_BUTTON_GUIDE: return "joypad_guide";
			JOY_BUTTON_START: return "joypad_start";
			JOY_BUTTON_LEFT_STICK: return "joypad_left_stick";
			JOY_BUTTON_RIGHT_STICK: return "joypad_right_stick";
			JOY_BUTTON_LEFT_SHOULDER: return "joypad_left_shoulder";
			JOY_BUTTON_RIGHT_SHOULDER: return "joypad_right_shoulder";
			JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
				return "joypad_dpad";

	if event is InputEventJoypadMotion:
		match event.axis:
			JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
				return "joypad_left_stick";
			JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
				return "joypad_right_stick";
			JOY_AXIS_TRIGGER_LEFT:
				return "joypad_left_trigger";
			JOY_AXIS_TRIGGER_RIGHT:
				return "joypad_right_trigger";
	return "";

func get_input_icon(action: String) -> Array[int]:
	var dict_key: String = event_to_key(get_keybind(action));
	var rV: Array[int];
	rV.assign(get_key(dict_key));
	return rV;
