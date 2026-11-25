class_name ActionPrompt extends HBoxContainer

@export var action := "ui_accept"
@export var label_key := "UI_CONFIRM"

func _ready() -> void:
	InputManager.input_mode_changed.connect(refresh)
	InputManager.bindings_changed.connect(refresh)
	refresh()

func refresh() -> void:
	var event := InputManager.get_keybind(action)
	var coords := InputManager.get_input_icon(action)
	var use_icon := event != null and coords.size() == 2 and (not InputManager.is_device(InputManager.InputDevice.CONTROLLER) or InputManager.controller_family() == "xbox")
	# Axis direction must remain visible even though the atlas only shows a stick.
	if event is InputEventJoypadMotion: use_icon = false
	$Icon.visible = use_icon
	$Binding.visible = not use_icon
	if use_icon:
		var texture := InputManager.get_input_texture()
		texture.region = InputManager.get_rect(Vector2i(coords[0], coords[1]))
		texture.filter_clip = true
		$Icon.texture = texture
	$Binding.text = InputManager.describe_event(event)
	if label_key == "UI_SCROLL" and event is InputEventJoypadMotion:
		$Binding.text = $Binding.text.trim_suffix(" ↓").trim_suffix(" ↑") + " ↕"
	$Text.text = tr(label_key)

func configure(next_action: String, next_label: String) -> void:
	if action == next_action and label_key == next_label: return
	action = next_action
	label_key = next_label
	if is_node_ready(): refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): refresh()
