class_name TavernRosterRowUI
extends HBoxContainer

signal details_requested()

@onready var name_label: Label = $Name
@onready var profession_label: Label = $Profession
@onready var rank_label: Label = $Rank
@onready var status_label: Label = $Status
@onready var details_button: Button = $Details

func _ready() -> void:
	if not details_button.pressed.is_connected(_on_details_pressed):
		details_button.pressed.connect(_on_details_pressed)

func setup(npc: NPC) -> void:
	if npc == null:
		return
	if not is_node_ready():
		call_deferred("setup", npc)
		return
	name_label.text = _get_npc_display_name(npc)
	profession_label.text = npc.get_profession_label()
	rank_label.text = tr("ADVENTURER_ROSTER_RANK") % npc.get_rank_progress_label()
	status_label.text = npc.get_activity_status_label()
	status_label.add_theme_color_override("font_color", _get_status_color(npc))

func _on_details_pressed() -> void:
	details_requested.emit()

func _get_npc_display_name(npc: NPC) -> String:
	if npc == null or npc.npc_info == null:
		return tr("SCENE_ADVENTURER_NAME")
	var display_name := npc.npc_info.get_display_name()
	return tr("SCENE_ADVENTURER_NAME") if display_name == npc.npc_info.id.capitalize() else display_name

func _get_status_color(npc: NPC) -> Color:
	if npc == null:
		return Color(0.42, 0.31, 0.2, 1)
	if npc.is_state(NPC.NPCState.RESTING):
		return Color(0.55, 0.38, 0.16, 1)
	if npc.current_quest != null:
		return Color(0.18, 0.42, 0.62, 1)
	return Color(0.18, 0.5, 0.34, 1)
