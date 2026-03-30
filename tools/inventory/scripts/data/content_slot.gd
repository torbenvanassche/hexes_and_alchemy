class_name ContentSlotResource extends Resource

var _content: ItemInfo;
var count: int = 0;
var maxcount: int = 0;
var is_unlocked: bool = false;
var clear_on_empty: bool = true;

signal full();

func _init(_count: int = 0, content: ItemInfo = null, _maxcount: int = 1, _unlocked: bool = true, _clear_on_empty: bool = true) -> void:
	is_unlocked = _unlocked;
	clear_on_empty = _clear_on_empty;
	maxcount = _maxcount;
	set_content(content);
	count = _count;
	
func set_content(content: ItemInfo) -> void:
	_content = content;
	changed.emit();
	
func get_content() -> ItemInfo:
	return _content;
	
func set_stack_size(max_size: int = 1) -> void:
	maxcount = max_size;
	
func can_add(content: ItemInfo) -> bool:
	return content != _content && !is_full();

func add(amount: int = 1, content: ItemInfo = null) -> int:
	if _content == null && content != null:
		_content = content;
	
	if content != null && _content != content:
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
	
func match_or_empty(element: ItemInfo) -> bool:
	return has_content(element) || has_content(null);
	
func has_content(element: ItemInfo) -> bool: 
	return _content == element
	
func is_full() -> bool:
	return count >= maxcount;

func reset() -> void:
	if clear_on_empty:
		_content = null;
		count = 0;
