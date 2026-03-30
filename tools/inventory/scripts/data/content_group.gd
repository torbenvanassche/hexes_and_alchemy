class_name ContentGroup extends Node

@export var data: Array[ContentSlotResource] = [];

@export var stack_size: int = 1;

signal changed();
signal full();
		
func get_available_slots(content: Resource, exclude_full: bool = false) -> Array[ContentSlotResource]:
	return data.filter(func(slot: ContentSlotResource) -> bool: 
		return slot.is_unlocked && slot.match_or_empty(content) && (!exclude_full || !slot.is_full()));
		
func is_full() -> bool:
	return data.all(func(slot: ContentSlotResource) -> bool: return slot.is_full());
	
func create_or_unlock_slot() -> ContentSlotResource:
	for slot in data:
		if !slot.is_unlocked:
			slot.unlock();
			return slot;
	return add_slot(ContentSlotResource.new(0, null, stack_size, true));
	
func add_slot(slot: ContentSlotResource) -> ContentSlotResource:
	slot.full.connect(_on_slot_full)
	slot.changed.connect(changed.emit)
	data.append(slot);
	return slot;
	
func _on_slot_full() -> void:
	if is_full():
		full.emit();
	
func add(content: Resource, amount: int = 1, can_exceed_capacity: bool = false) -> int:
	if content == null:
		Debug.message("Trying to add a null object to the inventory!");
	
	var remaining_amount: int = amount;
	var call_amount: int = data.size();
	while remaining_amount > 0 && call_amount > 0:
		var slots: Array[ContentSlotResource] = get_available_slots(content, true);
		if slots.size() == 0:
			if can_exceed_capacity:
				create_or_unlock_slot()
				continue;
			break;
		remaining_amount = slots[0].add(remaining_amount, content);
		call_amount -= 1;
	changed.emit();
	if is_full():
		full.emit();
	return remaining_amount;

func remove(content: Resource, amount: int = 1) -> int:
	var remaining_amount: int = amount;
	while remaining_amount > 0:
		var slots: Array[ContentSlotResource] = get_available_slots(content);
		if slots.size() == 0:
			break;
		remaining_amount = slots[0].remove(remaining_amount);
	changed.emit();
	return remaining_amount;
