class_name InventoryUI
extends Control

var elements: Array[Node] = []

@export var inventory: Inventory:
	set(value):
		inventory = value
		if not is_inside_tree():
			return
		_rebuild_inventory()

@export var packed_slot: PackedScene
@export var max_slot_size: int = 50

@onready var grid: GridContainer = $CenterContainer/GridContainer

var selected_slot: ContentSlotUI

func _rebuild_inventory() -> void:
	for element in grid.get_children():
		element.queue_free()
	elements.clear()

	if not inventory:
		return

	for content in inventory.data:
		var slot := add(content)
		elements.append(slot)

func add(content: ContentSlot) -> ContentSlotUI:
	var container: ContentSlotUI = packed_slot.instantiate()

	container.button_up.connect(_set_selected.bind(container))
	container.set_content(content)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size = Vector2(max_slot_size, max_slot_size)

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
