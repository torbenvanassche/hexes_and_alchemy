class_name EquipmentSlotUI
extends PlaceableContentSlotUI

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not super._can_drop_data(at_position, data):
		return false
	var drag_data := data as DragData
	if drag_data == null or drag_data.slot == null or drag_data.slot.contentSlot == null:
		return false
	return drag_data.slot.contentSlot.get_content() is EquipmentInfo

func _get_dragged_placeable() -> PlaceableStructureInfo:
	return null
