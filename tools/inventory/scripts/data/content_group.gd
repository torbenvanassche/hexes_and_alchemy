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
	_prepare_slot(slot);
	data.append(slot);
	return slot;

func _prepare_slot(slot: ContentSlotResource) -> void:
	if not slot.full.is_connected(_on_slot_full):
		slot.full.connect(_on_slot_full)
	if not slot.changed.is_connected(changed.emit):
		slot.changed.connect(changed.emit)
	
func _on_slot_full() -> void:
	if is_full():
		full.emit();
	
func add(content: Resource, amount: int = 1, can_exceed_capacity: bool = false) -> int:
	if content == null:
		push_warning("Trying to add a null object to the inventory!")
		return maxi(0, amount)
	if amount <= 0:
		return 0
	
	var remaining_amount: int = amount;
	while remaining_amount > 0:
		var slots: Array[ContentSlotResource] = get_available_slots(content, true);
		if slots.size() == 0:
			if can_exceed_capacity:
				var created_slot := create_or_unlock_slot()
				if created_slot == null:
					break
				continue;
			break;
		var previous_remaining := remaining_amount
		remaining_amount = slots[0].add(remaining_amount, content);
		if remaining_amount >= previous_remaining:
			break
	changed.emit();
	if is_full():
		full.emit();
	return remaining_amount;

func remove(content: Resource, amount: int = 1) -> int:
	if content == null or amount <= 0:
		return maxi(0, amount)
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

func transfer_to(
	destination: ContentGroup,
	content: Resource,
	amount: int,
	destination_can_exceed_capacity: bool = false
) -> bool:
	if content == null or amount < 0:
		return false
	if amount == 0:
		return true
	return transfer_all_to(destination, {content: amount}, destination_can_exceed_capacity)

func transfer_all_to(
	destination: ContentGroup,
	amounts: Dictionary,
	destination_can_exceed_capacity: bool = false
) -> bool:
	if destination == null or destination == self:
		return destination == self
	if not has_all(amounts):
		return false

	var moved: Dictionary = {}
	for content: Resource in amounts.keys():
		var amount := maxi(0, int(amounts[content]))
		if amount == 0:
			continue
		if remove(content, amount) != 0:
			_rollback_transfer(destination, moved)
			return false
		var remainder := destination.add(content, amount, destination_can_exceed_capacity)
		var accepted := amount - remainder
		if accepted > 0:
			moved[content] = int(moved.get(content, 0)) + accepted
		if remainder > 0:
			add(content, remainder, true)
			_rollback_transfer(destination, moved)
			return false
	return true

func _rollback_transfer(destination: ContentGroup, moved: Dictionary) -> void:
	for content: Resource in moved.keys():
		var amount := int(moved[content])
		if amount <= 0:
			continue
		var not_removed := destination.remove(content, amount)
		add(content, amount - not_removed, true)
