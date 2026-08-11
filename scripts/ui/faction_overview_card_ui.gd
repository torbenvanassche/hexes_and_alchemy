class_name FactionOverviewCardUI
extends PanelContainer

const MEMBER_ROW_SCENE := preload("res://scenes/ui/components/faction_member_row.tscn")
const MEMBER_ROW_HEIGHT := 38

@onready var info_button: Button = $Margin/Content/Header/Info
@onready var title: Label = $Margin/Content/Header/Title
@onready var availability: Label = $Margin/Content/Header/Availability
@onready var progress: Label = $Margin/Content/Progress
@onready var members_scroll: ScrollContainer = $Margin/Content/MembersPanel/Margin/MembersContent/MembersScroll
@onready var members_rows: VBoxContainer = $Margin/Content/MembersPanel/Margin/MembersContent/MembersScroll/Rows
@onready var empty_members: Label = $Margin/Content/MembersPanel/Margin/MembersContent/EmptyMembers

var _members_scroll_height_update_pending := false

func setup(faction: FactionState) -> void:
	if faction == null:
		return
	if not is_node_ready():
		call_deferred("setup", faction)
		return
	title.text = faction.get_display_name()
	title.tooltip_text = _get_faction_info_tooltip(faction)
	info_button.tooltip_text = ""
	availability.text = tr("HUB_MEMBER_AVAILABILITY") % [
		faction.get_available_member_count(),
		faction.get_working_member_count(),
		faction.get_resting_member_count(),
	]
	progress.text = tr("HUB_COMPLETED_OPERATIONS") % faction.completed_operations
	_refresh_members(faction)

func _refresh_members(faction: FactionState) -> void:
	for child in members_rows.get_children():
		members_rows.remove_child(child)
		child.queue_free()
	var members: Array[NPC] = []
	for member: NPC in faction.members:
		if member != null and is_instance_valid(member):
			members.append(member)
	empty_members.visible = members.is_empty()
	members_scroll.visible = not members.is_empty()
	for member: NPC in members:
		var row := MEMBER_ROW_SCENE.instantiate() as FactionMemberRowUI
		members_rows.add_child(row)
		row.setup(member)
	_queue_members_scroll_height_update()
	members_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

func _queue_members_scroll_height_update() -> void:
	if _members_scroll_height_update_pending or not is_node_ready() or not is_inside_tree() or is_queued_for_deletion():
		return
	_members_scroll_height_update_pending = true
	_apply_members_scroll_height.call_deferred()

func _apply_members_scroll_height() -> void:
	_members_scroll_height_update_pending = false
	if not is_node_ready() or not is_inside_tree() or is_queued_for_deletion():
		return
	if not is_instance_valid(members_scroll) or not is_instance_valid(members_rows):
		return
	var visible_row_count := mini(members_rows.get_child_count(), 4)
	var required_height := 0.0
	for index in visible_row_count:
		var row := members_rows.get_child(index) as Control
		if row != null:
			required_height += maxf(MEMBER_ROW_HEIGHT, row.get_combined_minimum_size().y)
	if visible_row_count > 1:
		required_height += float(visible_row_count - 1) * members_rows.get_theme_constant("separation")
	members_scroll.custom_minimum_size.y = required_height

func _get_faction_info_tooltip(faction: FactionState) -> String:
	var lines: Array[String] = []
	lines.append("%s: %s" % [tr("HUB_FACTION_ROLES_LABEL"), ", ".join(faction.roles)])
	lines.append(tr("HUB_FACTION_RESPONSIBILITIES_LABEL") + ":")
	for responsibility: String in faction.responsibilities:
		lines.append("- " + responsibility)
	return "\n".join(lines)
