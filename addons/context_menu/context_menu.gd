class_name ContextMenu
extends PopupMenu

var menu_items: Array[ContextMenuItem]
var item_size: Vector2 = Vector2(100, 24);

func _init(data: Array[ContextMenuItem] = []) -> void:
	for item in data:
		add(item)

func _ready() -> void:
	close_requested.connect(_on_close)
	index_pressed.connect(_on_idx)

func add(cmi: ContextMenuItem) -> void:
	menu_items.append(cmi)
	var idx: int = menu_items.size() - 1;
	cmi.idx = idx;
	
	if cmi.submenu == null: 
		add_item(cmi.id, cmi.idx);
		set_item_disabled(cmi.idx, !cmi.enabled)
	else:
		add_submenu_node_item(cmi.id, cmi.submenu, cmi.idx)

func _on_idx(index: int) -> void:
	var found_item: Array[ContextMenuItem] = menu_items.filter(func(x: ContextMenuItem) -> bool: return x.idx == index)
	for item in found_item:
		if item.function.is_valid():
			item.function.call()
	close_requested.emit();

func _on_close() -> void:
	queue_free()

func open(vec2: Vector2) -> void:
	popup(Rect2(vec2, Vector2(item_size.x, item_size.y * menu_items.size())))
