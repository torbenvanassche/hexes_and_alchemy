class_name Toast
extends Control

const REPORT_ICON := preload("res://sprites/ui/icons/notepad_write.png")
const REPORT_ICON_COLOR := Color(0.35, 0.24, 0.14, 1)

@export var notification_scene: PackedScene
@export var display_time: float = 5.0
@export var transition_time: float = 0.2
@export_range(1, 8, 1) var max_visible_notifications: int = 4

@onready var notification_stack: VBoxContainer = $SafeMargin/Alignment/NotificationStack

var active_notifications: Array[ToastNotificationUI] = []
var pending_notifications: Array[Dictionary] = []

func notify(text: String, accent_color: Color = Color.TRANSPARENT) -> void:
	_enqueue(text, accent_color)

func notify_report(text: String, accent_color: Color = Color.TRANSPARENT) -> void:
	_enqueue(text, accent_color, REPORT_ICON, REPORT_ICON_COLOR)

func notify_item_reward(item: ItemInfo, amount: int, accent_color: Color = Color.TRANSPARENT) -> void:
	if item == null:
		return
	var reward_text := tr("QUEST_REWARD_ITEM_GAINED") % [amount, item.get_display_name()]
	_enqueue(reward_text, accent_color, item.texture)

func _enqueue(
	text: String,
	accent_color: Color,
	icon: Texture2D = null,
	icon_color: Color = Color.WHITE
) -> void:
	if text.strip_edges() == "":
		return
	pending_notifications.append({
		"text": text,
		"accent_color": accent_color,
		"icon": icon,
		"icon_color": icon_color,
	})
	if is_node_ready():
		_show_pending_notifications()
	else:
		call_deferred("_show_pending_notifications")

func _show_pending_notifications() -> void:
	if not is_node_ready() or notification_stack == null:
		return
	while active_notifications.size() < max_visible_notifications and not pending_notifications.is_empty():
		var data: Dictionary = pending_notifications.pop_front()
		if not _show_notification(data):
			pending_notifications.clear()
			return

func _show_notification(data: Dictionary) -> bool:
	if notification_scene == null:
		push_warning("Toast notification scene is not configured.")
		return false
	var toast_notification := notification_scene.instantiate() as ToastNotificationUI
	if toast_notification == null:
		push_warning("Toast notification scene root must be a ToastNotificationUI.")
		return false
	toast_notification.modulate.a = 0.0
	toast_notification.scale = Vector2(0.98, 0.98)
	notification_stack.add_child(toast_notification)
	var accent_color: Color = data.get("accent_color", Color.TRANSPARENT)
	var icon := data.get("icon") as Texture2D
	var icon_color: Color = data.get("icon_color", Color.WHITE)
	toast_notification.setup(str(data.get("text", "")), accent_color, icon, icon_color)
	active_notifications.append(toast_notification)
	_present_notification(toast_notification)
	return true

func _present_notification(toast_notification: ToastNotificationUI) -> void:
	await get_tree().process_frame
	if not is_instance_valid(toast_notification):
		return
	toast_notification.pivot_offset = toast_notification.size * 0.5
	var tween_in := create_tween().set_parallel(true)
	tween_in.tween_property(toast_notification, "modulate:a", 1.0, transition_time)
	tween_in.tween_property(toast_notification, "scale", Vector2.ONE, transition_time)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	await tween_in.finished
	if not is_instance_valid(toast_notification):
		return
	await get_tree().create_timer(display_time).timeout
	if not is_instance_valid(toast_notification):
		return
	var tween_out := create_tween()
	tween_out.tween_property(toast_notification, "modulate:a", 0.0, transition_time)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	await tween_out.finished
	if not is_instance_valid(toast_notification):
		return
	active_notifications.erase(toast_notification)
	toast_notification.queue_free()
	_show_pending_notifications()
