class_name MarketUI extends InventoryUI

func add(content: ContentSlotResource) -> ContentSlotUI:
	var market_slot: MarketSlotUI = packed_slot.instantiate();
	grid.add_child(market_slot)
	
	var container := market_slot.content_slot_ui;
	container.button_up.connect(_set_selected.bind(container))
	container.set_content(content)

	container.size_flags_horizontal = Control.SIZE_FILL
	container.size_flags_vertical = Control.SIZE_FILL
	container.custom_minimum_size = Vector2(slot_size, slot_size)
	return container
