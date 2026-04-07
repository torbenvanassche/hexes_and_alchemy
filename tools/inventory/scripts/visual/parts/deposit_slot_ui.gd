extends ContentSlotUI

func redraw() -> void:
	super.redraw();
	counter.text = "%s/%s" % [contentSlot.count, contentSlot.maxcount]

func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	return super(_at_position, _data) && _data.slot.contentSlot.get_content() == contentSlot.get_content();
