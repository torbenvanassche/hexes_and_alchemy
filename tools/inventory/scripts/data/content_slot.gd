class_name ContentSlotResource extends Resource

var _content: Resource;

@export var content: Resource:
	set(value):
		set_content(value);
	get:
		return _content;

@export var count: int = 0;
@export var maxcount: int = 0;
@export var is_unlocked: bool = false;
@export var clear_on_empty: bool = true;

signal full();

func _init(_count: int = 0, slot_content: Resource = null, _maxcount: int = 1, _unlocked: bool = true, _clear_on_empty: bool = true) -> void:
	is_unlocked = _unlocked;
	clear_on_empty = _clear_on_empty;
	maxcount = _maxcount;
	set_content(slot_content);
	count = _count;
	
func set_content(slot_content: Resource) -> void:
	_content = slot_content;
	changed.emit();
	
func get_content() -> Resource:
	return _content;
	
func set_stack_size(max_size: int = 1) -> void:
	maxcount = max_size;
	
func can_add(slot_content: Resource) -> bool:
	return (_content == null or _content == slot_content) and not is_full();

func add(amount: int = 1, slot_content: Resource = null) -> int:
	if _content == null && slot_content != null:
		_content = slot_content;
	
	if slot_content != null && _content != slot_content:
		return amount;
		
	var remaining_space: int = maxcount - count;
	var amount_to_add: int = min(amount, remaining_space);
	count += amount_to_add;
	changed.emit();
	if is_full():
		full.emit();
	return amount - amount_to_add;
	
func remove(amount: int = 1) -> int:
	var amount_to_remove: int = min(amount, count);
	count -= amount_to_remove;
	if count == 0:
		reset()
	changed.emit();
	return amount - amount_to_remove
	
func match_or_empty(element: Resource) -> bool:
	return has_content(element) || has_content(null);
	
func has_content(element: Resource) -> bool: 
	return _content == element
	
func is_full() -> bool:
	return count >= maxcount;

func reset() -> void:
	if clear_on_empty:
		_content = null;
		count = 0;
