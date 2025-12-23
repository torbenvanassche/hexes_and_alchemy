class_name Inventory extends ContentGroup

@export var unlocked_slots: int = 1;
@export var max_slots: int = 1;

func _ready() -> void:
	for i in range(max_slots):
		data.append(ContentSlot.new(0, null, stack_size, i < unlocked_slots))
