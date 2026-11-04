class_name FactionMemberRowUI
extends PanelContainer

signal details_requested()

@onready var name_label: Label = $Margin/Columns/Name
@onready var role_label: Label = $Margin/Columns/Role
@onready var rank_label: Label = $Margin/Columns/Rank
@onready var activity_label: Label = $Margin/Columns/Status/Activity
@onready var injury_label: Label = $Margin/Columns/Status/Injury
@onready var details_button: Button = $Margin/Columns/Details

func _ready() -> void:
	details_button.pressed.connect(details_requested.emit)

func setup(npc: NPC) -> void:
	if npc == null:
		return
	if not is_node_ready():
		call_deferred("setup", npc)
		return
	name_label.text = _get_npc_display_name(npc)
	role_label.text = npc.get_role_label()
	rank_label.text = AdventurerRank.get_display_name(npc.rank)
	rank_label.tooltip_text = npc.get_rank_progress_label()
	injury_label.visible = not npc.active_injuries.is_empty()
	injury_label.text = tr("PEOPLE_INJURED")
	injury_label.tooltip_text = npc.get_injuries_label()
	injury_label.add_theme_color_override("font_color", GameUI.DANGER)
	details_button.tooltip_text = tr("PEOPLE_VIEW_PROFILE") % npc.get_display_name()
	activity_label.text = _get_activity_label(npc)
	name_label.tooltip_text = name_label.text
	role_label.tooltip_text = "%s · %s" % [npc.get_profession_label(), role_label.text]
	activity_label.tooltip_text = activity_label.text
	activity_label.add_theme_color_override("font_color", _get_status_color(npc))

func _get_activity_label(npc: NPC) -> String:
	var status := npc.get_activity_status_label()
	if npc.current_quest != null:
		return tr("HUB_MEMBER_ACTIVITY_QUEST") % [status, _get_quest_label(npc.current_quest)]
	return status

func _get_quest_label(quest: Quest) -> String:
	var profile := quest.get_profile()
	if profile != null:
		return profile.get_display_name()
	var translation_key := "QUEST_TYPE_%s" % quest.quest_key.to_upper()
	var translated := tr(translation_key)
	return quest.quest_key.capitalize() if translated == translation_key else translated

func _get_npc_display_name(npc: NPC) -> String:
	return npc.get_display_name()

func _get_status_color(npc: NPC) -> Color:
	if npc.is_state(NPC.NPCState.RESTING):
		return GameUI.WARNING
	if not npc.is_state(NPC.NPCState.IDLE):
		return GameUI.TRAVEL
	return GameUI.SUCCESS
