class_name PlaceableContentSlotUI extends ContentSlotUI

static var is_placing_placeable: bool = false;
const ROTATION_STEP := PI / 3.0;
const ROTATION_STEP_COUNT := 6;

var hovered_hex: HexBase;
var hovered_hex_can_drop: bool = false;
var placement_rotation_y: float = NAN;
var preview := StructurePlacementPreview.new();

var _preview_hex: HexBase;
var _placement_rotation_axis_ready: bool = true;
var _inventory_drop_completed: bool = false;

func _on_drag_started() -> void:
	_inventory_drop_completed = false;
	is_placing_placeable = _get_dragged_placeable() != null;

func _on_drag_finished() -> void:
	_clear_placeable_cursor();
	_clear_placement_preview();
	hovered_hex = null;
	hovered_hex_can_drop = false;
	placement_rotation_y = NAN;
	is_placing_placeable = false;

func _on_inventory_drop_completed(_destination_slot: ContentSlotUI) -> void:
	_inventory_drop_completed = true;
	_on_drag_finished();

func _should_process_drag() -> bool:
	return is_placing_placeable;

func _process_drag(_delta: float) -> void:
	var placeable := _get_dragged_placeable();
	if placeable == null:
		hovered_hex = null;
		hovered_hex_can_drop = false;
		_clear_placeable_cursor();
		_clear_placement_preview();
		return;

	hovered_hex = _get_hovered_hex();
	_update_placement_rotation(placeable);
	hovered_hex_can_drop = placeable.can_place_on(hovered_hex, _get_player_inventory(), placement_rotation_y);
	_update_placement_preview(placeable);
	Input.set_default_cursor_shape(
		Input.CURSOR_CAN_DROP if hovered_hex_can_drop else Input.CURSOR_FORBIDDEN
	);

func _handle_unsuccessful_drag_end() -> bool:
	if _inventory_drop_completed:
		return false;
	var placeable := _get_dragged_placeable();
	if placeable == null:
		return false;
	if not hovered_hex_can_drop:
		return false;
	return placeable.place_on(hovered_hex, _get_player_inventory(), placement_rotation_y);

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

func _get_player_inventory() -> ContentGroup:
	if Manager.instance == null:
		return null
	if Manager.instance.hub != null and Manager.instance.hub.stockpile != null:
		return Manager.instance.hub.stockpile
	if Manager.instance.player_instance == null:
		return null
	return Manager.instance.player_instance.inventory

func _get_hovered_hex() -> HexBase:
	if Manager.instance == null or Manager.instance.player_instance == null:
		return null;
	return Manager.instance.player_instance.interactor_component.peek_hex_from_mouse();

func _clear_placeable_cursor() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW);

func _update_placement_rotation(placeable: PlaceableStructureInfo) -> void:
	if hovered_hex != _preview_hex:
		_preview_hex = hovered_hex;
		placement_rotation_y = placeable.get_placement_rotation_y(hovered_hex);

	if Input.is_action_just_pressed("camera_rotate_left"):
		_step_placement_rotation(placeable, 1.0);
		_placement_rotation_axis_ready = false;
	elif Input.is_action_just_pressed("camera_rotate_right"):
		_step_placement_rotation(placeable, -1.0);
		_placement_rotation_axis_ready = false;
	else:
		var rotation_input := Input.get_action_strength("camera_rotate_left") - Input.get_action_strength("camera_rotate_right");
		if absf(rotation_input) < 0.2:
			_placement_rotation_axis_ready = true;
		elif _placement_rotation_axis_ready:
			_step_placement_rotation(placeable, signf(rotation_input));
			_placement_rotation_axis_ready = false;

func _step_placement_rotation(placeable: PlaceableStructureInfo, direction: float) -> void:
	if hovered_hex == null:
		return

	if absf(direction) < 0.001:
		return
	if is_nan(placement_rotation_y):
		return

	var step_direction := signf(direction)
	var inventory := _get_player_inventory()
	var starting_rotation := placement_rotation_y
	for step_index in range(1, ROTATION_STEP_COUNT + 1):
		var candidate_rotation := wrapf(
			starting_rotation + ROTATION_STEP * step_direction * float(step_index),
			-PI,
			PI
		)
		if placeable.can_place_on(hovered_hex, inventory, candidate_rotation):
			placement_rotation_y = candidate_rotation
			return

func _update_placement_preview(placeable: PlaceableStructureInfo) -> void:
	preview.update(placeable, hovered_hex, hovered_hex_can_drop, placement_rotation_y)

func _clear_placement_preview() -> void:
	preview.clear()
	_preview_hex = null

func _gui_input(event: InputEvent) -> void:
	if not can_drag or contentSlot == null: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var placeable := _get_dragged_placeable()
		if placeable == null: return
		accept_event()
		var menu := ContextMenu.new([ContextMenuItem.new("PLACEMENT_PLACE", func() -> void: WorldPlacement.begin(placeable, _get_player_inventory(), contentSlot))])
		add_child(menu)
		menu.open(get_global_mouse_position())
