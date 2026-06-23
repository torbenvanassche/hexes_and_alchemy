class_name ContentGroup extends Node

@export var data: Array[ContentSlotResource] = [];

@export var stack_size: int = 1;

signal changed();
signal full();

func _init(_stack_size: int = stack_size) -> void:
	self.stack_size = _stack_size;

func get_available_slots(content: Resource, exclude_full: bool = false) -> Array[ContentSlotResource]:
	return data.filter(func(slot: ContentSlotResource) -> bool: 
		return slot.is_unlocked && slot.match_or_empty(content) && (!exclude_full || !slot.is_full()));
		
func is_full() -> bool:
	return data.all(func(slot: ContentSlotResource) -> bool: return slot.is_full());

func get_count(content: Resource) -> int:
	var total := 0;
	for slot in data:
		if slot.is_unlocked && slot.has_content(content):
			total += slot.count;
	return total;

func has_all(cost: Dictionary) -> bool:
	for content: Resource in cost.keys():
		if get_count(content) < int(cost[content]):
			return false;
	return true;
	
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
	if data.size() == 0 && can_exceed_capacity:
		create_or_unlock_slot()
	
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
		var slots: Array[ContentSlotResource] = data.filter(func(slot: ContentSlotResource) -> bool:
			return slot.is_unlocked && slot.has_content(content) && slot.count > 0
		)
		if slots.size() == 0:
			break;
		var previous_remaining := remaining_amount
		remaining_amount = slots[0].remove(remaining_amount)
		if remaining_amount == previous_remaining:
			break
	changed.emit();
	return remaining_amount;
