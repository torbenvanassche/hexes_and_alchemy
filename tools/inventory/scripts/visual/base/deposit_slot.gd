extends ContentSlotUI

func redraw() -> void:
	super.redraw();
	counter.text = "%s/%s" % [contentSlot.count, contentSlot._maxcount]
