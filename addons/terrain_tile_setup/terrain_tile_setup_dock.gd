@tool
extends VBoxContainer

const HEX_SLOPE_SCRIPT := preload("res://scripts/hex_system/base/hex_slope.gd")
const GUIDE_ROOT_NAME := "_terrain_tile_guides"
const EDGE_DIRECTIONS: Array[Vector3] = [
	Vector3(1.0, 0.0, 0.0),
	Vector3(0.5, 0.0, -0.8660254),
	Vector3(-0.5, 0.0, -0.8660254),
	Vector3(-1.0, 0.0, 0.0),
	Vector3(-0.5, 0.0, 0.8660254),
	Vector3(0.5, 0.0, 0.8660254),
]

var editor_plugin: EditorPlugin
var tile_label: Label
var uphill_edge: OptionButton
var edge_connectors: Array[OptionButton] = []
var rise_units: SpinBox
var status_label: Label
var guide_root: Node3D

func _init() -> void:
	name = "Terrain Tile Setup"
	custom_minimum_size = Vector2(280, 0)
	add_theme_constant_override("separation", 8)
	_build_ui()

func _exit_tree() -> void:
	cleanup_guides()

func _build_ui() -> void:
	var title := Label.new()
	title.text = "Terrain Tile Setup"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)

	tile_label = Label.new()
	tile_label.text = "Editing: no tile loaded"
	tile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(tile_label)

	var load_tile := Button.new()
	load_tile.text = "Use Edited Scene Root"
	load_tile.pressed.connect(_load_edited_tile)
	add_child(load_tile)

	var setup_slope := Button.new()
	setup_slope.text = "Make Root a Slope Tile"
	setup_slope.pressed.connect(_make_root_a_slope)
	add_child(setup_slope)

	add_child(_separator())
	add_child(_label("Slope Profile"))

	add_child(_label("Mesh high end"))
	uphill_edge = OptionButton.new()
	for edge in range(6):
		uphill_edge.add_item("EDGE %d" % edge, edge)
	uphill_edge.item_selected.connect(_refresh_guides)
	add_child(uphill_edge)

	add_child(_label("Rise units"))
	rise_units = SpinBox.new()
	rise_units.min_value = 1
	rise_units.max_value = 2
	rise_units.step = 1
	rise_units.value = 1
	add_child(rise_units)

	add_child(_label("Tile connections"))
	for edge in range(6):
		var row := HBoxContainer.new()
		var edge_label := _label("EDGE %d" % edge)
		edge_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(edge_label)
		var connector := OptionButton.new()
		connector.add_item("Disabled", 0)
		connector.add_item("Low", 1)
		connector.add_item("High", 2)
		connector.add_item("Navigation only", 3)
		connector.item_selected.connect(_refresh_guides)
		row.add_child(connector)
		edge_connectors.append(connector)
		add_child(row)

	var apply_profile := Button.new()
	apply_profile.text = "Apply Profile"
	apply_profile.pressed.connect(_apply_profile)
	add_child(apply_profile)

	var show_guides := Button.new()
	show_guides.text = "Show Entrance Guides"
	show_guides.pressed.connect(_refresh_guides)
	add_child(show_guides)

	var hide_guides := Button.new()
	hide_guides.text = "Hide Entrance Guides"
	hide_guides.pressed.connect(cleanup_guides)
	add_child(hide_guides)

	add_child(_separator())
	var instructions := Label.new()
	instructions.text = "High and Low are required terrain connectors. Navigation only is a walkable upper-level edge that does not affect placement. The mesh high end remains independent from these connections."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(instructions)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

func _separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 6)
	return separator

func _load_edited_tile() -> void:
	var tile := _get_edited_tile()
	if tile == null:
		tile_label.text = "Editing: open a tile scene with a Node3D root"
		status_label.text = "No suitable edited scene root found."
		cleanup_guides()
		return

	tile_label.text = "Editing: %s" % tile.name
	if tile is HexSlope:
		rise_units.value = tile.slope_rise_units
		uphill_edge.select(int(tile.asset_uphill_edge))
		for edge in range(6):
			var connector_state: int = 0
			var edge_mask := 1 << edge
			if (tile.navigation_only_mask & edge_mask) != 0:
				connector_state = 3
			elif (tile.connector_mask & edge_mask) != 0:
				var edge_offset: int = 0
				if edge < tile.edge_height_offsets.size():
					edge_offset = int(tile.edge_height_offsets[edge])
				if edge_offset <= 0:
					connector_state = 1
				else:
					connector_state = 2
			edge_connectors[edge].select(connector_state)
		status_label.text = "Slope profile loaded."
		_refresh_guides()
	else:
		status_label.text = "This root is not a HexSlope yet. Use Make Root a Slope Tile."
		cleanup_guides()

func _make_root_a_slope() -> void:
	var tile := _get_edited_tile()
	if tile == null:
		status_label.text = "Open a tile scene first."
		return
	if tile is HexSlope:
		status_label.text = "The edited root is already a slope tile."
		_load_edited_tile()
		return
	if not tile is HexBase:
		status_label.text = "The edited root must use HexBase before it can become a slope tile."
		return

	var undo_redo := editor_plugin.get_undo_redo()
	var previous_script := tile.get_script()
	undo_redo.create_action("Make Terrain Tile a Slope")
	undo_redo.add_do_method(tile, "set_script", HEX_SLOPE_SCRIPT)
	undo_redo.add_undo_method(tile, "set_script", previous_script)
	undo_redo.commit_action()
	status_label.text = "Slope script added. Set its high end and connections, then apply it."
	call_deferred("_load_edited_tile")

func _apply_profile() -> void:
	var tile := _get_edited_tile()
	if not tile is HexSlope:
		status_label.text = "Make the edited root a slope tile before applying a profile."
		return

	var new_mask: int = 0
	var new_navigation_only_mask: int = 0
	var new_offsets := PackedInt32Array([0, 0, 0, 0, 0, 0])
	var low_connections: int = 0
	var high_connections: int = 0
	for edge in range(6):
		var connector_state: int = edge_connectors[edge].get_selected_id()
		if connector_state == 0:
			continue
		var edge_mask := 1 << edge
		if connector_state == 1:
			new_mask |= edge_mask
			low_connections += 1
		elif connector_state == 2:
			new_mask |= edge_mask
			new_offsets[edge] = int(rise_units.value)
			high_connections += 1
		else:
			new_navigation_only_mask |= edge_mask
			new_offsets[edge] = int(rise_units.value)
	if low_connections == 0 or high_connections == 0:
		status_label.text = "A slope needs at least one low and one high connection."
		return

	var undo_redo := editor_plugin.get_undo_redo()
	undo_redo.create_action("Set Slope Tile Profile")
	undo_redo.add_do_property(tile, "slope_rise_units", int(rise_units.value))
	undo_redo.add_do_property(tile, "asset_uphill_edge", uphill_edge.get_selected_id())
	undo_redo.add_do_property(tile, "connector_mask", new_mask)
	undo_redo.add_do_property(tile, "navigation_only_mask", new_navigation_only_mask)
	undo_redo.add_do_property(tile, "edge_height_offsets", new_offsets)
	undo_redo.add_undo_property(tile, "slope_rise_units", tile.slope_rise_units)
	undo_redo.add_undo_property(tile, "asset_uphill_edge", tile.asset_uphill_edge)
	undo_redo.add_undo_property(tile, "connector_mask", tile.connector_mask)
	undo_redo.add_undo_property(tile, "navigation_only_mask", tile.navigation_only_mask)
	undo_redo.add_undo_property(tile, "edge_height_offsets", tile.edge_height_offsets)
	undo_redo.commit_action()
	status_label.text = "Slope profile applied with %d connections." % (low_connections + high_connections)
	_refresh_guides()

func _get_edited_tile() -> Node3D:
	if editor_plugin == null:
		return null
	return editor_plugin.get_editor_interface().get_edited_scene_root() as Node3D

func _refresh_guides(_selected: int = -1) -> void:
	cleanup_guides()
	var tile := _get_edited_tile()
	if tile == null:
		return

	guide_root = Node3D.new()
	guide_root.name = GUIDE_ROOT_NAME
	tile.add_child(guide_root)
	guide_root.owner = null
	for edge in range(6):
		var connector_state: int = edge_connectors[edge].get_selected_id()
		if connector_state == 1:
			_add_edge_guide(edge, "LOW", Color("60b5ff"))
		elif connector_state == 2:
			_add_edge_guide(edge, "HIGH", Color("67e86b"))
		elif connector_state == 3:
			_add_edge_guide(edge, "NAV HIGH", Color("d58cff"))
		else:
			_add_edge_guide(edge, "DISABLED", Color("9aa0a6"))

func _add_edge_guide(edge: int, label_text: String, color: Color) -> void:
	if guide_root == null:
		return
	var node := Node3D.new()
	node.name = "edge_%d" % edge
	node.position = EDGE_DIRECTIONS[edge] * 1.08 + Vector3.UP * 0.12
	guide_root.add_child(node)

	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	marker.mesh = sphere
	marker.material_override = _guide_material(color)
	node.add_child(marker)

	var label := Label3D.new()
	label.text = "%s %d" % [label_text, edge]
	label.position = Vector3.UP * 0.15
	label.font_size = 32
	label.outline_size = 8
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.add_child(label)

func _guide_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	return material

func cleanup_guides() -> void:
	if is_instance_valid(guide_root):
		guide_root.queue_free()
	guide_root = null
