extends Control

const GROUPS := {
	&"Movement": ["move_forward", "move_backward", "move_left", "move_right", "move_sprint", "primary_action", "toggle_input"],
	&"Camera": ["camera_pan_forward", "camera_pan_backward", "camera_pan_left", "camera_pan_right",
		"camera_rotate_left", "camera_rotate_right", "camera_zoom_in", "camera_zoom_out"],
	&"Menus": ["inventory", "journal", "hub", "pause"],
	&"Interface": ["ui_accept", "cancel", "ui_focus_next", "ui_focus_prev", "ui_slot_place"],
}
const KEYBIND_TEMPLATE := preload("res://tools/input_prompts/scenes/action_setter.tscn")

@onready var categories: TabContainer = %Categories
@onready var reset_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/reset
@onready var confirm_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/confirm

var _binding_buttons: Dictionary[String, InputDisplayer] = {}

func _ready() -> void:
	_build_binding_rows()
	_refresh_binding_icons()
	reset_button.pressed.connect(Manager.instance.input.reset_bindings)
	confirm_button.pressed.connect(Manager.instance.save)
	InputManager.input_mode_changed.connect(_refresh_binding_icons)
	InputManager.bindings_changed.connect(_refresh_binding_icons)
	categories.get_tab_bar().focus_mode = Control.FOCUS_ALL
	categories.tab_changed.connect(_cancel_remapping.unbind(1))
	visibility_changed.connect(_cancel_if_hidden)

func _exit_tree() -> void:
	_cancel_remapping()

func _build_binding_rows() -> void:
	for index in categories.get_tab_count():
		var page := categories.get_tab_control(index)
		categories.set_tab_title(index, "INPUT_GROUP_%s" % String(page.name).to_upper())
		var rows: VBoxContainer = page.get_node("Margin/Rows")
		for action: String in GROUPS.get(page.name, []):
			_add_binding_row(action, rows)

	var interface_rows: VBoxContainer = categories.get_node("Interface/Margin/Rows")
	for action: String in InputManager.mappable_actions:
		if not _binding_buttons.has(action):
			_add_binding_row(action, interface_rows)

func _add_binding_row(action: String, rows: VBoxContainer) -> void:
	if not InputManager.mappable_actions.has(action) or _binding_buttons.has(action):
		return
	var button: InputDisplayer = KEYBIND_TEMPLATE.instantiate()
	rows.add_child(button)
	button.set_label(InputManager.mappable_actions[action])
	button.pressed.connect(_on_rebind_key.bind(button, action))
	_binding_buttons[action] = button

func _refresh_binding_icons() -> void:
	for action: String in _binding_buttons:
		var button := _binding_buttons[action]
		if button == InputManager.remapping_button:
			continue
		var event := InputManager.get_keybind(action)
		button.set_key(InputManager.event_to_key(event), event)

func _on_rebind_key(button: InputDisplayer, action: String) -> void:
	if InputManager.is_remapping:
		return
	InputManager.is_remapping = true
	InputManager.action_to_remap = action
	InputManager.remapping_button = button
	button.set_rebinding()

func _owns_remap() -> bool:
	var button := InputManager.remapping_button
	return InputManager.is_remapping and is_instance_valid(button) and is_ancestor_of(button)

func _cancel_if_hidden() -> void:
	if not is_visible_in_tree():
		_cancel_remapping()

func _cancel_remapping() -> void:
	if not _owns_remap():
		return
	InputManager.is_remapping = false
	InputManager.remapping_button = null
	InputManager.action_to_remap = &""
	_refresh_binding_icons()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _owns_remap():
		return
	if (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
		_cancel_remapping()
		get_viewport().set_input_as_handled()
		return
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) >= 0.6):
		InputManager.replace_action(InputManager.action_to_remap, event)
		get_viewport().set_input_as_handled()
