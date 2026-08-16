class_name RecruitCandidateRowUI
extends VBoxContainer

signal hire_requested(candidate: RecruitCandidate)

@onready var name_label: Label = $Primary/Name
@onready var faction_label: Label = $Primary/Faction
@onready var profession_label: Label = $Primary/Profession
@onready var rank_label: Label = $Primary/Rank
@onready var cost_label: Label = $Primary/Cost
@onready var hire_button: Button = $Primary/Hire

var candidate: RecruitCandidate
var tavern: Tavern

func _ready() -> void:
	if not hire_button.pressed.is_connected(_on_hire_pressed):
		hire_button.pressed.connect(_on_hire_pressed)

func setup(value: RecruitCandidate, source_tavern: Tavern) -> void:
	candidate = value
	tavern = source_tavern
	if not is_node_ready():
		call_deferred("setup", value, source_tavern)
		return
	if candidate == null:
		return
	name_label.text = candidate.display_name
	faction_label.text = candidate.get_faction_name()
	profession_label.text = candidate.get_profession_name()
	rank_label.text = candidate.get_rank_name()
	cost_label.text = str(candidate.hire_cost)
	tooltip_text = ""
	name_label.tooltip_text = name_label.text
	faction_label.tooltip_text = faction_label.text
	profession_label.tooltip_text = profession_label.text
	rank_label.tooltip_text = tr("RECRUITMENT_RANK_LINE") % candidate.get_rank_name()
	cost_label.tooltip_text = tr("RECRUITMENT_COST_LINE") % candidate.hire_cost
	refresh_availability()

func refresh_availability() -> void:
	if candidate == null or tavern == null or not is_instance_valid(tavern):
		hire_button.disabled = true
		return
	var block_key := tavern.get_hire_block_key(candidate)
	hire_button.disabled = not block_key.is_empty()
	hire_button.tooltip_text = tr(block_key) if not block_key.is_empty() else tr("RECRUITMENT_HIRE_TOOLTIP")

func _on_hire_pressed() -> void:
	if candidate != null:
		hire_requested.emit(candidate)
