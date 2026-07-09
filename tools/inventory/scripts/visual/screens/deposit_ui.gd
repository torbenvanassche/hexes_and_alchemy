class_name DepositUI
extends VBoxContainer

@onready var complete_order: Button = $"../complete_order"

var requirement_rows: Dictionary[Resource, Dictionary] = {}

@export var inventory: ContentGroup:
	set(value):
		if inventory and inventory.changed.is_connected(_on_inventory_changed):
			inventory.changed.disconnect(_on_inventory_changed)
		inventory = value
		if inventory and not inventory.changed.is_connected(_on_inventory_changed):
			inventory.changed.connect(_on_inventory_changed)
		_rebuild_requirements()

var source_inventory: ContentGroup:
	set(value):
		if source_inventory and source_inventory.changed.is_connected(_on_inventory_changed):
			source_inventory.changed.disconnect(_on_inventory_changed)
		source_inventory = value
		if source_inventory and not source_inventory.changed.is_connected(_on_inventory_changed):
			source_inventory.changed.connect(_on_inventory_changed)
		_on_inventory_changed()

signal supplies_deposited()

func _ready() -> void:
	_rebuild_requirements()
	if not complete_order.pressed.is_connected(_on_complete_order_pressed):
		complete_order.pressed.connect(_on_complete_order_pressed)

func on_enter() -> void:
	_refresh_deposit_state()
	
func _on_inventory_changed() -> void:
	_refresh_deposit_state()

func _rebuild_requirements() -> void:
	if not is_node_ready():
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	requirement_rows.clear()
	if inventory == null:
		_refresh_deposit_state()
		return
	for slot: ContentSlotResource in inventory.data:
		var item := slot.get_content()
		if item == null:
			continue
		var row := _create_requirement_row(item)
		add_child(row)
		var row_data: Dictionary[String, Object] = {
			"slot": slot,
			"count_label": row.get_node("CountLabel"),
		}
		requirement_rows[item] = row_data
	_refresh_deposit_state()

func _create_requirement_row(item: Resource) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "RequirementRow"
	row.custom_minimum_size = Vector2(340, 42)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.theme = theme
	row.add_theme_constant_override("separation", 8)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(38, 38)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item is ItemInfo:
		icon.texture = (item as ItemInfo).texture
	row.add_child(icon)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.custom_minimum_size = Vector2(200, 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text = _get_display_name(item)
	row.add_child(name_label)

	var count_label := Label.new()
	count_label.name = "CountLabel"
	count_label.custom_minimum_size = Vector2(64, 0)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(count_label)

	return row

func _refresh_deposit_state() -> void:
	if not is_node_ready():
		return
	var required := _get_required_resources()
	for item: Resource in requirement_rows.keys():
		var row_data: Dictionary[String, Object] = requirement_rows[item]
		var slot := row_data["slot"] as ContentSlotResource
		var count_label := row_data["count_label"] as Label
		var available := slot.count
		if source_inventory != null:
			available += source_inventory.get_count(item)
		var required_amount := slot.maxcount
		var has_requirement := available >= required_amount
		count_label.text = "x%s" % required_amount
		count_label.modulate = Color.WHITE if has_requirement else Color(1.0, 0.65, 0.65)
	complete_order.disabled = source_inventory == null or inventory == null or required.is_empty() or not source_inventory.has_all(required)

func _get_required_resources() -> Dictionary[Resource, int]:
	var required: Dictionary[Resource, int] = {}
	if inventory == null:
		return required
	for slot: ContentSlotResource in inventory.data:
		var content := slot.get_content()
		var amount := slot.maxcount - slot.count
		if content != null and amount > 0:
			required[content] = amount
	return required

func _on_complete_order_pressed() -> void:
	if source_inventory == null or inventory == null:
		return
	var required := _get_required_resources()
	if required.is_empty() or not source_inventory.has_all(required):
		_refresh_deposit_state()
		return
	for item: Resource in required.keys():
		var amount := int(required[item])
		source_inventory.remove(item, amount)
		inventory.add(item, amount, true)
	_refresh_deposit_state()
	supplies_deposited.emit()

func _get_display_name(item: Resource) -> String:
	if item == null:
		return ""
	if item.has_method("get_display_name"):
		return item.get_display_name()
	return str(item)
