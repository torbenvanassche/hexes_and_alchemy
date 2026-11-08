class_name ItemPreview
extends RefCounted

## Shared readonly inventory rendering for requirements, rewards and recipes.
const SCENE := preload("res://tools/inventory/scenes/content_slot.tscn")
const COMMISSION_SIZE := 56

static func create(item: ItemInfo = null, amount := 1, slot_size := COMMISSION_SIZE, scene: PackedScene = SCENE) -> ContentSlotUI:
	var slot := scene.instantiate() as ContentSlotUI
	slot.custom_minimum_size = Vector2(slot_size, slot_size)
	slot.can_drag = false
	if item != null:
		slot.set_content(ContentSlotResource.new(amount, item, maxi(1, amount), true, false))
	return slot
