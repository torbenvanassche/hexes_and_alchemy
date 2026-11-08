extends Node

## Owns click placement independently of the inventory window. Stock is consumed
## by PlaceableStructureInfo only after a valid placement succeeds.
var structure: PlaceableStructureInfo
var inventory: ContentGroup
var source_slot: ContentSlotResource
var hovered_hex: HexBase
var rotation_y := NAN
var preview := StructurePlacementPreview.new()
var hidden_windows: Array[Control] = []
var _player: PlayerController
var _hint: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveGames.load_started.connect(func() -> void: finish(false))
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen)
	_hint = Label.new()
	screen.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -300
	_hint.offset_right = 300
	_hint.offset_top = -60
	_hint.offset_bottom = -24
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", GameUI.ACCENT)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.text = tr("PLACEMENT_HINT")
	_hint.hide()

func begin(info: PlaceableStructureInfo, stockpile: ContentGroup, slot: ContentSlotResource = null) -> bool:
	finish()
	if info == null or stockpile == null or not stockpile.has_all(info.build_cost) or not is_instance_valid(Manager.instance.player_instance): return false
	structure = info
	inventory = stockpile
	source_slot = slot
	_player = Manager.instance.player_instance
	for window: Node in get_tree().root.find_children("*", "Control", true, false):
		if window is DraggableControl and window.is_visible_in_tree():
			hidden_windows.append(window)
			window.hide()
	PlaceableContentSlotUI.is_placing_placeable = true
	_hint.show()
	return true

func finish(restore_windows := true) -> void:
	preview.clear()
	structure = null
	inventory = null
	source_slot = null
	hovered_hex = null
	rotation_y = NAN
	PlaceableContentSlotUI.is_placing_placeable = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	for window: Control in hidden_windows:
		if restore_windows and is_instance_valid(window): window.show()
	hidden_windows.clear()
	if is_instance_valid(_hint): _hint.hide()

func _process(_delta: float) -> void:
	if structure == null: return
	if not is_instance_valid(_player) or SaveGames.is_loading:
		finish(false)
		return
	if source_slot != null and (source_slot.count <= 0 or not structure.uses_content(source_slot.get_content())):
		finish()
		return
	var next := _player.interactor_component.peek_hex_from_mouse()
	if next != hovered_hex:
		hovered_hex = next
		rotation_y = structure.get_placement_rotation_y(hovered_hex) if hovered_hex != null else NAN
	var valid := structure.can_place_on(hovered_hex, inventory, rotation_y)
	preview.update(structure, hovered_hex, valid, rotation_y)
	Input.set_default_cursor_shape(Input.CURSOR_CAN_DROP if valid else Input.CURSOR_FORBIDDEN)

func _input(event: InputEvent) -> void:
	if structure == null: return
	if event.is_action_pressed("inventory") or event.is_action_pressed("journal"):
		get_viewport().set_input_as_handled()
		finish()
		return
	if event.is_action_pressed("cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		get_viewport().set_input_as_handled()
		finish()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		# Refresh the pick on click, so a fast move/click cannot use the previous tile.
		_process(0.0)
		try_place_at(hovered_hex)
	elif event.is_action_pressed("camera_rotate_left") or event.is_action_pressed("camera_rotate_right"):
		if not is_nan(rotation_y): rotation_y += PI / 3.0 * (1.0 if event.is_action_pressed("camera_rotate_left") else -1.0)
		get_viewport().set_input_as_handled()

func try_place_at(hex: HexBase) -> bool:
	if structure == null or not structure.place_on(hex, inventory, rotation_y): return false
	finish()
	return true
