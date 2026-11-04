class_name InventoryUI
extends GridContainer

var elements: Array[Node] = []

@export var inventory: ContentGroup:
	set(value):
		inventory = value
		if not is_inside_tree():
			return
		_rebuild_inventory()

@export var packed_slot: PackedScene
@export var slot_size: int = 100
## Use available width for square slots; fixed-column inventories keep their existing layout.
@export var auto_fit_columns := false

var _fit_queued := false

@onready var grid: GridContainer = self

var selected_slot: ContentSlotUI

func _ready() -> void:
	if auto_fit_columns:
		resized.connect(_queue_fit)
		get_parent_control().resized.connect(_queue_fit)
		if get_parent() is ScrollContainer:
			(get_parent() as ScrollContainer).get_v_scroll_bar().visibility_changed.connect(_queue_fit)
	_rebuild_inventory()

func _rebuild_inventory() -> void:
	selected_slot = null
	for element in grid.get_children():
		grid.remove_child(element)
		element.queue_free()
	elements.clear()

	if not inventory:
		return

	for content in inventory.data:
		var slot := add(content)
		elements.append(slot)
	_queue_fit()

func _queue_fit() -> void:
	if not auto_fit_columns or _fit_queued:
		return
	_fit_queued = true
	_fit_grid.call_deferred()

func _fit_grid() -> void:
	_fit_queued = false
	var available := get_parent_control().size.x
	if get_parent() is ScrollContainer:
		var scroll := get_parent() as ScrollContainer
		var bar := scroll.get_v_scroll_bar()
		if bar.visible:
			available -= bar.size.x + scroll.get_theme_constant("scrollbar_h_separation")
	var gap := get_theme_constant("h_separation")
	columns = maxi(1, floori((available + gap) / (slot_size + gap)))
	var side := maxf(slot_size, floorf((available - gap * (columns - 1)) / columns))
	for element: Control in elements:
		element.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		element.custom_minimum_size = Vector2(slot_size, side)

func add(content: ContentSlotResource) -> ContentSlotUI:
	var container: ContentSlotUI = packed_slot.instantiate()

	container.button_up.connect(_set_selected.bind(container))
	container.set_content(content)

	container.size_flags_horizontal = Control.SIZE_FILL
	container.size_flags_vertical = Control.SIZE_FILL
	container.custom_minimum_size = Vector2(slot_size, slot_size)

	grid.add_child(container)
	return container

func _set_selected(slot: ContentSlotUI) -> void:
	if not slot:
		return

	if selected_slot and selected_slot != slot:
		selected_slot.button_pressed = false

	if selected_slot == slot:
		selected_slot.button_pressed = false
		selected_slot = null
		return

	selected_slot = slot
	selected_slot.button_pressed = true
