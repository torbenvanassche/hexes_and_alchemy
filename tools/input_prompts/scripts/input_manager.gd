extends Node

@onready var mappable_actions: Dictionary[String, String] = {
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
	"camera_zoom_in": "KEYBIND_CAMERA_ZOOM_IN",
	"camera_zoom_out": "KEYBIND_CAMERA_ZOOM_OUT",
	
	"toggle_input": "KEYBIND_TOGGLE_INPUT",
	"primary_action": "KEYBIND_PRIMARY_ACTION",
	"inventory": "KEYBIND_INVENTORY",
	"journal": "KEYBIND_JOURNAL",
	"hub": "KEYBIND_HUB",
	
	"cancel": "KEYBIND_CANCEL",
	"pause": "KEYBIND_PAUSE",
	"ui_accept": "UI_CONFIRM",
	"ui_focus_next": "UI_NEXT_CONTROL",
	"ui_focus_prev": "UI_PREVIOUS_CONTROL",
	"ui_slot_place": "PLACEMENT_PLACE"
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	controller_ui = preload("res://tools/input_prompts/scenes/controller_ui.tscn").instantiate()
	add_child(controller_ui)
	for action: String in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		InputMap.action_set_deadzone(action, 0.3)
	Input.joy_connection_changed.connect(_controller_connection_changed)

func _controller_connection_changed(device: int, connected: bool) -> void:
	if not connected and controller_device == device:
		controller_device = -1
		current_input_device = InputDevice.KEYBOARD_MOUSE
	input_mode_changed.emit()

# Keep focus in the foremost screen, including after tabs rebuild their contents.
func _process(_delta: float) -> void:
	if current_input_device != InputDevice.CONTROLLER or is_remapping:
		return
	var root: Node = controller_ui.active_root()
	if root == null: return
	var owner := get_viewport().gui_get_focus_owner()
	# Popup menus manage their own focus outside their owning screen's subtree.
	if owner != null and owner.get_window() != get_viewport().get_window(): return
	if owner == null or owner.is_queued_for_deletion() or not owner.is_visible_in_tree() or (owner is BaseButton and owner.disabled) or not (root == owner or root.is_ancestor_of(owner)):
		var target: Control = controller_ui.restore_focus(root)
		if target == null: target = _first_focusable(root)
		if target != null: target.grab_focus()
	owner = get_viewport().gui_get_focus_owner()
	if owner != null and owner.get_instance_id() != _focused_control_id:
		_focused_control_id = owner.get_instance_id()
		var parent := owner.get_parent()
		while parent != null:
			if parent is ScrollContainer:
				parent.ensure_control_visible(owner)
			parent = parent.get_parent()

func _first_focusable(node: Node) -> Control:
	if node.is_queued_for_deletion(): return null
	if node is Control:
		if not node.is_visible_in_tree(): return null
		if node.focus_mode == Control.FOCUS_ALL and not (node is BaseButton and node.disabled):
			return node
	# Window contents take priority over close/lock actions on initial entry.
	if node is DraggableControl:
		var target := _first_focusable(node.content_panel)
		if target != null: return target
	for child in node.get_children():
		var target := _first_focusable(child)
		if target != null: return target
	return null

enum InputDevice {
	KEYBOARD_MOUSE,
	CONTROLLER
}

var current_input_device := InputDevice.KEYBOARD_MOUSE;
var _focused_control_id := 0
var controller_device := -1
var controller_ui: CanvasLayer
signal input_mode_changed();
signal bindings_changed()

var action_to_remap: StringName;
var is_remapping: bool = false;
var remapping_button: InputDisplayer = null;

var dictionary_path: String = "res://tools/input_prompts/input_prompts.json";
@onready var keyboard_image: Texture2D = preload("res://tools/input_prompts/textures/kb_mouse_inputs.png");
@onready var controller_image: Texture2D = preload("res://tools/input_prompts/textures/xbox-controller_inputs.png");

var keys: Dictionary[String, Variant]:
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
	if event is InputEventJoypadMotion and absf(event.axis_value) < 0.3:
		return
	if event is InputEventJoypadButton and not event.pressed:
		return
	if event is InputEventMouseMotion and event.relative.length_squared() < 4.0:
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if controller_device != event.device:
			controller_device = event.device
			input_mode_changed.emit()
	var next_input_device := current_input_device
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		next_input_device = InputDevice.CONTROLLER
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		next_input_device = InputDevice.KEYBOARD_MOUSE
	if next_input_device == current_input_device:
		return
	current_input_device = next_input_device
	input_mode_changed.emit()

func set_action(action: StringName, event: InputEvent) -> void:
	if event == null or not InputMap.has_action(action):
		return
	var controller := event is InputEventJoypadButton or event is InputEventJoypadMotion
	if controller: event.device = -1
	for existing: InputEvent in InputMap.action_get_events(action):
		if controller == (existing is InputEventJoypadButton or existing is InputEventJoypadMotion):
			InputMap.action_erase_event(action, existing)
	InputMap.action_add_event(action, event);
	if action == &"cancel" and controller:
		for existing: InputEvent in InputMap.action_get_events("ui_cancel"):
			if existing is InputEventJoypadButton or existing is InputEventJoypadMotion:
				InputMap.action_erase_event("ui_cancel", existing)
		InputMap.action_add_event("ui_cancel", event)
	bindings_changed.emit()

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
	var rect_values: Array[int] = []
	rect_values.assign(get_key(dict_key));
	return rect_values;

func controller_family() -> String:
	var device_name := Input.get_joy_name(controller_device).to_lower()
	var info := Input.get_joy_info(controller_device)
	var vendor := int(info.get("vendor_id", 0))
	if vendor == 0x054c or "sony" in device_name or "playstation" in device_name or "dual" in device_name or "ps4" in device_name or "ps5" in device_name or device_name == "wireless controller":
		return "playstation"
	if vendor == 0x057e or "nintendo" in device_name or "switch" in device_name or "joy-con" in device_name:
		return "nintendo"
	return "xbox"

func describe_event(event: InputEvent) -> String:
	if event == null: return "—"
	if event is InputEventKey: return event.as_text().trim_suffix(" (Physical)")
	if event is InputEventJoypadButton:
		var labels := ["A", "B", "X", "Y", "View", "Guide", "Start", "LS", "RS", "LB", "RB", "D-pad ↑", "D-pad ↓", "D-pad ←", "D-pad →"]
		if controller_family() == "playstation":
			labels = ["×", "○", "□", "△", "Share", "PS", "Options", "L3", "R3", "L1", "R1", "D-pad ↑", "D-pad ↓", "D-pad ←", "D-pad →"]
		elif controller_family() == "nintendo":
			labels = ["B", "A", "Y", "X", "−", "Home", "+", "LS", "RS", "L", "R", "D-pad ↑", "D-pad ↓", "D-pad ←", "D-pad →"]
		return labels[event.button_index] if event.button_index < labels.size() else event.as_text()
	if event is InputEventJoypadMotion:
		var axis_names := ["LS", "LS", "RS", "RS", "LT", "RT"]
		if controller_family() == "playstation": axis_names = ["LS", "LS", "RS", "RS", "L2", "R2"]
		if controller_family() == "nintendo": axis_names = ["LS", "LS", "RS", "RS", "ZL", "ZR"]
		if event.axis >= axis_names.size(): return event.as_text()
		if event.axis >= JOY_AXIS_TRIGGER_LEFT: return axis_names[event.axis]
		return axis_names[event.axis] + (" ←" if event.axis_value < 0 else " →") if event.axis % 2 == 0 else axis_names[event.axis] + (" ↑" if event.axis_value < 0 else " ↓")
	return event.as_text()

func action_label(action: String) -> String:
	return describe_event(get_keybind(action))
