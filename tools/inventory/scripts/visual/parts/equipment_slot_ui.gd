class_name EquipmentSlotUI
extends PlaceableContentSlotUI

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not super._can_drop_data(at_position, data):
		return false
	var equipment_drag_data := data as DragData
	if equipment_drag_data == null or equipment_drag_data.slot == null or equipment_drag_data.slot.contentSlot == null:
		return false
	return equipment_drag_data.slot.contentSlot.get_content() is EquipmentInfo

func _get_dragged_placeable() -> PlaceableStructureInfo:
	return null
