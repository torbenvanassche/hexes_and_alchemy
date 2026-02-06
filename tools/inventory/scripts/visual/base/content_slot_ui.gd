class_name ContentSlotUI extends TextureButton

@onready var textureRect: TextureRect = $margin_container/background/MarginContainer/item_sprite;
@onready var mainMarginContainer: MarginContainer = $margin_container;
@onready var counter: Label = $count;

@export_group("Properties")
@export var show_amount: bool = true;
@export var main_margin_size: Vector4i = Vector4(2, 2, 2, 2);

@export_group("Drag Settings")
@export var default_color: Color = Color.WHITE;
@export var dragging_color: Color = Color(Color.WHITE, 0.3)

var contentSlot: ContentSlot;

func _ready() -> void:	
	mainMarginContainer.add_theme_constant_override("margin_left", main_margin_size.x)
	mainMarginContainer.add_theme_constant_override("margin_top", main_margin_size.y)
	mainMarginContainer.add_theme_constant_override("margin_right", main_margin_size.z)
	mainMarginContainer.add_theme_constant_override("margin_bottom", main_margin_size.w)
	
	counter.visible = show_amount;
	counter.text = "";
	
	if contentSlot:
		redraw();
	
func redraw() -> void:
	if contentSlot == null:
		return;
	
	disabled = !contentSlot.is_unlocked;
	var resource := contentSlot.get_content()
	if resource is ItemInfo:
		if "texture" in resource:
			textureRect.texture = resource.texture;
			textureRect.modulate = default_color;
		counter.visible = show_amount;
		counter.text = str(contentSlot.count);
	else:
		textureRect.texture = null;
		counter.text = "";

func blur() -> void:
	textureRect.modulate = dragging_color;
	counter.visible = false;
	
func set_content(_content: ContentSlot) -> void:
	if contentSlot && contentSlot.changed.is_connected(redraw):
		contentSlot.changed.disconnect(redraw);
	contentSlot = _content;
	contentSlot.changed.connect(redraw)
	is_queued_for_deletion()
	
	if _content:
		if is_node_ready():
			redraw();
		else:
			ready.connect(redraw, CONNECT_ONE_SHOT);

func _get_drag_data(_at_position: Vector2) -> DragData:
	if !contentSlot.has_content(null):
		blur();
		
		var preview := TextureRect.new();
		preview.texture = self.textureRect.texture;
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.z_index = 100;
		preview.size = Vector2(50, 50);
		set_drag_preview(preview)
		
		return DragData.new(self);
	return null;
	
func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	return contentSlot && contentSlot.is_unlocked;

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var src_slot: ContentSlot = (data as DragData).slot.contentSlot
	var dest_slot: ContentSlot = contentSlot
	
	if dest_slot.has_content(null) or dest_slot.has_content(src_slot.get_content()):
		src_slot.remove(src_slot.count - dest_slot.add(src_slot.count, src_slot.get_content()))
	else:
		var dest_content: Resource = dest_slot.get_content();
		dest_slot.set_content(src_slot.get_content());
		src_slot.set_content(dest_content)
		
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_END:
			if !is_drag_successful():
				redraw()
				
func _gui_input(_event: InputEvent) -> void:
	if _event is InputEventMouseButton and _event.is_pressed() and _event.button_index == MOUSE_BUTTON_RIGHT && !contentSlot.has_content(null):
		var mouse_position := get_global_mouse_position();
		var context := ContextMenu.new([
			ContextMenuItem.new("Test", print.bind("test")),
			ContextMenuItem.new("Test2", print.bind("test2"))
		])
		add_child(context);
		context.open(Vector2(mouse_position.x, mouse_position.y))
