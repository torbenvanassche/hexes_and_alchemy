class_name ItemRequest extends ContentSlotResource

signal completed();

func _init(_count: int = 0, content: ItemInfo = null, maxcount: int = 1, _unlocked: bool = true) -> void:
	super(_count, content, maxcount);
	value_changed.connect(_on_changed)
		
func _on_changed() -> void:
	if is_full():
		completed.emit();
