class_name OperationCardUI
extends PanelContainer

@onready var title: Label = $Margin/Columns/Details/Title
@onready var detail: Label = $Margin/Columns/Details/Detail
@onready var party: Label = $Margin/Columns/Details/Party
@onready var state: Label = $Margin/Columns/State

func setup(operation: HubOperation) -> void:
	if operation == null:
		return
	if not is_node_ready():
		call_deferred("setup", operation)
		return
	var operation_key := "QUEST_TYPE_%s" % operation.operation_type.to_upper()
	var operation_name := tr(operation_key)
	if operation_name == operation_key:
		operation_name = operation.operation_type.capitalize()
	title.text = operation_name
	detail.text = tr("HUB_OPERATION_DETAIL") % [_get_location_name(operation), operation.get_activity_name()]
	party.text = tr("HUB_PARTY_LABEL") % operation.get_assigned_npc_names()
	party.clip_text = true
	state.text = operation.get_state_name().to_upper()
	state.add_theme_color_override("font_color", _get_state_color(operation.state))
	var panel_style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	panel_style.border_color = _get_state_color(operation.state)
	add_theme_stylebox_override("panel", panel_style)

func _get_location_name(operation: HubOperation) -> String:
	if operation.quest != null and operation.quest.location != null and operation.quest.location.structure != null:
		var structure_info = operation.quest.location.structure.structure_info
		if structure_info != null:
			return structure_info.get_display_name()
	return tr("HUB_UNKNOWN_LOCATION")

func _get_state_color(operation_state: HubOperation.State) -> Color:
	match operation_state:
		HubOperation.State.WAITING:
			return Color(0.65, 0.45, 0.16, 1)
		HubOperation.State.EN_ROUTE, HubOperation.State.RETURNING:
			return Color(0.2, 0.42, 0.62, 1)
		HubOperation.State.IN_PROGRESS:
			return Color(0.18, 0.5, 0.34, 1)
		HubOperation.State.FAILED:
			return Color(0.65, 0.18, 0.15, 1)
	return Color(0.42, 0.31, 0.2, 1)
