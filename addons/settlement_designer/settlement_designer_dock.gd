@tool
extends VBoxContainer

const STRUCTURES_ROOT := "structures"
const WALLS_ROOT := "walls"
const ENTRANCES_ROOT := "entrances"
const FOOTPRINT_ROOT := "footprint"

const BUILDABLE_SCENE := "res://scenes/tops/buildable_structure.tscn"
const FOUNDATION_SCENE := "res://meshes/kay_fantasy_hexagon/buildings/neutral/building_stage_A.glb"
const FOUNDATION_SCRIPT := "res://tools/quest_system/scripts/fetch_objective.gd"
const DEFAULT_MATERIAL := "res://materials/kay_fantasy_default.tres"
const WALL_SCENE := "res://scenes/tops/fence_stone_straight.tscn"
const GATE_SCENE := "res://scenes/tops/fence_stone_straight_gate_collision.tscn"
const SETTLEMENT_SCRIPT := "res://scripts/hex_system/settlement.gd"
const SETTLEMENT_UPGRADE_LEVEL_2 := "res://resources/settlement_upgrades/settlement_level_2.tres"
const SETTLEMENT_UPGRADE_LEVEL_3 := "res://resources/settlement_upgrades/settlement_level_3.tres"

const PIECES: Array[Dictionary] = [
	{"label": "Blacksmith", "name": "blacksmith", "path": "res://scenes/tops/topper_blacksmith.tscn"},
	{"label": "Market", "name": "market", "path": "res://scenes/tops/topper_market.tscn"},
	{"label": "Tavern", "name": "tavern", "path": "res://scenes/tops/topper_tavern.tscn"},
	{"label": "Quest Board", "name": "questboard", "path": "res://scenes/tops/topper_questboard.tscn"},
	{"label": "Shipyard", "name": "shipyard", "path": "res://scenes/tops/topper_shipyard.tscn"},
	{"label": "Docks", "name": "docks", "path": "res://scenes/tops/topper_docks.tscn"},
	{"label": "Home", "name": "home", "path": "res://scenes/tops/house_simple.tscn"},
]

const QUESTS: Array[Dictionary] = [
	{"label": "None", "path": ""},
	{"label": "Build Blacksmith", "path": "res://tools/quest_system/resources/quests/build_blacksmith.tres"},
	{"label": "Build Shipyard", "path": "res://tools/quest_system/resources/quests/build_shipyard.tres"},
]

const HEX_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]
const HANDLE_PICK_RADIUS_PX: float = 18.0
const HANDLE_HEIGHT: float = 0.18
const EDITOR_SETTINGS_PREFIX := "hexes_and_alchemy/settlement_designer/"
const WALL_PLACEHOLDER_META := "settlement_wall_placeholder"
const WALL_HEX_Q_META := "settlement_wall_q"
const WALL_HEX_R_META := "settlement_wall_r"
const WALL_SIDE_META := "settlement_wall_side"
const WALL_REPLACEMENT_YAW_OFFSET: float = 90.0

var editor_plugin: EditorPlugin
var settlement_root: Node3D

var root_label: Label
var piece_options: OptionButton
var piece_name: LineEdit
var rotation_spin: SpinBox
var buildable_check: CheckBox
var quest_options: OptionButton
var required_level_spin: SpinBox
var inner_radius_spin: SpinBox
var spacing_spin: SpinBox
var pointy_top_check: CheckBox
var selected_hex_label: Label
var grid_source_label: Label
var status_label: Label
var worldspace_handle_root: Node3D
var worldspace_handle_nodes: Array[Node3D] = []
var worldspace_selected_hex: Node3D
var hovered_worldspace_handle: int = -1
var handle_material: StandardMaterial3D
var handle_hover_material: StandardMaterial3D
var footprint_material: StandardMaterial3D
var wall_placeholder_material: StandardMaterial3D

func _init() -> void:
	name = "Settlement Designer"
	custom_minimum_size = Vector2.ZERO
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_build_ui()

func _ready() -> void:
	call_deferred("_use_edited_scene_root_as_settlement")
	_restore_grid_settings()
	call_deferred("_load_grid_settings_from_scene_if_available")

func _build_ui() -> void:
	add_theme_constant_override("separation", 8)
	var title: Label = Label.new()
	title.text = "Settlement Designer"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)

	root_label = Label.new()
	root_label.text = "Editing: current scene root"
	root_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(root_label)

	var create_settlement: Button = Button.new()
	create_settlement.text = "Set Up Scene Root"
	create_settlement.pressed.connect(_create_settlement_root)
	add_child(create_settlement)

	add_child(_make_separator())
	add_child(_make_label("Grid"))

	var load_grid: Button = Button.new()
	load_grid.text = "Load Grid Settings"
	load_grid.pressed.connect(_load_grid_settings)
	add_child(load_grid)

	grid_source_label = Label.new()
	grid_source_label.text = "Grid: manual defaults"
	grid_source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(grid_source_label)

	inner_radius_spin = _make_spin("Inner radius", 0.1, 10.0, 1.0, 0.05)
	spacing_spin = _make_spin("Extra spacing", 0.0, 4.0, 0.25, 0.05)
	inner_radius_spin.value_changed.connect(_on_grid_setting_changed)
	spacing_spin.value_changed.connect(_on_grid_setting_changed)

	pointy_top_check = CheckBox.new()
	pointy_top_check.text = "Pointy top"
	pointy_top_check.button_pressed = false
	pointy_top_check.toggled.connect(_on_grid_orientation_changed)
	add_child(pointy_top_check)

	selected_hex_label = Label.new()
	selected_hex_label.text = "Selected footprint: none"
	selected_hex_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(selected_hex_label)

	var tabs: TabContainer = TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 260)
	tabs.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(tabs)

	var terrain_tab: VBoxContainer = VBoxContainer.new()
	terrain_tab.name = "Terrain"
	terrain_tab.add_theme_constant_override("separation", 8)
	tabs.add_child(terrain_tab)

	var structures_tab: VBoxContainer = VBoxContainer.new()
	structures_tab.name = "Structures"
	structures_tab.add_theme_constant_override("separation", 8)
	tabs.add_child(structures_tab)

	terrain_tab.add_child(_make_label("Footprint"))

	var build_boundary_walls: Button = Button.new()
	build_boundary_walls.text = "Add Boundary Walls"
	build_boundary_walls.pressed.connect(_add_boundary_walls)
	terrain_tab.add_child(build_boundary_walls)

	var replace_wall_placeholders: Button = Button.new()
	replace_wall_placeholders.text = "Replace Wall Placeholders"
	replace_wall_placeholders.pressed.connect(_replace_wall_placeholders)
	terrain_tab.add_child(replace_wall_placeholders)

	var remove_ground: Button = Button.new()
	remove_ground.text = "Remove Footprint Ground"
	remove_ground.pressed.connect(_remove_footprint_ground)
	terrain_tab.add_child(remove_ground)

	var save_without_ground: Button = Button.new()
	save_without_ground.text = "Save Without Footprint Ground"
	save_without_ground.pressed.connect(_save_without_footprint_ground)
	terrain_tab.add_child(save_without_ground)

	terrain_tab.add_child(_make_separator())
	terrain_tab.add_child(_make_label("Entrances"))

	var add_gate: Button = Button.new()
	add_gate.text = "Replace Selected Wall With Entrance"
	add_gate.pressed.connect(_add_entrance)
	terrain_tab.add_child(add_gate)

	structures_tab.add_child(_make_label("Piece"))

	piece_options = OptionButton.new()
	for piece: Dictionary in PIECES:
		piece_options.add_item(String(piece["label"]))
	piece_options.item_selected.connect(_on_piece_selected)
	structures_tab.add_child(piece_options)

	piece_name = LineEdit.new()
	piece_name.placeholder_text = "Node name"
	structures_tab.add_child(piece_name)
	_on_piece_selected(0)

	rotation_spin = _make_spin("Rotation", 0, 300, 0, 60)
	_move_last_children_to(rotation_spin, structures_tab, 2)

	buildable_check = CheckBox.new()
	buildable_check.text = "Wrap as buildable"
	buildable_check.toggled.connect(_on_buildable_toggled)
	structures_tab.add_child(buildable_check)

	quest_options = OptionButton.new()
	for quest: Dictionary in QUESTS:
		quest_options.add_item(String(quest["label"]))
	structures_tab.add_child(quest_options)

	required_level_spin = _make_spin("Required level", 1, 10, 1, 1)
	_move_last_children_to(required_level_spin, structures_tab, 2)
	_on_buildable_toggled(false)

	var add_piece: Button = Button.new()
	add_piece.text = "Add Piece"
	add_piece.pressed.connect(_add_piece)
	structures_tab.add_child(add_piece)

	structures_tab.add_child(_make_separator())
	structures_tab.add_child(_make_label("Selected Nodes"))

	var snap_selected: Button = Button.new()
	snap_selected.text = "Snap Selected to Hex"
	snap_selected.pressed.connect(_snap_selected_to_hex)
	structures_tab.add_child(snap_selected)

	var rotate_selected: Button = Button.new()
	rotate_selected.text = "Rotate Selected 60"
	rotate_selected.pressed.connect(_rotate_selected)
	structures_tab.add_child(rotate_selected)

	var parent_selected: Button = Button.new()
	parent_selected.text = "Move Selected to Structures"
	parent_selected.pressed.connect(_move_selected_to_structures)
	structures_tab.add_child(parent_selected)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)

func _make_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	return label

func _make_separator() -> HSeparator:
	var separator: HSeparator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 8)
	return separator

func _make_spin(label_text: String, min_value: float, max_value: float, value: float, step: float) -> SpinBox:
	var label: Label = Label.new()
	label.text = label_text
	add_child(label)
	var spin: SpinBox = SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.value = value
	spin.step = step
	add_child(spin)
	return spin

func _move_last_children_to(_anchor: Node, target: Container, count: int) -> void:
	var moved: Array[Node] = []
	for i: int in range(count):
		var child: Node = get_child(get_child_count() - count + i)
		moved.append(child)
	for child: Node in moved:
		remove_child(child)
		target.add_child(child)

func _get_direction_label(side: int) -> String:
	var labels: Array[String] = ["E", "NE", "NW", "W", "SW", "SE"]
	return labels[side] if side >= 0 and side < labels.size() else str(side)

func handle_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> bool:
	if viewport_camera == null or editor_plugin == null:
		return false
	_update_worldspace_handles()

	var mouse_event: InputEventMouse = event as InputEventMouse
	if mouse_event != null:
		hovered_worldspace_handle = _get_hovered_worldspace_handle(viewport_camera, mouse_event.position)
		_refresh_worldspace_handle_materials()

	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if (
		mouse_button != null
		and mouse_button.pressed
		and mouse_button.button_index == MOUSE_BUTTON_LEFT
		and hovered_worldspace_handle >= 0
	):
		_grow_footprint_direction(hovered_worldspace_handle)
		_update_worldspace_handles()
		return true
	return false

func cleanup_worldspace_handles() -> void:
	if worldspace_handle_root != null and is_instance_valid(worldspace_handle_root):
		worldspace_handle_root.queue_free()
	worldspace_handle_root = null
	worldspace_handle_nodes.clear()
	worldspace_selected_hex = null
	hovered_worldspace_handle = -1

func _use_edited_scene_root_as_settlement() -> bool:
	var edited_root: Node3D = editor_plugin.get_editor_interface().get_edited_scene_root() as Node3D
	if edited_root == null:
		return false
	_set_settlement_root(edited_root)
	return true

func _set_settlement_root(root: Node3D) -> void:
	settlement_root = root
	if root_label != null:
		root_label.text = "Editing: %s" % settlement_root.name

func _load_grid_settings() -> void:
	var grid_node: Node = _find_grid_from_selection()
	if grid_node == null:
		grid_node = _find_grid_in_scene()
	if grid_node == null:
		_set_status("Could not find a HexGrid in the selection or edited scene.")
		return

	_apply_grid_settings_from_node(grid_node)
	_set_status("Loaded grid spacing from %s." % grid_node.name)

func _load_grid_settings_from_scene_if_available() -> void:
	var grid_node: Node = _find_grid_in_scene()
	if grid_node != null:
		_apply_grid_settings_from_node(grid_node)

func _apply_grid_settings_from_node(grid_node: Node) -> void:
	var radius_value: float = HexGrid.RADIUS_IN
	var spacing_value: float = 0.25
	var pointy_value: bool = false
	if _node_has_property(grid_node, "_spacing"):
		spacing_value = float(grid_node.get("_spacing"))
	if _node_has_property(grid_node, "pointy_top"):
		pointy_value = bool(grid_node.get("pointy_top"))
	inner_radius_spin.value = radius_value
	spacing_spin.value = spacing_value
	pointy_top_check.button_pressed = pointy_value
	grid_source_label.text = "Grid: %s" % grid_node.name
	_save_grid_settings()
	_reposition_footprint_markers()

func _restore_grid_settings() -> void:
	if editor_plugin == null:
		return
	var settings: EditorSettings = editor_plugin.get_editor_interface().get_editor_settings()
	if settings.has_setting(EDITOR_SETTINGS_PREFIX + "inner_radius"):
		inner_radius_spin.value = float(settings.get_setting(EDITOR_SETTINGS_PREFIX + "inner_radius"))
	if settings.has_setting(EDITOR_SETTINGS_PREFIX + "extra_spacing"):
		spacing_spin.value = float(settings.get_setting(EDITOR_SETTINGS_PREFIX + "extra_spacing"))
	if settings.has_setting(EDITOR_SETTINGS_PREFIX + "pointy_top"):
		pointy_top_check.button_pressed = bool(settings.get_setting(EDITOR_SETTINGS_PREFIX + "pointy_top"))
	grid_source_label.text = "Grid: saved editor defaults"
	_reposition_footprint_markers()

func _save_grid_settings() -> void:
	if editor_plugin == null:
		return
	var settings: EditorSettings = editor_plugin.get_editor_interface().get_editor_settings()
	settings.set_setting(EDITOR_SETTINGS_PREFIX + "inner_radius", float(inner_radius_spin.value))
	settings.set_setting(EDITOR_SETTINGS_PREFIX + "extra_spacing", float(spacing_spin.value))
	settings.set_setting(EDITOR_SETTINGS_PREFIX + "pointy_top", pointy_top_check.button_pressed)

func _on_grid_setting_changed(_value: float) -> void:
	_save_grid_settings()
	_reposition_footprint_markers()
	_update_worldspace_handles()

func _on_grid_orientation_changed(_pressed: bool) -> void:
	_save_grid_settings()
	_reposition_footprint_markers()
	_update_worldspace_handles()

func _find_grid_from_selection() -> Node:
	for node: Node in editor_plugin.get_editor_interface().get_selection().get_selected_nodes():
		var grid_node: Node = _find_grid_node(node)
		if grid_node != null:
			return grid_node
	return null

func _find_grid_in_scene() -> Node:
	var edited_root: Node = editor_plugin.get_editor_interface().get_edited_scene_root()
	return _find_grid_node(edited_root)

func _find_grid_node(node: Node) -> Node:
	if node == null:
		return null
	if _looks_like_hex_grid(node):
		return node
	for child: Node in node.get_children():
		var found: Node = _find_grid_node(child)
		if found != null:
			return found
	return null

func _looks_like_hex_grid(node: Node) -> bool:
	var script: Script = node.get_script() as Script
	if script != null and String(script.get_global_name()) == "HexGrid":
		return true
	return _node_has_property(node, "pointy_top") and _node_has_property(node, "_spacing")

func _node_has_property(node: Object, property_name: String) -> bool:
	if node == null:
		return false
	for property: Dictionary in node.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false

func _create_settlement_root() -> void:
	var edited_root: Node = editor_plugin.get_editor_interface().get_edited_scene_root()
	if edited_root == null:
		_set_status("Open a scene before creating a settlement.")
		return
	if not (edited_root is Node3D):
		_set_status("The edited scene root must be a Node3D.")
		return

	var root: Node3D = edited_root as Node3D
	var script: Script = load(SETTLEMENT_SCRIPT) as Script
	_set_settlement_root(root)

	var undo: EditorUndoRedoManager = _get_undo_redo()
	var pending_containers: Dictionary[String, Node3D] = {}
	_create_undo_action(undo, "Set Up Settlement Scene Root")
	var changed: bool = false
	if script != null and root.get_script() != script:
		var old_script: Script = root.get_script() as Script
		undo.add_do_method(root, "set_script", script)
		undo.add_undo_method(root, "set_script", old_script)
		changed = true
	var script_available: bool = script != null
	if _queue_settlement_defaults(undo, root, script_available):
		changed = true
	if _queue_missing_containers(undo, pending_containers):
		changed = true
	if _get_footprint_hex(Vector2i.ZERO) == null and not _pending_footprint_hex_exists(Vector2i.ZERO, pending_containers):
		_queue_footprint_hex(Vector2i.ZERO, undo, pending_containers)
		changed = true
	if _queue_spawn_position_if_needed(undo, root, script_available):
		changed = true
	if changed:
		undo.commit_action()
		_set_status("Set up the scene root as a settlement.")
	else:
		undo.commit_action()
		_set_status("Scene root already has the settlement setup.")

func _queue_settlement_defaults(undo: EditorUndoRedoManager, root: Node3D, script_available: bool) -> bool:
	var changed: bool = false
	if script_available or _node_has_property(root, "upgrade_requirements"):
		var upgrades: Array[Resource] = [
			load(SETTLEMENT_UPGRADE_LEVEL_2),
			load(SETTLEMENT_UPGRADE_LEVEL_3),
		]
		if root.get("upgrade_requirements") != upgrades:
			_queue_property_change(undo, root, "upgrade_requirements", [
				load(SETTLEMENT_UPGRADE_LEVEL_2),
				load(SETTLEMENT_UPGRADE_LEVEL_3),
			])
			changed = true
	if (script_available or _node_has_property(root, "structure_invalid_range")) and root.get("structure_invalid_range") != 3:
		_queue_property_change(undo, root, "structure_invalid_range", 3)
		changed = true
	return changed

func _queue_spawn_position_if_needed(undo: EditorUndoRedoManager, root: Node3D, script_available: bool) -> bool:
	if not script_available and not _node_has_property(root, "spawn_position"):
		return false
	if root.get("spawn_position") == NodePath("player_spawn"):
		return false
	_queue_property_change(undo, root, "spawn_position", NodePath("player_spawn"))
	return true

func _on_piece_selected(index: int) -> void:
	if index >= 0 and index < PIECES.size():
		var piece: Dictionary = PIECES[index]
		piece_name.text = String(piece["name"])

func _on_buildable_toggled(enabled: bool) -> void:
	quest_options.visible = enabled
	required_level_spin.visible = enabled

func _add_piece() -> void:
	if not _require_settlement():
		return
	var piece: Dictionary = PIECES[piece_options.selected]
	var parent: Node3D = settlement_root.get_node_or_null(STRUCTURES_ROOT) as Node3D
	if parent == null:
		_set_status("Set up the settlement containers first.")
		return
	var undo: EditorUndoRedoManager = _get_undo_redo()
	_create_undo_action(undo, "Add Settlement Piece")
	if buildable_check.button_pressed:
		_queue_buildable_piece(parent, piece, undo)
	else:
		_queue_scene_instance(parent, String(piece["path"]), piece_name.text, _selected_hex_position(), rotation_spin.value, undo)
	undo.commit_action()

func _queue_buildable_piece(parent: Node, piece: Dictionary, undo: EditorUndoRedoManager) -> void:
	var buildable_scene: PackedScene = load(BUILDABLE_SCENE) as PackedScene
	if buildable_scene == null:
		_set_status("Missing buildable scene.")
		return

	var buildable: Node3D = buildable_scene.instantiate() as Node3D
	buildable.name = "buildable_%s" % piece_name.text
	buildable.position = _selected_hex_position()
	buildable.rotation_degrees.y = rotation_spin.value

	var foundation: Node3D = _create_foundation()
	buildable.add_child(foundation)
	foundation.name = "foundation"
	_add_default_interaction_shapes(foundation)

	var final_piece: Node3D = _instantiate_scene(String(piece["path"]))
	if final_piece == null:
		buildable.queue_free()
		_set_status("Could not load %s." % String(piece["path"]))
		return
	final_piece.name = piece_name.text
	final_piece.visible = false
	buildable.add_child(final_piece)

	buildable.set("build_steps", [NodePath("foundation"), NodePath(final_piece.name)])
	_queue_add_node(undo, parent, buildable)

	_set_status("Added buildable %s." % String(piece["label"]))

func _create_foundation() -> Node3D:
	var foundation_scene: PackedScene = load(FOUNDATION_SCENE) as PackedScene
	var foundation: Node3D = foundation_scene.instantiate() as Node3D
	foundation.name = "foundation"
	var script: Script = load(FOUNDATION_SCRIPT) as Script
	if script != null:
		foundation.set_script(script)
	var selected_quest: Dictionary = QUESTS[quest_options.selected]
	var quest_path: String = String(selected_quest["path"])
	if quest_path != "":
		foundation.set("quest", load(quest_path))
	foundation.set("required_settlement_level", int(required_level_spin.value))
	var material: Material = load(DEFAULT_MATERIAL) as Material
	var root: Node = foundation.get_node_or_null("RootNode")
	if root != null and root.get_child_count() > 0 and root.get_child(0) is MeshInstance3D:
		(root.get_child(0) as MeshInstance3D).set_surface_override_material(0, material)
	return foundation

func _add_default_interaction_shapes(parent: Node3D) -> void:
	var trigger: Area3D = Area3D.new()
	trigger.name = "interaction"
	parent.add_child(trigger)

	var trigger_shape: CollisionShape3D = CollisionShape3D.new()
	trigger_shape.name = "CollisionShape3D"
	trigger_shape.position = Vector3(0.02, 0.14, 0.12)
	var trigger_box: BoxShape3D = BoxShape3D.new()
	trigger_box.size = Vector3(1.6, 0.31, 1.26)
	trigger_shape.shape = trigger_box
	trigger.add_child(trigger_shape)

	var collision: StaticBody3D = StaticBody3D.new()
	collision.name = "collision"
	parent.add_child(collision)

	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.position = Vector3(0.04, 0.14, 0.1)
	var collision_box: BoxShape3D = BoxShape3D.new()
	collision_box.size = Vector3(1.05, 0.29, 0.88)
	collision_shape.shape = collision_box
	collision.add_child(collision_shape)

func _queue_scene_instance(
	parent: Node,
	scene_path: String,
	node_name: String,
	position: Vector3,
	rotation_degrees_y: float,
	undo: EditorUndoRedoManager
) -> Node3D:
	var instance: Node3D = _instantiate_scene(scene_path)
	if instance == null:
		_set_status("Could not load %s." % scene_path)
		return null
	instance.name = node_name
	instance.position = position
	instance.rotation_degrees.y = rotation_degrees_y
	_queue_add_node(undo, parent, instance)
	_set_status("Added %s." % node_name)
	return instance

func _instantiate_scene(scene_path: String) -> Node3D:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as Node3D

func _snap_selected_to_hex() -> void:
	var undo: EditorUndoRedoManager = _get_undo_redo()
	_create_undo_action(undo, "Snap Settlement Nodes to Hex")
	for node: Node in editor_plugin.get_editor_interface().get_selection().get_selected_nodes():
		if node is Node3D:
			var node_3d: Node3D = node as Node3D
			var local_position: Vector3 = node_3d.position
			if settlement_root != null and node_3d != settlement_root and settlement_root.is_ancestor_of(node_3d):
				local_position = node_3d.position
			_queue_property_change(undo, node_3d, "position", _snap_position(local_position))
	undo.commit_action()
	_set_status("Snapped selected Node3D nodes.")

func _rotate_selected() -> void:
	var undo: EditorUndoRedoManager = _get_undo_redo()
	_create_undo_action(undo, "Rotate Settlement Nodes")
	for node: Node in editor_plugin.get_editor_interface().get_selection().get_selected_nodes():
		if node is Node3D:
			var node_3d: Node3D = node as Node3D
			var rotation_degrees: Vector3 = node_3d.rotation_degrees
			rotation_degrees.y = _normalize_degrees(rotation_degrees.y + 60.0)
			_queue_property_change(undo, node_3d, "rotation_degrees", rotation_degrees)
	undo.commit_action()
	_set_status("Rotated selected Node3D nodes.")

func _move_selected_to_structures() -> void:
	if not _require_settlement():
		return
	var target: Node3D = settlement_root.get_node_or_null(STRUCTURES_ROOT) as Node3D
	if target == null:
		_set_status("Set up the settlement containers first.")
		return
	var undo: EditorUndoRedoManager = _get_undo_redo()
	_create_undo_action(undo, "Move Settlement Nodes to Structures")
	for node: Node in editor_plugin.get_editor_interface().get_selection().get_selected_nodes():
		if node is Node3D and node != settlement_root and node.get_parent() != target:
			var node_3d: Node3D = node as Node3D
			var old_parent: Node = node_3d.get_parent()
			var old_global: Transform3D = node_3d.global_transform
			var old_owner: Node = node_3d.owner
			undo.add_do_method(self, "_reparent_node_keep_global", node_3d, target, old_global, _get_edited_scene_root())
			undo.add_undo_method(self, "_reparent_node_keep_global", node_3d, old_parent, old_global, old_owner)
	undo.commit_action()
	_set_status("Moved selected nodes under structures.")

func _add_entrance() -> void:
	if not _require_settlement():
		return
	var entrances: Node3D = settlement_root.get_node_or_null(ENTRANCES_ROOT) as Node3D
	if entrances == null:
		_set_status("Set up the settlement containers first.")
		return
	var selected_walls: Array[Node3D] = _get_selected_wall_nodes()
	if selected_walls.is_empty():
		_set_status("Select one or more wall segments to replace with entrances.")
		return
	var replacements: Array[Dictionary] = []
	var replaced_count: int = 0
	for wall: Node3D in selected_walls:
		if wall == null or not is_instance_valid(wall):
			continue
		var gate: Node3D = _create_entrance_replacement(wall)
		if gate == null:
			continue
		replacements.append({"old": wall, "new": gate})
	if replacements.is_empty():
		_set_status("No valid selected wall segments found.")
		return
	var undo: EditorUndoRedoManager = _get_undo_redo()
	_create_undo_action(undo, "Replace Selected Walls With Entrances")
	for replacement_pair: Dictionary in replacements:
		var old_wall: Node = replacement_pair["old"] as Node
		var new_gate: Node = replacement_pair["new"] as Node
		if old_wall == null or new_gate == null or not is_instance_valid(old_wall):
			continue
		_queue_replace_node_to_parent(undo, old_wall, new_gate, entrances)
		replaced_count += 1
	undo.commit_action()
	_set_status("Replaced %s selected wall segments with entrances." % replaced_count)

func _grow_footprint_direction(side: int) -> void:
	if not _require_settlement():
		return
	var selected_hex: Node3D = _get_selected_footprint_hex()
	if selected_hex == null:
		_refresh_selected_footprint_label()
		_set_status("Select a footprint hex in the 3D scene first.")
		return
	var origin: Vector2i = _get_footprint_hex_coord(selected_hex)
	var direction: Vector2i = HEX_DIRECTIONS[side]
	var target: Vector2i = origin + direction
	_add_footprint_hex(target)
	_refresh_selected_footprint_label()

func _add_footprint_hex(hex: Vector2i) -> Node3D:
	if not _require_settlement():
		return null
	var undo: EditorUndoRedoManager = _get_undo_redo()
	_create_undo_action(undo, "Add Settlement Footprint Hex")
	var marker: Node3D = _queue_footprint_hex(hex, undo)
	undo.commit_action()
	return marker

func _get_selected_footprint_hex() -> Node3D:
	for node: Node in editor_plugin.get_editor_interface().get_selection().get_selected_nodes():
		var node_3d: Node3D = node as Node3D
		while node_3d != null and node_3d != settlement_root:
			if node_3d.has_meta("settlement_q") and node_3d.has_meta("settlement_r"):
				return node_3d
			node_3d = node_3d.get_parent() as Node3D
	return null

func _refresh_selected_footprint_label() -> void:
	if selected_hex_label == null:
		return
	var selected_hex: Node3D = _get_selected_footprint_hex()
	if selected_hex == null:
		selected_hex_label.text = "Selected footprint: none"
		return
	selected_hex_label.text = "Selected footprint: %s" % selected_hex.name

func _update_worldspace_handles() -> void:
	if settlement_root == null or not is_instance_valid(settlement_root):
		_clear_worldspace_handles()
		return
	var selected_hex: Node3D = _get_selected_footprint_hex()
	if selected_hex == null:
		_clear_worldspace_handles()
		return
	if selected_hex == worldspace_selected_hex and worldspace_handle_nodes.size() == 6:
		_position_worldspace_handles(selected_hex)
		return
	worldspace_selected_hex = selected_hex
	_rebuild_worldspace_handles(selected_hex)
	_refresh_selected_footprint_label()

func _rebuild_worldspace_handles(selected_hex: Node3D) -> void:
	_clear_worldspace_handles()
	var edited_root: Node = _get_edited_scene_root()
	if edited_root == null:
		return

	worldspace_handle_root = Node3D.new()
	worldspace_handle_root.name = "settlement_designer_worldspace_handles"
	edited_root.add_child(worldspace_handle_root)

	for side: int in range(6):
		var handle: MeshInstance3D = MeshInstance3D.new()
		handle.name = "expand_%s" % _get_direction_label(side)
		handle.mesh = _create_worldspace_handle_mesh()
		handle.material_override = _get_handle_material(false)
		handle.set_meta("settlement_direction", side)
		worldspace_handle_root.add_child(handle)
		worldspace_handle_nodes.append(handle)
	_position_worldspace_handles(selected_hex)

func _clear_worldspace_handles() -> void:
	if worldspace_handle_root != null and is_instance_valid(worldspace_handle_root):
		worldspace_handle_root.queue_free()
	worldspace_handle_root = null
	worldspace_handle_nodes.clear()
	worldspace_selected_hex = null
	hovered_worldspace_handle = -1

func _position_worldspace_handles(selected_hex: Node3D) -> void:
	var origin: Vector2i = _get_footprint_hex_coord(selected_hex)
	for handle_node: Node3D in worldspace_handle_nodes:
		var side: int = int(handle_node.get_meta("settlement_direction", 0))
		var local_pos: Vector3 = _axial_edge_to_local(origin, side)
		handle_node.global_position = settlement_root.global_transform * (local_pos + Vector3.UP * HANDLE_HEIGHT)

func _create_worldspace_handle_mesh() -> Mesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.28, 0.08, 0.28)
	return mesh

func _get_handle_material(hovered: bool) -> StandardMaterial3D:
	if hovered:
		if handle_hover_material == null:
			handle_hover_material = StandardMaterial3D.new()
			handle_hover_material.albedo_color = Color(0.25, 0.9, 1.0, 0.85)
			handle_hover_material.emission_enabled = true
			handle_hover_material.emission = Color(0.25, 0.9, 1.0)
			handle_hover_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			handle_hover_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return handle_hover_material
	if handle_material == null:
		handle_material = StandardMaterial3D.new()
		handle_material.albedo_color = Color(0.9, 0.75, 0.25, 0.8)
		handle_material.emission_enabled = true
		handle_material.emission = Color(0.9, 0.65, 0.15)
		handle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		handle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return handle_material

func _get_hovered_worldspace_handle(viewport_camera: Camera3D, mouse_position: Vector2) -> int:
	var best_side: int = -1
	var best_distance: float = HANDLE_PICK_RADIUS_PX * HANDLE_PICK_RADIUS_PX
	for handle_node: Node3D in worldspace_handle_nodes:
		if handle_node == null or not is_instance_valid(handle_node):
			continue
		if viewport_camera.is_position_behind(handle_node.global_position):
			continue
		var screen_position: Vector2 = viewport_camera.unproject_position(handle_node.global_position)
		var distance: float = screen_position.distance_squared_to(mouse_position)
		if distance <= best_distance:
			best_distance = distance
			best_side = int(handle_node.get_meta("settlement_direction", -1))
	return best_side

func _refresh_worldspace_handle_materials() -> void:
	for handle_node: Node3D in worldspace_handle_nodes:
		var mesh_instance: MeshInstance3D = handle_node as MeshInstance3D
		if mesh_instance == null:
			continue
		var side: int = int(mesh_instance.get_meta("settlement_direction", -1))
		mesh_instance.material_override = _get_handle_material(side == hovered_worldspace_handle)

func _get_footprint_hex(hex: Vector2i) -> Node3D:
	var footprint: Node3D = settlement_root.get_node_or_null(FOOTPRINT_ROOT) as Node3D
	if footprint == null:
		return null
	return footprint.get_node_or_null(_get_footprint_hex_name(hex)) as Node3D

func _get_footprint_hex_coord(marker: Node3D) -> Vector2i:
	return Vector2i(int(marker.get_meta("settlement_q", 0)), int(marker.get_meta("settlement_r", 0)))

func _get_footprint_hex_name(hex: Vector2i) -> String:
	return "footprint_%s_%s" % [hex.x, hex.y]

func _add_boundary_walls() -> void:
	if not _require_settlement():
		return
	var footprint_coords: Dictionary[Vector2i, bool] = _get_footprint_coords()
	if footprint_coords.is_empty():
		_set_status("Add footprint hexes before creating boundary walls.")
		return
	var walls: Node3D = settlement_root.get_node_or_null(WALLS_ROOT) as Node3D
	if walls == null:
		_set_status("Set up the settlement containers first.")
		return
	var undo: EditorUndoRedoManager = _get_undo_redo()
	_create_undo_action(undo, "Add Settlement Boundary Walls")
	for hex: Vector2i in footprint_coords.keys():
		for side: int in range(6):
			var neighbor: Vector2i = hex + HEX_DIRECTIONS[side]
			if footprint_coords.has(neighbor):
				continue
			var wall_name: String = "boundary_wall_%s_%s_%s" % [hex.x, hex.y, side]
			if walls.get_node_or_null(wall_name) != null:
				continue
			_queue_wall_placeholder(walls, wall_name, hex, side, undo)
	undo.commit_action()
	_set_status("Added boundary wall placeholders from footprint.")

func _replace_wall_placeholders() -> void:
	if not _require_settlement():
		return
	var walls: Node3D = settlement_root.get_node_or_null(WALLS_ROOT) as Node3D
	if walls == null:
		_set_status("Set up the settlement containers first.")
		return
	var placeholders: Array[Node3D] = _get_wall_placeholders(walls)
	if placeholders.is_empty():
		_set_status("No wall placeholders found.")
		return
	var replacements: Array[Dictionary] = []
	var replaced_count: int = 0
	for placeholder: Node3D in placeholders:
		if placeholder == null or not is_instance_valid(placeholder):
			continue
		var replacement: Node3D = _create_wall_replacement(placeholder)
		if replacement == null:
			continue
		replacements.append({"old": placeholder, "new": replacement})
	if replacements.is_empty():
		_set_status("No valid wall placeholders found.")
		return
	var undo: EditorUndoRedoManager = _get_undo_redo()
	_create_undo_action(undo, "Replace Settlement Wall Placeholders")
	for replacement_pair: Dictionary in replacements:
		var old_placeholder: Node = replacement_pair["old"] as Node
		var new_wall: Node = replacement_pair["new"] as Node
		if old_placeholder == null or new_wall == null or not is_instance_valid(old_placeholder):
			continue
		_queue_replace_node(undo, old_placeholder, new_wall)
		replaced_count += 1
	undo.commit_action()
	_set_status("Replaced %s wall placeholders. Use undo before saving if needed." % replaced_count)

func _remove_footprint_ground() -> void:
	if not _require_settlement():
		return
	var footprint: Node3D = settlement_root.get_node_or_null(FOOTPRINT_ROOT) as Node3D
	if footprint == null:
		_set_status("There is no footprint ground to remove.")
		return
	cleanup_worldspace_handles()
	var undo: EditorUndoRedoManager = _get_undo_redo()
	_create_undo_action(undo, "Remove Settlement Footprint Ground")
	_queue_remove_node(undo, footprint)
	undo.commit_action()
	_refresh_selected_footprint_label()
	_set_status("Removed footprint ground. Use undo if you still need it for editing.")

func _save_without_footprint_ground() -> void:
	if not _require_settlement():
		return
	var footprint: Node3D = settlement_root.get_node_or_null(FOOTPRINT_ROOT) as Node3D
	var removed_footprint: bool = false
	if footprint != null:
		cleanup_worldspace_handles()
		_remove_node_now(footprint)
		_refresh_selected_footprint_label()
		removed_footprint = true
	editor_plugin.get_editor_interface().save_scene()
	if removed_footprint:
		_set_status("Removed footprint ground and saved the scene.")
	else:
		_set_status("No footprint ground found; saved the scene.")

func _get_footprint_coords() -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	if settlement_root == null:
		return result
	var footprint: Node3D = settlement_root.get_node_or_null(FOOTPRINT_ROOT) as Node3D
	if footprint == null:
		return result
	for child: Node in footprint.get_children():
		var marker: Node3D = child as Node3D
		if marker != null and marker.has_meta("settlement_q") and marker.has_meta("settlement_r"):
			result[_get_footprint_hex_coord(marker)] = true
	return result

func _reposition_footprint_markers() -> void:
	if settlement_root == null or not is_instance_valid(settlement_root):
		return
	var footprint: Node3D = settlement_root.get_node_or_null(FOOTPRINT_ROOT) as Node3D
	if footprint == null:
		return
	for child: Node in footprint.get_children():
		var marker: Node3D = child as Node3D
		if marker == null or not marker.has_meta("settlement_q") or not marker.has_meta("settlement_r"):
			continue
		var coord: Vector2i = _get_footprint_hex_coord(marker)
		marker.position = _axial_to_local(coord)
		marker.rotation_degrees.y = 30.0 if _is_pointy_top() else 0.0

func _queue_missing_containers(
	undo: EditorUndoRedoManager,
	pending_containers: Dictionary[String, Node3D]
) -> bool:
	var changed: bool = false
	if _get_container_for_action(FOOTPRINT_ROOT, undo, pending_containers) != null and pending_containers.has(FOOTPRINT_ROOT):
		changed = true
	if _get_container_for_action(STRUCTURES_ROOT, undo, pending_containers) != null and pending_containers.has(STRUCTURES_ROOT):
		changed = true
	if _get_container_for_action(WALLS_ROOT, undo, pending_containers) != null and pending_containers.has(WALLS_ROOT):
		changed = true
	if _get_container_for_action(ENTRANCES_ROOT, undo, pending_containers) != null and pending_containers.has(ENTRANCES_ROOT):
		changed = true
	if settlement_root.get_node_or_null("player_spawn") == null:
		var spawn: Node3D = Node3D.new()
		spawn.name = "player_spawn"
		_queue_add_node(undo, settlement_root, spawn)
		changed = true
	return changed

func _pending_footprint_hex_exists(hex: Vector2i, pending_containers: Dictionary[String, Node3D]) -> bool:
	if not pending_containers.has(FOOTPRINT_ROOT):
		return false
	var footprint: Node3D = pending_containers[FOOTPRINT_ROOT] as Node3D
	if footprint == null:
		return false
	return footprint.get_node_or_null(_get_footprint_hex_name(hex)) != null

func _get_container_for_action(
	container_name: String,
	undo: EditorUndoRedoManager,
	pending_containers: Dictionary[String, Node3D]
) -> Node3D:
	var existing: Node3D = settlement_root.get_node_or_null(container_name) as Node3D
	if existing != null:
		return existing
	if pending_containers.has(container_name):
		return pending_containers[container_name] as Node3D
	var container: Node3D = Node3D.new()
	container.name = container_name
	pending_containers[container_name] = container
	_queue_add_node(undo, settlement_root, container)
	return container

func _queue_footprint_hex(
	hex: Vector2i,
	undo: EditorUndoRedoManager,
	pending_containers: Dictionary[String, Node3D] = {}
) -> Node3D:
	var existing: Node3D = _get_footprint_hex(hex)
	if existing != null:
		_set_status("Footprint already has hex %s,%s." % [hex.x, hex.y])
		return existing

	var footprint: Node3D = _get_container_for_action(FOOTPRINT_ROOT, undo, pending_containers)
	var marker: Node3D = _create_footprint_marker()
	marker.name = _get_footprint_hex_name(hex)
	marker.position = _axial_to_local(hex)
	marker.set_meta("settlement_q", hex.x)
	marker.set_meta("settlement_r", hex.y)
	_queue_add_node(undo, footprint, marker)
	_set_status("Added footprint hex %s,%s." % [hex.x, hex.y])
	return marker

func _create_footprint_marker() -> MeshInstance3D:
	var marker: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.035
	mesh.radial_segments = 6
	mesh.rings = 1
	marker.mesh = mesh
	marker.material_override = _get_footprint_material()
	marker.rotation_degrees.y = 30.0 if _is_pointy_top() else 0.0
	return marker

func _get_footprint_material() -> StandardMaterial3D:
	if footprint_material == null:
		footprint_material = StandardMaterial3D.new()
		footprint_material.albedo_color = Color(0.1, 0.65, 1.0, 0.35)
		footprint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		footprint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		footprint_material.no_depth_test = true
	return footprint_material

func _queue_wall_placeholder(
	parent: Node,
	node_name: String,
	hex: Vector2i,
	side: int,
	undo: EditorUndoRedoManager
) -> MeshInstance3D:
	var placeholder: MeshInstance3D = _create_wall_placeholder()
	placeholder.name = node_name
	placeholder.position = _axial_to_local(hex)
	placeholder.rotation_degrees.y = _wall_rotation_for_hex_side(hex, side)
	placeholder.set_meta(WALL_PLACEHOLDER_META, true)
	placeholder.set_meta(WALL_HEX_Q_META, hex.x)
	placeholder.set_meta(WALL_HEX_R_META, hex.y)
	placeholder.set_meta(WALL_SIDE_META, side)
	_queue_add_node(undo, parent, placeholder)
	return placeholder

func _create_wall_placeholder() -> MeshInstance3D:
	var placeholder: MeshInstance3D = MeshInstance3D.new()
	var inner_radius: float = float(inner_radius_spin.value)
	var wall_length: float = max(0.1, (2.0 * inner_radius / sqrt(3.0)) * 0.82)
	var wall_size: Vector3 = Vector3(wall_length, 0.32, 0.16)
	placeholder.mesh = _create_offset_box_mesh(wall_size, Vector3(0.0, 0.0, inner_radius))
	placeholder.material_override = _get_wall_placeholder_material()
	return placeholder

func _create_offset_box_mesh(size: Vector3, offset: Vector3) -> ArrayMesh:
	var half_size: Vector3 = size * 0.5
	var vertices: PackedVector3Array = PackedVector3Array([
		offset + Vector3(-half_size.x, -half_size.y, -half_size.z),
		offset + Vector3(half_size.x, -half_size.y, -half_size.z),
		offset + Vector3(half_size.x, half_size.y, -half_size.z),
		offset + Vector3(-half_size.x, half_size.y, -half_size.z),
		offset + Vector3(-half_size.x, -half_size.y, half_size.z),
		offset + Vector3(half_size.x, -half_size.y, half_size.z),
		offset + Vector3(half_size.x, half_size.y, half_size.z),
		offset + Vector3(-half_size.x, half_size.y, half_size.z),
	])
	var indices: PackedInt32Array = PackedInt32Array([
		0, 2, 1, 0, 3, 2,
		4, 5, 6, 4, 6, 7,
		0, 1, 5, 0, 5, 4,
		3, 7, 6, 3, 6, 2,
		1, 2, 6, 1, 6, 5,
		0, 4, 7, 0, 7, 3,
	])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _get_wall_placeholder_material() -> StandardMaterial3D:
	if wall_placeholder_material == null:
		wall_placeholder_material = StandardMaterial3D.new()
		wall_placeholder_material.albedo_color = Color(1.0, 0.78, 0.18, 0.45)
		wall_placeholder_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wall_placeholder_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return wall_placeholder_material

func _get_wall_placeholders(walls: Node) -> Array[Node3D]:
	var placeholders: Array[Node3D] = []
	for child: Node in walls.get_children():
		var node_3d: Node3D = child as Node3D
		if node_3d != null and is_instance_valid(node_3d) and bool(node_3d.get_meta(WALL_PLACEHOLDER_META, false)):
			placeholders.append(node_3d)
	return placeholders

func _get_selected_wall_nodes() -> Array[Node3D]:
	var walls_root: Node3D = settlement_root.get_node_or_null(WALLS_ROOT) as Node3D
	if walls_root == null:
		return []
	var selected_walls: Array[Node3D] = []
	for selected_node: Node in editor_plugin.get_editor_interface().get_selection().get_selected_nodes():
		var wall_node: Node3D = _get_wall_node_from_selection(selected_node, walls_root)
		if wall_node != null and not selected_walls.has(wall_node):
			selected_walls.append(wall_node)
	return selected_walls

func _get_wall_node_from_selection(selected_node: Node, walls_root: Node3D) -> Node3D:
	var node_3d: Node3D = selected_node as Node3D
	var wall_node: Node3D = null
	while node_3d != null and node_3d != settlement_root:
		if node_3d.get_parent() == walls_root:
			wall_node = node_3d
			break
		node_3d = node_3d.get_parent() as Node3D
	if wall_node != null and _is_wall_node(wall_node, walls_root):
		return wall_node
	return null

func _is_wall_node(node: Node3D, walls_root: Node3D) -> bool:
	if node == null or walls_root == null:
		return false
	if node == walls_root:
		return false
	if not walls_root.is_ancestor_of(node):
		return false
	return (
		bool(node.get_meta(WALL_PLACEHOLDER_META, false))
		or node.has_meta(WALL_SIDE_META)
		or node.name.begins_with("boundary_wall_")
	)

func _create_wall_replacement(placeholder: Node3D) -> Node3D:
	var replacement: Node3D = _instantiate_scene(WALL_SCENE)
	if replacement == null:
		_set_status("Could not load %s." % WALL_SCENE)
		return null
	replacement.name = placeholder.name
	replacement.position = placeholder.position
	replacement.rotation_degrees = placeholder.rotation_degrees
	replacement.rotation_degrees.y = _normalize_degrees(replacement.rotation_degrees.y + WALL_REPLACEMENT_YAW_OFFSET)
	if placeholder.has_meta(WALL_HEX_Q_META):
		replacement.set_meta(WALL_HEX_Q_META, placeholder.get_meta(WALL_HEX_Q_META))
	if placeholder.has_meta(WALL_HEX_R_META):
		replacement.set_meta(WALL_HEX_R_META, placeholder.get_meta(WALL_HEX_R_META))
	if placeholder.has_meta(WALL_SIDE_META):
		replacement.set_meta(WALL_SIDE_META, placeholder.get_meta(WALL_SIDE_META))
	return replacement

func _create_entrance_replacement(wall: Node3D) -> Node3D:
	var gate: Node3D = _instantiate_scene(GATE_SCENE)
	if gate == null:
		_set_status("Could not load %s." % GATE_SCENE)
		return null
	gate.name = _get_entrance_name_for_wall(wall)
	gate.position = wall.position
	gate.rotation_degrees = wall.rotation_degrees
	if bool(wall.get_meta(WALL_PLACEHOLDER_META, false)):
		gate.rotation_degrees.y = _normalize_degrees(gate.rotation_degrees.y + WALL_REPLACEMENT_YAW_OFFSET)
	if wall.has_meta(WALL_HEX_Q_META):
		gate.set_meta(WALL_HEX_Q_META, wall.get_meta(WALL_HEX_Q_META))
	if wall.has_meta(WALL_HEX_R_META):
		gate.set_meta(WALL_HEX_R_META, wall.get_meta(WALL_HEX_R_META))
	if wall.has_meta(WALL_SIDE_META):
		gate.set_meta(WALL_SIDE_META, wall.get_meta(WALL_SIDE_META))
	return gate

func _get_entrance_name_for_wall(wall: Node3D) -> String:
	if wall.has_meta(WALL_HEX_Q_META) and wall.has_meta(WALL_HEX_R_META) and wall.has_meta(WALL_SIDE_META):
		return "gate_%s_%s_%s" % [
			int(wall.get_meta(WALL_HEX_Q_META, 0)),
			int(wall.get_meta(WALL_HEX_R_META, 0)),
			int(wall.get_meta(WALL_SIDE_META, 0)),
		]
	return "gate_%s" % wall.name

func _queue_add_node(undo: EditorUndoRedoManager, parent: Node, node: Node) -> void:
	if parent == null or node == null:
		return
	undo.add_do_method(self, "_add_child_if_missing", parent, node)
	undo.add_do_method(self, "_set_node_owner_recursive", node, _get_edited_scene_root())
	undo.add_undo_method(self, "_set_node_owner_recursive", node, null)
	undo.add_undo_method(self, "_remove_child_if_parent", parent, node)
	undo.add_do_reference(node)

func _queue_remove_node(undo: EditorUndoRedoManager, node: Node) -> void:
	if node == null or node.get_parent() == null:
		return
	var parent: Node = node.get_parent()
	var owner: Node = node.owner
	undo.add_do_method(self, "_set_node_owner_recursive", node, null)
	undo.add_do_method(self, "_remove_child_if_parent", parent, node)
	undo.add_undo_method(self, "_add_child_if_missing", parent, node)
	undo.add_undo_method(self, "_set_node_owner_recursive", node, owner)
	undo.add_undo_reference(node)

func _queue_replace_node(undo: EditorUndoRedoManager, old_node: Node, new_node: Node) -> void:
	if old_node == null or new_node == null or old_node.get_parent() == null:
		return
	var parent: Node = old_node.get_parent()
	var old_owner: Node = old_node.owner
	undo.add_do_method(self, "_set_node_owner_recursive", old_node, null)
	undo.add_do_method(self, "_remove_child_if_parent", parent, old_node)
	undo.add_do_method(self, "_add_child_if_missing", parent, new_node)
	undo.add_do_method(self, "_set_node_owner_recursive", new_node, _get_edited_scene_root())
	undo.add_undo_method(self, "_set_node_owner_recursive", new_node, null)
	undo.add_undo_method(self, "_remove_child_if_parent", parent, new_node)
	undo.add_undo_method(self, "_add_child_if_missing", parent, old_node)
	undo.add_undo_method(self, "_set_node_owner_recursive", old_node, old_owner)
	undo.add_do_reference(new_node)
	undo.add_undo_reference(old_node)

func _queue_replace_node_to_parent(undo: EditorUndoRedoManager, old_node: Node, new_node: Node, new_parent: Node) -> void:
	if old_node == null or new_node == null or new_parent == null or old_node.get_parent() == null:
		return
	var old_parent: Node = old_node.get_parent()
	var old_owner: Node = old_node.owner
	undo.add_do_method(self, "_set_node_owner_recursive", old_node, null)
	undo.add_do_method(self, "_remove_child_if_parent", old_parent, old_node)
	undo.add_do_method(self, "_add_child_if_missing", new_parent, new_node)
	undo.add_do_method(self, "_set_node_owner_recursive", new_node, _get_edited_scene_root())
	undo.add_undo_method(self, "_set_node_owner_recursive", new_node, null)
	undo.add_undo_method(self, "_remove_child_if_parent", new_parent, new_node)
	undo.add_undo_method(self, "_add_child_if_missing", old_parent, old_node)
	undo.add_undo_method(self, "_set_node_owner_recursive", old_node, old_owner)
	undo.add_do_reference(new_node)
	undo.add_undo_reference(old_node)

func _remove_node_now(node: Node) -> void:
	if node == null or node.get_parent() == null:
		return
	var parent: Node = node.get_parent()
	_set_node_owner_recursive(node, null)
	parent.remove_child(node)
	node.queue_free()

func _add_child_if_missing(parent: Node, node: Node) -> void:
	if parent == null or node == null:
		return
	if node.get_parent() == parent:
		return
	if node.get_parent() != null:
		return
	parent.add_child(node)

func _remove_child_if_parent(parent: Node, node: Node) -> void:
	if parent == null or node == null:
		return
	if node.get_parent() != parent:
		return
	parent.remove_child(node)

func _queue_property_change(
	undo: EditorUndoRedoManager,
	object: Object,
	property: StringName,
	value: Variant
) -> void:
	if object == null:
		return
	undo.add_do_property(object, property, value)
	undo.add_undo_property(object, property, object.get(property))

func _reparent_node_keep_global(
	node: Node3D,
	new_parent: Node,
	global_transform: Transform3D,
	owner: Node
) -> void:
	if node == null or new_parent == null:
		return
	var current_parent: Node = node.get_parent()
	if current_parent != null and current_parent != new_parent:
		current_parent.remove_child(node)
	if node.get_parent() == null:
		new_parent.add_child(node)
	node.global_transform = global_transform
	_set_node_owner_recursive(node, owner)

func _set_node_owner_recursive(node: Node, owner: Node) -> void:
	if node == null:
		return
	node.owner = owner
	for child: Node in node.get_children():
		_set_node_owner_recursive(child, owner)

func _get_undo_redo() -> EditorUndoRedoManager:
	return editor_plugin.get_undo_redo()

func _create_undo_action(undo: EditorUndoRedoManager, action_name: String) -> void:
	var context: Object = _get_undo_context()
	if context != null:
		undo.create_action(action_name, 0, context)
	else:
		undo.create_action(action_name)

func _get_undo_context() -> Object:
	var edited_root: Node = editor_plugin.get_editor_interface().get_edited_scene_root()
	if edited_root != null:
		return edited_root
	return settlement_root

func _get_edited_scene_root() -> Node:
	var edited_root: Node = editor_plugin.get_editor_interface().get_edited_scene_root()
	return edited_root if edited_root != null else settlement_root

func _require_settlement() -> bool:
	var edited_root: Node3D = editor_plugin.get_editor_interface().get_edited_scene_root() as Node3D
	if edited_root != null and settlement_root != edited_root:
		_set_settlement_root(edited_root)
	if settlement_root == null or not is_instance_valid(settlement_root):
		_use_edited_scene_root_as_settlement()
	if settlement_root == null or not is_instance_valid(settlement_root):
		_set_status("Pick a settlement root first.")
		return false
	return true

func _selected_hex_position() -> Vector3:
	var selected_hex: Node3D = _get_selected_footprint_hex()
	if selected_hex == null:
		return Vector3.ZERO
	return _axial_to_local(_get_footprint_hex_coord(selected_hex))

func _axial_to_local(hex: Vector2i) -> Vector3:
	var spacing: Vector2 = _hex_spacing()
	var x: float = 0.0
	var z: float = 0.0
	if _is_pointy_top():
		x = spacing.x * float(hex.x)
		z = spacing.y * (float(hex.y) + float(hex.x) * 0.5)
	else:
		x = spacing.x * (float(hex.x) + float(hex.y) * 0.5)
		z = spacing.y * float(hex.y)
	return Vector3(x, 0.0, z)

func _axial_edge_to_local(hex: Vector2i, side: int) -> Vector3:
	var center: Vector3 = _axial_to_local(hex)
	var neighbor_center: Vector3 = _axial_to_local(hex + HEX_DIRECTIONS[side])
	return center.lerp(neighbor_center, 0.5)

func _snap_position(position: Vector3) -> Vector3:
	var spacing: Vector2 = _hex_spacing()
	var q: float = 0.0
	var r: float = 0.0
	if _is_pointy_top():
		q = round(position.x / spacing.x)
		r = round((position.z / spacing.y) - q * 0.5)
	else:
		r = round(position.z / spacing.y)
		q = round((position.x / spacing.x) - r * 0.5)
	return _axial_to_local(Vector2i(int(q), int(r)))

func _hex_spacing() -> Vector2:
	var inner_radius: float = float(inner_radius_spin.value)
	var extra_spacing: float = float(spacing_spin.value)
	if _is_pointy_top():
		return Vector2(1.5 * inner_radius + extra_spacing, sqrt(3.0) * inner_radius + extra_spacing)
	return Vector2(sqrt(3.0) * inner_radius + extra_spacing, 1.5 * inner_radius + extra_spacing)

func _is_pointy_top() -> bool:
	return pointy_top_check != null and pointy_top_check.button_pressed

func _wall_rotation_for_hex_side(hex: Vector2i, side: int) -> float:
	var center: Vector3 = _axial_to_local(hex)
	var neighbor_center: Vector3 = _axial_to_local(hex + HEX_DIRECTIONS[side])
	var normal: Vector3 = neighbor_center - center
	if normal.length_squared() <= 0.0001:
		return _normalize_degrees(float(side) * 60.0)
	return _normalize_degrees(rad_to_deg(atan2(normal.x, normal.z)))

func _normalize_degrees(degrees: float) -> float:
	return fposmod(degrees, 360.0)

func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
