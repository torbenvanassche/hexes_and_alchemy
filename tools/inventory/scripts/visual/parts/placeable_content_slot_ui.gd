class_name PlaceableContentSlotUI extends ContentSlotUI

static var is_placing_placeable: bool = false;
const ROTATION_STEP := PI / 3.0;
const ROTATION_STEP_COUNT := 6;

var hovered_hex: HexBase;
var hovered_hex_can_drop: bool = false;
var placement_rotation_y: float = NAN;
var _preview_node: Node3D;
var _preview_placeable: PlaceableStructureInfo;
var _preview_hex: HexBase;
var _placement_rotation_axis_ready: bool = true;

func _on_drag_started() -> void:
	is_placing_placeable = _get_dragged_placeable() != null;

func _on_drag_finished() -> void:
	_clear_placeable_cursor();
	_clear_placement_preview();
	hovered_hex = null;
	hovered_hex_can_drop = false;
	placement_rotation_y = NAN;
	is_placing_placeable = false;

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

func _update_placement_rotation(placeable: PlaceableStructureInfo) -> void:
	if hovered_hex != _preview_hex:
		_preview_hex = hovered_hex;
		var placement_rotation := placeable.get_placement_rotation_y(hovered_hex);
		if bool(placement_rotation.get("has_rotation", false)):
			placement_rotation_y = float(placement_rotation["rotation_y"]);
		else:
			placement_rotation_y = NAN;

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
	if placement_rotation_y != placement_rotation_y:
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
	if hovered_hex == null or not hovered_hex_can_drop:
		_clear_placement_preview();
		return;

	if _preview_node == null or _preview_placeable != placeable:
		_clear_placement_preview();
		if placeable.packed_scene == null:
			return;

		_preview_node = placeable.packed_scene.instantiate() as Node3D;
		_preview_placeable = placeable;
		if _preview_node == null:
			return;

		_preview_node.process_mode = Node.PROCESS_MODE_DISABLED;
		_disable_preview_collision(_preview_node);
		_apply_preview_modulate(_preview_node);

		var active_scene := SceneManager.get_active_scene();
		if active_scene != null and active_scene.node != null:
			active_scene.node.add_child(_preview_node);

	_preview_node.visible = true;
	_preview_node.global_position = hovered_hex.global_position;
	_preview_node.rotation.y = 0.0 if placement_rotation_y != placement_rotation_y else placement_rotation_y;

func _clear_placement_preview() -> void:
	_preview_placeable = null;
	_preview_hex = null;
	if _preview_node != null and is_instance_valid(_preview_node):
		_preview_node.queue_free();
	_preview_node = null;

func _apply_preview_modulate(root: Node) -> void:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		mesh.transparency = 0.35;

func _disable_preview_collision(root: Node) -> void:
	for area: Area3D in root.find_children("*", "Area3D", true, false):
		area.monitoring = false;
		area.monitorable = false;
		area.collision_layer = 0;
		area.collision_mask = 0;
	for body: CollisionObject3D in root.find_children("*", "CollisionObject3D", true, false):
		body.collision_layer = 0;
		body.collision_mask = 0;
	for shape: CollisionShape3D in root.find_children("*", "CollisionShape3D", true, false):
		shape.disabled = true;
