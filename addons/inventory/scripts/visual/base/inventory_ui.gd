class_name InventoryUI
extends GridContainer

var elements: Array[Node];

@export var inventory: Inventory:
	set(value):
		inventory = value;
		if value:
			for element in elements:
				element.queue_free()
			for element in inventory.data:
				add(element)
			elements.assign(self.get_children())
			_control_size();
@export var packed_slot: PackedScene
@export var max_slot_size: int = 50;

var selected_slot: ContentSlotUI

func _ready() -> void:
	resized.connect(_control_size, CONNECT_DEFERRED)

func _control_size() -> void:
	var container_width := size.x
	var h_separation := get_theme_constant("h_separation")

	var container_size_x: int = clamp((container_width / columns) - h_separation, 15, max_slot_size)

	for e: Control in get_children():
		e.custom_minimum_size.x = container_size_x
		e.custom_minimum_size.y = container_size_x

func add(content: ContentSlot) -> ContentSlotUI:
	var container: ContentSlotUI = packed_slot.instantiate() as ContentSlotUI
	container.button_up.connect(_set_selected.bind(container))
	container.set_content(content)
	add_child(container)
	return container

func _set_selected(slot: ContentSlotUI) -> void:
	if !slot or (selected_slot != slot and selected_slot):
		selected_slot.button_pressed = false
		selected_slot = null

	var redraw: bool = selected_slot == slot
	if redraw or slot:
		slot.button_pressed = false
		selected_slot = null
	else:
		selected_slot = slot
