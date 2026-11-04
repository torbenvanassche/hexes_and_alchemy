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
	return npc.get_display_name() if npc != null else tr("SCENE_ADVENTURER_NAME")

func _get_status_color(npc: NPC) -> Color:
	if npc == null:
		return GameUI.MUTED
	if npc.is_state(NPC.NPCState.RESTING):
		return GameUI.WARNING
	if not npc.is_state(NPC.NPCState.IDLE):
		return GameUI.TRAVEL
	return GameUI.SUCCESS
