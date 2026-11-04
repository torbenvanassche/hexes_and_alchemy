class_name FactionOverviewCardUI
extends PanelContainer

signal details_requested(npc: NPC)

const MEMBER_ROW_SCENE := preload("res://scenes/ui/components/faction_member_row.tscn")

@onready var description: Label = $Content/Description
@onready var availability: Label = $Content/Availability
@onready var progress: Label = $Content/Progress
@onready var members_scroll: ScrollContainer = $Content/MembersScroll
@onready var members_rows: VBoxContainer = $Content/MembersScroll/Roster/Rows
@onready var empty_members: Label = $Content/MembersScroll/Roster/EmptyMembers

var faction_id: StringName

func setup(faction: FactionState) -> void:
	if faction == null:
		return
	if not is_node_ready():
		setup.call_deferred(faction)
		return
	faction_id = faction.id
	var key := "FACTION_%s_SUMMARY" % faction.id.to_upper()
	description.text = tr(key) if tr(key) != key else ", ".join(faction.get_role_display_names())
	description.tooltip_text = _get_faction_info_tooltip(faction)
	var counts: Array[String] = []
	var available := faction.get_available_member_count()
	var working := faction.get_working_member_count()
	var recovering := faction.get_resting_member_count()
	counts.append(tr("PEOPLE_AVAILABLE") % available)
	if working > 0:
		counts.append(tr("PEOPLE_AWAY") % working)
	if recovering > 0:
		counts.append(tr("PEOPLE_RECOVERING") % recovering)
	availability.text = " · ".join(counts)
	progress.text = tr("PEOPLE_COMMISSIONS_COMPLETED") % faction.completed_operations
	_refresh_members(faction)

func _refresh_members(faction: FactionState) -> void:
	for child in members_rows.get_children():
		members_rows.remove_child(child)
		child.queue_free()
	for member: NPC in faction.members:
		if not is_instance_valid(member):
			continue
		var row := MEMBER_ROW_SCENE.instantiate() as FactionMemberRowUI
		members_rows.add_child(row)
		row.setup(member)
		row.details_requested.connect(details_requested.emit.bind(member))
	empty_members.visible = members_rows.get_child_count() == 0

func _get_faction_info_tooltip(faction: FactionState) -> String:
	var lines: Array[String] = []
	lines.append(tr("UI_LABEL_VALUE") % [tr("HUB_FACTION_ROLES_LABEL"), ", ".join(faction.get_role_display_names())])
	lines.append(tr("UI_HEADING") % tr("HUB_FACTION_RESPONSIBILITIES_LABEL"))
	for responsibility: String in faction.get_responsibility_display_names():
		lines.append("- " + responsibility)
	return "\n".join(lines)
