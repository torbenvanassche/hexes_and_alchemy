class_name FactionMemberRowUI
extends PanelContainer

@onready var name_label: Label = $Margin/Columns/Name
@onready var role_label: Label = $Margin/Columns/Role
@onready var activity_label: Label = $Margin/Columns/Activity

func setup(npc: NPC) -> void:
	if npc == null:
		return
	if not is_node_ready():
		call_deferred("setup", npc)
		return
	name_label.text = _get_npc_display_name(npc)
	role_label.text = npc.get_role_label()
	activity_label.text = _get_activity_label(npc)
	name_label.tooltip_text = name_label.text
	role_label.tooltip_text = role_label.text
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
		return Color(0.55, 0.38, 0.16, 1)
	if not npc.is_state(NPC.NPCState.IDLE):
		return Color(0.18, 0.42, 0.62, 1)
	return Color(0.18, 0.5, 0.34, 1)
