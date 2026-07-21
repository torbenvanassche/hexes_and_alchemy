class_name Toast
extends Control

@export var notification_scene: PackedScene
@export var display_time: float = 2.5
@export var slide_time: float = 0.25
@export var edge_padding: float = 10.0
@export var stack_spacing: float = 8.0
@export var content_padding: Vector2 = Vector2(16.0, 10.0)
@export var item_icon_size: Vector2i = Vector2i(24, 24)
@export var minimum_notification_width: float = 120.0
@export var maximum_notification_width: float = 360.0

var target_position: Vector2
var active_notifications: Array[RichTextLabel] = []

func _ready() -> void:
	target_position = position
	visible = false

func notify(txt: String, c: Color = Color.TRANSPARENT) -> void:
	var toast_label := _create_toast_label(txt, c)
	if toast_label != null:
		_show_toast(toast_label)

func notify_item_reward(item: ItemInfo, amount: int, c: Color = Color.TRANSPARENT) -> void:
	if item == null:
		return
	var reward_text := tr("QUEST_REWARD_ITEM_GAINED") % [amount, item.get_display_name()]
	var icon_path := _get_item_icon_path(item)
	var message := reward_text
	if icon_path != "":
		message = "[img=%sx%s]%s[/img] %s" % [
			item_icon_size.x,
			item_icon_size.y,
			icon_path,
			message,
		]
	var toast_label := _create_toast_label(message, c)
	if toast_label != null:
		_show_toast(toast_label)

func _show_toast(toast_label: RichTextLabel) -> void:
	active_notifications.append(toast_label)

	await get_tree().process_frame
	_fit_toast_to_content(toast_label)

	toast_label.position = _get_toast_offscreen_position(toast_label)
	toast_label.visible = true

	var tween := get_tree().create_tween()
	tween.tween_property(toast_label, "position", _get_toast_target_position(toast_label), slide_time)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(display_time).timeout

	var tween_out := get_tree().create_tween()
	tween_out.tween_property(toast_label, "position", _get_toast_offscreen_position(toast_label), slide_time)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_IN)

	tween_out.tween_callback(func() -> void:
		active_notifications.erase(toast_label)
		toast_label.queue_free()
		_layout_toasts()
	)

func _create_toast_label(txt: String, c: Color) -> RichTextLabel:
	if notification_scene == null:
		Debug.warn("Toast notification scene is not configured.")
		return null

	var toast_label := notification_scene.instantiate() as RichTextLabel
	if toast_label == null:
		Debug.warn("Toast notification scene root must be a RichTextLabel.")
		return null

	toast_label.text = txt
	toast_label.visible = false
	toast_label.position = target_position
	if c != Color.TRANSPARENT:
		toast_label.add_theme_color_override("default_color", c)
	get_parent().add_child(toast_label)
	return toast_label

func _fit_toast_to_content(toast_label: RichTextLabel) -> void:
	var width := clampf(
		toast_label.get_content_width() + content_padding.x * 2.0,
		minimum_notification_width,
		maximum_notification_width
	)
	toast_label.size = Vector2(width, toast_label.get_content_height() + content_padding.y * 2.0)

func _layout_toasts() -> void:
	for toast_label in active_notifications:
		if not is_instance_valid(toast_label):
			continue
		var tween := get_tree().create_tween()
		tween.tween_property(toast_label, "position", _get_toast_target_position(toast_label), slide_time)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)

func _get_item_icon_path(item: ItemInfo) -> String:
	if item.texture == null:
		return ""
	return item.texture.resource_path

func _get_toast_target_position(toast_label: Control) -> Vector2:
	var stack_offset := 0.0
	for active_toast in active_notifications:
		if active_toast == toast_label:
			break
		stack_offset += active_toast.size.y + stack_spacing
	return Vector2(_get_viewport_width() - toast_label.size.x - edge_padding, target_position.y + stack_offset)

func _get_toast_offscreen_position(toast_label: Control) -> Vector2:
	var target := _get_toast_target_position(toast_label)
	return Vector2(_get_viewport_width() + edge_padding, target.y)

func _get_viewport_width() -> float:
	return get_viewport_rect().size.x
