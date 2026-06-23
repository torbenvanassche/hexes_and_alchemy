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

@onready var grid: GridContainer = self

var selected_slot: ContentSlotUI

func _ready() -> void:
	var craft_button := get_node_or_null("../../topbar/MarginContainer2/HBoxContainer/CraftButton") as Button
	if craft_button:
		craft_button.pressed.connect(_open_crafting_window)
	_rebuild_inventory()

func _rebuild_inventory() -> void:
	for element in grid.get_children():
		element.free()
	elements.clear()

	if not inventory:
		return

	for content in inventory.data:
		var slot := add(content)
		elements.append(slot)

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

func _open_crafting_window() -> void:
	var crafting_window := DataManager.instance.get_scene_by_name("crafting_ui")
	if crafting_window == null:
		return
	for instance in crafting_window.get_live_instances():
		if SceneManager.is_visible(instance):
			SceneManager.add(crafting_window, true)
			return
	crafting_window.queue(_show_crafting_window)

func _show_crafting_window(window_info: SceneInfo) -> void:
	var window_instance := SceneManager.add(window_info, false)
	var crafting_ui: CraftingUI = (window_instance.node as DraggableControl).content as CraftingUI
	crafting_ui.inventory = inventory
	window_instance.on_enter.emit()
