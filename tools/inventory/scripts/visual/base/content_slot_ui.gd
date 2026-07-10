class_name ContentSlotUI extends TextureButton

@onready var textureRect: TextureRect = $margin_container/background/MarginContainer/item_sprite;
@onready var textureMargin: MarginContainer = $margin_container/background/MarginContainer;
@onready var mainMarginContainer: MarginContainer = $margin_container;
@onready var counter: Label = $margin_container/MarginContainer/count;

@export_group("Properties")
@export var show_amount: bool = true:
	set(value):
		show_amount = value
		if is_node_ready():
			counter.visible = value;
@export var main_margin_size: int = 2;

@export_group("Drag Settings")
@export var default_color: Color = Color.WHITE;
@export var dragging_color: Color = Color(Color.WHITE, 0.3)
@export var can_drag: bool = true:
	set(value):
		can_drag = value
		if is_node_ready():
			_update_mouse_filter()

var contentSlot: ContentSlotResource;
static var drag_data: DragData;
static var drag_origin: ContentSlotUI;

signal initialized();

func _ready() -> void:
	Helpers.apply_margin_uniform(mainMarginContainer, main_margin_size)
	
	counter.visible = show_amount;
	counter.text = "";
	_update_mouse_filter()
	set_process(false);
	
func redraw() -> void:
	if contentSlot == null:
		return;
		
	_update_mouse_filter()
	
	disabled = !contentSlot.is_unlocked;
	var resource := contentSlot.get_content()
	if resource is ItemInfo:
		if "texture" in resource:
			textureRect.texture = resource.texture;
			textureRect.modulate = default_color;
		tooltip_text = resource.get_display_name();
		counter.visible = show_amount;
		counter.text = tr("ITEM_COUNT_LABEL") % contentSlot.count;
	elif resource is PlaceableStructureInfo:
		var structure_info := resource as PlaceableStructureInfo;
		textureRect.texture = null;
		tooltip_text = structure_info.get_display_name();
		counter.visible = show_amount;
		counter.text = tr("ITEM_COUNT_LABEL") % contentSlot.count;
	else:
		textureRect.texture = null;
		tooltip_text = "";
		counter.text = "";

func blur() -> void:
	textureRect.modulate = dragging_color;
	counter.visible = false;
	
func set_content(_content: ContentSlotResource) -> void:
	if contentSlot && contentSlot.changed.is_connected(redraw):
		contentSlot.changed.disconnect(redraw);
	contentSlot = _content;
	contentSlot.changed.connect(redraw)
	
	if _content:
		if is_node_ready():
			initialized.emit();
			redraw();
		else:
			ready.connect(redraw, CONNECT_ONE_SHOT);

func _get_drag_data(_at_position: Vector2) -> DragData:
	if not can_drag:
		return null
	if !contentSlot.has_content(null) && contentSlot.count != 0:
		blur();
		
		var preview := TextureRect.new();
		preview.texture = self.textureRect.texture;
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.z_index = 100;
		preview.size = Vector2(50, 50);
		set_drag_preview(preview)
		
		drag_data = DragData.new(self);
		drag_origin = self;
		_on_drag_started();
		set_process(_should_process_drag());
		return drag_data;
	drag_data = null;
	drag_origin = null;
	return null;
	
func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	return can_drag and contentSlot != null and contentSlot.is_unlocked;

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var src_slot: ContentSlotResource = (data as DragData).slot.contentSlot
	var dest_slot: ContentSlotResource = contentSlot
	
	if dest_slot.has_content(null) or dest_slot.has_content(src_slot.get_content()):
		src_slot.remove(src_slot.count - dest_slot.add(src_slot.count, src_slot.get_content()))
	else:
		var dest_content: Resource = dest_slot.get_content();
		var dest_count := dest_slot.count;
		var src_count := src_slot.count;
		dest_slot.set_content(src_slot.get_content());
		dest_slot.count = src_count;
		src_slot.set_content(dest_content)
		src_slot.count = dest_count;
		dest_slot.changed.emit()
		src_slot.changed.emit()
		
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_END:
			var placed := false;
			if drag_origin == self:
				if !is_drag_successful():
					placed = _handle_unsuccessful_drag_end();
				_on_drag_finished();
				drag_data = null;
				drag_origin = null;
				set_process(false);
			if !is_drag_successful() && !placed:
				redraw()

func _process(_delta: float) -> void:
	if drag_origin != self:
		set_process(false);
		return;

	_process_drag(_delta);
				
func _gui_input(_event: InputEvent) -> void:
	if not can_drag:
		return
	if _event is InputEventMouseButton and _event.is_pressed() and _event.button_index == MOUSE_BUTTON_RIGHT && !contentSlot.has_content(null):
		var mouse_position := get_global_mouse_position();
		var context := ContextMenu.new([
		])
		add_child(context);
		context.open(Vector2(mouse_position.x, mouse_position.y))

func _on_drag_started() -> void:
	pass;

func _on_drag_finished() -> void:
	pass;

func _should_process_drag() -> bool:
	return false;

func _process_drag(_delta: float) -> void:
	pass;

func _handle_unsuccessful_drag_end() -> bool:
	return false;

func _update_mouse_filter() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
