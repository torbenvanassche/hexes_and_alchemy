class_name Toast
extends Control

class NotificationData extends RefCounted:
	var text := ""
	var accent_color := Color.TRANSPARENT
	var icon: Texture2D
	var icon_color := Color.WHITE

const REPORT_ICON := preload("res://sprites/ui/line/book.svg")
const REPORT_ICON_COLOR := GameUI.MUTED

@export var notification_scene: PackedScene
@export var display_time: float = 5.0
@export var transition_time: float = 0.2
@export_range(1, 8, 1) var max_visible_notifications: int = 3
@export_range(260, 560, 10) var notification_width := 380

@onready var notification_stack: VBoxContainer = $SafeMargin/Alignment/NotificationStack

var active_notifications: Array[ToastNotificationUI] = []
var pending_notifications: Array[NotificationData] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_update_stack_width)
	_update_stack_width()

func _update_stack_width() -> void:
	var margins := $SafeMargin as MarginContainer
	var available := get_viewport_rect().size.x - margins.get_theme_constant("margin_left") - margins.get_theme_constant("margin_right")
	notification_stack.custom_minimum_size.x = minf(notification_width, maxf(1.0, available))

func notify(text: String, accent_color: Color = Color.TRANSPARENT) -> void:
	_enqueue(text, accent_color)

func notify_report(text: String, accent_color: Color = Color.TRANSPARENT) -> void:
	_enqueue(text, accent_color, REPORT_ICON, REPORT_ICON_COLOR)

func notify_item_reward(item: ItemInfo, amount: int, accent_color: Color = Color.TRANSPARENT) -> void:
	if item == null:
		return
	var reward_text := "[b]+%d[/b] %s" % [amount, _safe(item.get_display_name())]
	_enqueue(reward_text, accent_color, item.texture)

func notify_rewards(title: String, rewards: Dictionary[ItemInfo, int]) -> void:
	var lines := PackedStringArray(["[b]%s[/b]" % _safe(title)])
	for item: ItemInfo in rewards:
		if item != null and rewards[item] > 0:
			lines.append("%s [b]+%d[/b] %s" % [_inline_icon(item.texture), rewards[item], _safe(item.get_display_name())])
	if lines.size() > 1: _enqueue("\n".join(lines), GameUI.SUCCESS, REPORT_ICON)

func notify_crafted_item(item: ItemInfo) -> void:
	if item != null:
		_enqueue(tr("NOTICE_CRAFTED") % _safe(item.get_display_name()), GameUI.SUCCESS, item.texture)

func notify_project_completed(definition: CommunityProjectDefinition) -> void:
	var text := "[b]%s[/b]\n%s" % [_safe(tr("COMMUNITY_COMPLETED") % definition.get_title()), _safe(tr(definition.benefit_key))]
	text += "\n" + _inline_icon(preload("res://sprites/ui/line/lucide/reputation.svg")) + " +%d" % definition.reputation_reward
	for item: ItemInfo in definition.reward_items:
		text += "   " + _inline_icon(item.texture) + " +%d" % definition.reward_items[item]
	_enqueue(text, GameUI.SUCCESS, definition.blueprint.texture if definition.blueprint != null else REPORT_ICON)

func _safe(value: String) -> String:
	return value.replace("[", "[lb]")

func _inline_icon(texture: Texture2D) -> String:
	return "[img=20x20]%s[/img]" % texture.resource_path if texture != null else ""

func _enqueue(
	text: String,
	accent_color: Color,
	icon: Texture2D = null,
	icon_color: Color = Color.WHITE
) -> void:
	if text.strip_edges() == "":
		return
	var data := NotificationData.new()
	data.text = text
	data.accent_color = accent_color
	data.icon = icon
	data.icon_color = icon_color
	pending_notifications.append(data)
	if is_node_ready():
		_show_pending_notifications()
	else:
		call_deferred("_show_pending_notifications")

func _show_pending_notifications() -> void:
	if not is_node_ready() or notification_stack == null:
		return
	while active_notifications.size() < max_visible_notifications and not pending_notifications.is_empty():
		var data: NotificationData = pending_notifications.pop_front()
		if not _show_notification(data):
			pending_notifications.clear()
			return

func _show_notification(data: NotificationData) -> bool:
	if notification_scene == null:
		push_warning("Toast notification scene is not configured.")
		return false
	var toast_notification := notification_scene.instantiate() as ToastNotificationUI
	if toast_notification == null:
		push_warning("Toast notification scene root must be a ToastNotificationUI.")
		return false
	toast_notification.modulate.a = 0.0
	notification_stack.add_child(toast_notification)
	notification_stack.move_child(toast_notification, 0)
	toast_notification.setup(data.text, data.accent_color, data.icon, data.icon_color)
	active_notifications.push_front(toast_notification)
	_present_notification(toast_notification)
	return true

func _present_notification(toast_notification: ToastNotificationUI) -> void:
	await get_tree().process_frame
	if not is_instance_valid(toast_notification):
		return
	var tween_in := toast_notification.create_tween()
	tween_in.tween_property(toast_notification, "modulate:a", 1.0, transition_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween_in.finished
	if not is_instance_valid(toast_notification):
		return
	await get_tree().create_timer(display_time).timeout
	if not is_instance_valid(toast_notification):
		return
	var tween_out := toast_notification.create_tween()
	tween_out.tween_property(toast_notification, "modulate:a", 0.0, transition_time)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	await tween_out.finished
	if not is_instance_valid(toast_notification):
		return
	active_notifications.erase(toast_notification)
	notification_stack.remove_child(toast_notification)
	toast_notification.queue_free()
	_show_pending_notifications()
