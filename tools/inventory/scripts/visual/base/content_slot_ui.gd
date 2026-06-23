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
@export var can_drag: bool = true;

var contentSlot: ContentSlotResource;
static var drag_data: DragData;
static var drag_origin: ContentSlotUI;
static var hovered_hex: HexBase;
static var hovered_hex_can_drop: bool = false;
static var last_debug_hover_hex: HexBase;
static var last_debug_reason: String = "";

signal initialized();

func _ready() -> void:
	Helpers.apply_margin_uniform(mainMarginContainer, main_margin_size)
	
	counter.visible = show_amount;
	counter.text = "";
	set_process(false);
	
func redraw() -> void:
	if contentSlot == null:
		return;
		
	mouse_filter = Control.MOUSE_FILTER_STOP if can_drag else Control.MOUSE_FILTER_IGNORE;
	
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
		set_process(true);
		_debug_drag_start();
		return drag_data;
	drag_data = null;
	drag_origin = null;
	_clear_hover_debug();
	return null;
	
func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	return contentSlot && contentSlot.is_unlocked;

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
					placed = _try_drop_placeable_on_hovered_hex();
				_clear_placeable_cursor();
				drag_data = null;
				drag_origin = null;
				_clear_hover_debug();
				set_process(false);
			if !is_drag_successful() && !placed:
				redraw()

func _process(_delta: float) -> void:
	if drag_origin != self:
		set_process(false);
		return;

	var placeable := _get_dragged_placeable();
	if placeable == null:
		_clear_hover_debug();
		_clear_placeable_cursor();
		return;

	hovered_hex = _get_hovered_hex();
	var placement_debug := placeable.get_placement_debug(hovered_hex, _get_player_inventory());
	hovered_hex_can_drop = bool(placement_debug.get("can_place", false));
	var debug_reason := str(placement_debug.get("reason", ""));
	_update_hover_debug(hovered_hex, hovered_hex_can_drop, debug_reason);
	Input.set_default_cursor_shape(
		Input.CURSOR_CAN_DROP if hovered_hex_can_drop else Input.CURSOR_FORBIDDEN
	);
				
func _gui_input(_event: InputEvent) -> void:
	if _event is InputEventMouseButton and _event.is_pressed() and _event.button_index == MOUSE_BUTTON_RIGHT && !contentSlot.has_content(null):
		var mouse_position := get_global_mouse_position();
		var context := ContextMenu.new([
		])
		add_child(context);
		context.open(Vector2(mouse_position.x, mouse_position.y))

func _try_drop_placeable_on_hovered_hex() -> bool:
	var placeable := _get_dragged_placeable();
	if placeable == null:
		return false;
	if not hovered_hex_can_drop:
		return false;
	return placeable.place_on(hovered_hex, _get_player_inventory());

func _get_dragged_placeable() -> PlaceableStructureInfo:
	if contentSlot == null:
		return null;

	var content := contentSlot.get_content();
	if content is PlaceableStructureInfo:
		return content as PlaceableStructureInfo;

	for structure: StructureInfo in DataManager.instance.structures:
		var placeable := structure as PlaceableStructureInfo;
		if placeable != null and placeable.uses_content(content):
			return placeable;
	return null;

func _debug_drag_start() -> void:
	var content := contentSlot.get_content() if contentSlot != null else null;
	var placeable := _get_dragged_placeable();
	if placeable != null:
		Debug.message("Drag started for placeable structure: %s" % placeable.id)
		return;

	var content_name := "empty";
	if content is ItemInfo:
		content_name = (content as ItemInfo).get_display_name();
	elif content is Resource:
		content_name = (content as Resource).resource_path;
	Debug.message("Drag started for %s, but no placeable structure uses this item." % content_name)

func _get_player_inventory() -> Inventory:
	if Manager.instance == null or Manager.instance.player_instance == null:
		return null;
	return Manager.instance.player_instance.inventory;

func _get_hovered_hex() -> HexBase:
	if Manager.instance == null or Manager.instance.player_instance == null:
		return null;
	return Manager.instance.player_instance.interactor_component.peek_hex_from_mouse();

func _clear_placeable_cursor() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW);

func _update_hover_debug(next_hovered_hex: HexBase, can_drop: bool, debug_reason: String) -> void:
	if last_debug_hover_hex != null and last_debug_hover_hex != next_hovered_hex:
		last_debug_hover_hex.clear_drop_debug_tint()

	if next_hovered_hex != null:
		next_hovered_hex.set_drop_debug_tint(can_drop)

	var hovered_changed := last_debug_hover_hex != next_hovered_hex
	var reason_changed := last_debug_reason != debug_reason
	if hovered_changed or reason_changed:
		var hovered_label := "none" if next_hovered_hex == null else str(next_hovered_hex.cube_id)
		Debug.message("Drop hover %s: %s" % [hovered_label, debug_reason])

	last_debug_hover_hex = next_hovered_hex
	last_debug_reason = debug_reason

func _clear_hover_debug() -> void:
	if last_debug_hover_hex != null:
		last_debug_hover_hex.clear_drop_debug_tint()
	last_debug_hover_hex = null
	last_debug_reason = ""
	hovered_hex = null
	hovered_hex_can_drop = false
