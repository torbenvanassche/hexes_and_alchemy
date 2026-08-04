class_name HubOverviewUI
extends PanelContainer

@onready var faction_tabs: HBoxContainer = $Margin/Scroll/VBox/FactionTabs
@onready var faction_details: VBoxContainer = $Margin/Scroll/VBox/FactionDetails
@onready var operations_container: VBoxContainer = $Margin/Scroll/VBox/Operations

var active_faction_id: StringName = &"hunters"

func _ready() -> void:
	if Manager.instance != null:
		if Manager.instance.hub != null and not Manager.instance.hub.changed.is_connected(_refresh):
			Manager.instance.hub.changed.connect(_refresh)
		if Manager.instance.operations != null and not Manager.instance.operations.operations_changed.is_connected(_refresh):
			Manager.instance.operations.operations_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	if not is_node_ready() or Manager.instance == null or Manager.instance.hub == null:
		return
	var hub := Manager.instance.hub
	_refresh_factions(hub)
	_refresh_operations()

func _refresh_factions(hub: HubState) -> void:
	_clear_container(faction_tabs)
	for faction: FactionState in hub.factions.values():
		var tab := Button.new()
		tab.text = faction.display_name.to_upper()
		tab.toggle_mode = true
		tab.button_pressed = faction.id == active_faction_id
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(0, 34)
		tab.pressed.connect(_select_faction.bind(faction.id))
		faction_tabs.add_child(tab)
	if not hub.factions.has(active_faction_id) and not hub.factions.is_empty():
		active_faction_id = hub.factions.keys()[0]
	_refresh_faction_details(hub)

func _select_faction(faction_id: StringName) -> void:
	active_faction_id = faction_id
	if Manager.instance != null and Manager.instance.hub != null:
		_refresh_faction_details(Manager.instance.hub)
		_refresh_operations()

func _refresh_faction_details(hub: HubState) -> void:
	_clear_container(faction_details)
	var faction := hub.factions.get(active_faction_id) as FactionState
	if faction != null:
		faction_details.add_child(_create_faction_card(faction))

func _create_faction_card(faction: FactionState) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 0)
	card.add_theme_stylebox_override("panel", _make_card_style(Color(0.92, 0.84, 0.67, 0.65), Color(0.42, 0.31, 0.2, 0.35)))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	margin.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = faction.display_name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(0.28, 0.2, 0.13, 1))
	title.add_theme_font_size_override("font_size", 16)
	header.add_child(title)
	var availability := Label.new()
	availability.text = "%s available" % faction.get_available_member_count()
	availability.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	availability.add_theme_color_override("font_color", Color(0.32, 0.23, 0.14, 1))
	header.add_child(availability)
	var roles := Label.new()
	roles.text = "Roles: " + ", ".join(faction.roles)
	roles.add_theme_color_override("font_color", Color(0.42, 0.31, 0.2, 0.9))
	content.add_child(roles)
	for responsibility: String in faction.responsibilities:
		var task := HBoxContainer.new()
		task.add_theme_constant_override("separation", 6)
		var checkbox := CheckBox.new()
		checkbox.disabled = true
		checkbox.custom_minimum_size = Vector2(22, 22)
		task.add_child(checkbox)
		var task_label := Label.new()
		task_label.text = responsibility
		task_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		task_label.add_theme_color_override("font_color", Color(0.36, 0.27, 0.18, 1))
		task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		task.add_child(task_label)
		content.add_child(task)
	var progress := Label.new()
	progress.text = "Completed operations: %s" % faction.completed_operations
	progress.add_theme_color_override("font_color", Color(0.45, 0.34, 0.23, 0.9))
	content.add_child(progress)
	return card

func _refresh_operations() -> void:
	_clear_container(operations_container)
	var selected_faction := Manager.instance.hub.factions.get(active_faction_id) as FactionState if Manager.instance != null and Manager.instance.hub != null else null
	var active_operations: Array[HubOperation] = Manager.instance.operations.get_active_operations() if Manager.instance.operations != null else []
	if active_operations.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No active operations"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.45, 0.34, 0.23, 0.85))
		operations_container.add_child(empty_label)
		return
	for operation: HubOperation in active_operations:
		if operation == null or operation.quest == null:
			continue
		if selected_faction != null and operation.faction_id != selected_faction.id:
			continue
		operations_container.add_child(_create_operation_card(operation))
	if operations_container.get_child_count() == 0:
		var faction_empty_label := Label.new()
		faction_empty_label.text = "No active operations for this faction"
		faction_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		faction_empty_label.add_theme_color_override("font_color", Color(0.45, 0.34, 0.23, 0.85))
		operations_container.add_child(faction_empty_label)

func _create_operation_card(operation: HubOperation) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 68)
	var state_color := _get_state_color(operation.state)
	card.add_theme_stylebox_override("panel", _make_card_style(Color(0.12, 0.1, 0.08, 0.12), state_color))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	margin.add_child(columns)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(details)
	var title := Label.new()
	title.text = operation.operation_type.capitalize()
	title.add_theme_color_override("font_color", Color(0.27, 0.2, 0.14, 1))
	details.add_child(title)
	var location_name := "Unknown location"
	if operation.quest.location != null and operation.quest.location.structure != null and operation.quest.location.structure.structure_info != null:
		location_name = operation.quest.location.structure.structure_info.get_display_name()
	var detail := Label.new()
	detail.text = "%s - %s" % [location_name, operation.required_role.capitalize() if operation.required_role != "" else "General"]
	detail.add_theme_color_override("font_color", Color(0.42, 0.32, 0.22, 0.9))
	details.add_child(detail)
	var state := Label.new()
	state.text = operation.get_state_name().to_upper()
	state.custom_minimum_size = Vector2(112, 0)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state.add_theme_color_override("font_color", state_color)
	columns.add_child(state)
	return card

func _clear_container(container: Container) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _make_card_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _get_state_color(state: HubOperation.State) -> Color:
	match state:
		HubOperation.State.WAITING:
			return Color(0.65, 0.45, 0.16, 1)
		HubOperation.State.EN_ROUTE, HubOperation.State.RETURNING:
			return Color(0.2, 0.42, 0.62, 1)
		HubOperation.State.IN_PROGRESS:
			return Color(0.18, 0.5, 0.34, 1)
		HubOperation.State.FAILED:
			return Color(0.65, 0.18, 0.15, 1)
	return Color(0.42, 0.31, 0.2, 1)
