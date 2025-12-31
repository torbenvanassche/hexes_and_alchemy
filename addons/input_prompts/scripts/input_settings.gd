extends Node

@export var keybind_container: Node;
@onready var keybind_template: PackedScene = preload("res://addons/input_prompts/scenes/action_setter.tscn")
@onready var reset_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/reset;
@onready var confirm_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/confirm;

func _ready() -> void:
	InputMap.load_from_project_settings();
	reset_button.pressed.connect(_load_default)
	confirm_button.pressed.connect(_on_save)
	
	_load_bindings();
	_reset_bindings();
	
func _load_default() -> void:
	InputMap.load_from_project_settings();
	_reset_bindings();
	
	for action: String in InputManager.mappable_actions:
		var events: Array[InputEvent] = InputMap.action_get_events(action);
		if events.size() > 0:
			Config.input.change_keybinding(action, events[0]);
	
func _on_save() -> void:
	Config.save();

func _reset_bindings() -> void:
	for item in keybind_container.get_children():
		item.queue_free()

	for action: String in InputManager.mappable_actions:
		var btn: InputDisplayer = keybind_template.instantiate();
		btn.set_label(InputManager.mappable_actions[action]);
		var events: Array[InputEvent] = InputMap.action_get_events(action);
		if events.size() > 0:
			var key: String = events[0].as_text().to_lower();
			key = key.trim_suffix(" - physical")
			btn.set_key(key, events[0]);
		
		keybind_container.add_child(btn);
		btn.pressed.connect(_on_rebind_key.bind(btn, action))
		
func _load_bindings() -> void:
	var keybindings: Dictionary = Config.input.load_keybindings();
	for action: String in keybindings.keys():
		InputManager.set_action(action, keybindings[action])

func _on_rebind_key(button: InputDisplayer, action: String) -> void:
	if not InputManager.is_remapping:
		InputManager.is_remapping = true;
		InputManager.action_to_remap = action;
		InputManager.remapping_button = button;
		button.set_rebinding()
		
func _input(event: InputEvent) -> void:
	if InputManager.is_remapping:
		if event is InputEventKey || (event is InputEventMouseButton && event.pressed):
			InputManager.replace_action(InputManager.action_to_remap, event)
			get_viewport().set_input_as_handled()
