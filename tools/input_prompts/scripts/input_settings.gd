extends Node

@export var keybind_container: Node;
@onready var keybind_template: PackedScene = preload("res://tools/input_prompts/scenes/action_setter.tscn")
@onready var reset_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/reset;
@onready var confirm_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/confirm;

func _ready() -> void:
	InputMap.load_from_project_settings();
	reset_button.pressed.connect(_load_default)
	confirm_button.pressed.connect(_on_save)
	
	_load_bindings();
	_reset_bindings();
	InputManager.input_mode_changed.connect(_refresh_binding_icons)
	InputManager.bindings_changed.connect(_refresh_binding_icons)

func _exit_tree() -> void:
	InputManager.is_remapping = false
	InputManager.remapping_button = null
	InputManager.action_to_remap = &""

func _refresh_binding_icons() -> void:
	if InputManager.is_remapping: return
	for button: InputDisplayer in keybind_container.get_children():
		if button.is_queued_for_deletion(): continue
		var event := InputManager.get_keybind(str(button.get_meta("action")))
		button.set_key(InputManager.event_to_key(event), event)
	
func _load_default() -> void:
	Manager.instance.input.reset_bindings()
	_reset_bindings();
	
	for action: String in InputManager.mappable_actions:
		var events: Array[InputEvent] = InputMap.action_get_events(action);
		if events.size() > 0:
			Manager.instance.input.change_keybinding(action, events[0]);
	
func _on_save() -> void:
	Manager.instance.save();

func _reset_bindings() -> void:
	for item in keybind_container.get_children():
		item.queue_free()

	for action: String in InputManager.mappable_actions:
		var btn: InputDisplayer = keybind_template.instantiate();
		btn.set_meta("action", action)
		btn.set_label(InputManager.mappable_actions[action]);
		var event := InputManager.get_keybind(action)
		btn.set_key(InputManager.event_to_key(event), event)
		
		keybind_container.add_child(btn);
		btn.pressed.connect(_on_rebind_key.bind(btn, action))
		
func _load_bindings() -> void:
	Manager.instance.input.apply_bindings()

func _on_rebind_key(button: InputDisplayer, action: String) -> void:
	if not InputManager.is_remapping:
		InputManager.is_remapping = true;
		InputManager.action_to_remap = action;
		InputManager.remapping_button = button;
		button.set_rebinding()
		
func _input(event: InputEvent) -> void:
	if InputManager.is_remapping:
		if (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
			InputManager.is_remapping = false
			InputManager.remapping_button = null
			InputManager.action_to_remap = &""
			_refresh_binding_icons()
			get_viewport().set_input_as_handled()
			return
		if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) >= 0.6):
			InputManager.replace_action(InputManager.action_to_remap, event)
			get_viewport().set_input_as_handled()
