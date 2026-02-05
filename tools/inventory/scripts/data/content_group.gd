class_name ContentGroup extends Node

var data: Array[ContentSlot] = [];

@export var stack_size: int = 1;

signal changed();
		
func get_available_slots(content: Resource, exclude_full: bool = false) -> Array[ContentSlot]:
	return data.filter(func(slot: ContentSlot) -> bool: 
		return slot.is_unlocked && slot.match_or_empty(content) && (!exclude_full || !slot.is_full()))
	
func create_or_unlock_slot() -> ContentSlot:
	for slot in data:
		if !slot.is_unlocked:
			slot.unlock();
			return slot;
	var new_slot: ContentSlot = ContentSlot.new(0, null, stack_size, true);
	data.append(new_slot);
	return new_slot;
	
func add(content: Resource, amount: int = 1, can_exceed_capacity: bool = false) -> int:
	if content == null:
		Debug.message("Trying to add a null object to the inventory!");
	
	var remaining_amount: int = amount;
	var call_amount: int = data.size();
	while remaining_amount > 0 && call_amount > 0:
		var slots: Array[ContentSlot] = get_available_slots(content, true);
		if slots.size() == 0:
			if can_exceed_capacity:
				create_or_unlock_slot()
				continue;
			break;
		remaining_amount = slots[0].add(remaining_amount, content);
		call_amount -= 1;
	changed.emit();
	return remaining_amount;

func remove(content: Resource, amount: int = 1) -> int:
	var remaining_amount: int = amount;
	while remaining_amount > 0:
		var slots: Array[ContentSlot] = get_available_slots(content);
		if slots.size() == 0:
			break;
		remaining_amount = slots[0].remove(remaining_amount);
	changed.emit();
	return remaining_amount;
