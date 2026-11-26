class_name QuestListItemUI extends VBoxContainer

signal details_requested(quest: Quest, expanded: bool)

@export var column_header := false

@onready var title_label: Label = $Margin/Columns/Commission/Title
@onready var target_label: Label = $Margin/Columns/Commission/Target
@onready var crew_label: Label = $Margin/Columns/Crew
@onready var status_label: Label = $Margin/Columns/Status
@onready var details_button: Button = $Margin/Columns/Actions/Details
@onready var collect_button: Button = $Margin/Columns/Actions/CollectSlot/Collect
@onready var details_panel: PanelContainer = $DetailsPanel
@onready var summary_label: Label = $DetailsPanel/Content/Summary
@onready var detail_crew: Label = $DetailsPanel/Content/Facts/Crew
@onready var detail_payment: Label = $DetailsPanel/Content/Facts/Payment
@onready var detail_risk: Label = $DetailsPanel/Content/Facts/Risk

var quest: Quest
var _refresh_gate: RefreshGate

func _ready() -> void:
	if column_header:
		$Margin/Columns.custom_minimum_size.y = 28
		title_label.text = "QUEST_COMMISSION_COLUMN_TITLE"
		crew_label.text = "QUEST_COMMISSION_COLUMN_CREW"
		status_label.text = "QUEST_COMMISSION_COLUMN_STATUS"
		for heading: Label in [title_label, crew_label, status_label]:
			heading.theme_type_variation = &"SectionHeading"
			heading.uppercase = true
		target_label.hide()
		details_button.hide()
		return
	_refresh_gate = RefreshGate.new(self, refresh)
	details_button.toggled.connect(func(expanded: bool) -> void:
		details_requested.emit(quest, expanded)
	)
	collect_button.pressed.connect(func() -> void: quest.parse_reward())

func setup(value: Quest) -> void:
	quest = value
	quest.state_machine.state_entered.connect(_queue_refresh.unbind(1))
	refresh()

func _queue_refresh() -> void:
	_refresh_gate.request()

func refresh() -> void:
	if quest == null or SaveGames.is_loading:
		return
	title_label.text = get_title(quest)
	target_label.text = get_target(quest)
	crew_label.text = get_crew(quest)
	status_label.text = get_status(quest)
	status_label.add_theme_color_override("font_color", QuestStatePresentation.get_color(quest.state_machine.get_current_state()))
	collect_button.visible = quest.is_state(Quest.QuestState.COMPLETE)
	for label: Label in [title_label, target_label, crew_label, status_label]:
		label.tooltip_text = label.text
	if details_panel.visible:
		_refresh_details()

func set_expanded(expanded: bool) -> void:
	details_button.set_pressed_no_signal(expanded)
	details_panel.visible = expanded
	if expanded:
		_refresh_details()

func _refresh_details() -> void:
	var complete := quest.is_state(Quest.QuestState.COMPLETE)
	var profile := quest.get_profile()
	summary_label.text = quest.outcome.get_summary() if complete and quest.outcome != null else ""
	if summary_label.text.is_empty() and profile != null:
		summary_label.text = profile.get_description()
	summary_label.visible = not summary_label.text.is_empty()
	detail_crew.text = tr("QUEST_COMMISSION_CREW_DETAIL") % crew_label.text
	detail_payment.text = tr("QUEST_PAYMENT_OFFERED") % quest.get_offered_currency_reward()
	var risk_key := quest.get_effective_risk_key()
	detail_risk.visible = not risk_key.is_empty()
	detail_risk.text = tr("QUEST_DETAIL_RISK") % tr(risk_key) if detail_risk.visible else ""

static func get_title(commission: Quest) -> String:
	var profile := commission.get_profile()
	if profile != null:
		return profile.get_display_name()
	var key := "QUEST_TYPE_%s" % commission.quest_key.to_upper()
	var title := str(TranslationServer.translate(key))
	return commission.quest_key.capitalize() if title == key else title

static func get_target(commission: Quest) -> String:
	if commission.quest_key == "scout":
		var direction_key := str(commission.context.get("scout_direction_key", ""))
		var direction := str(TranslationServer.translate(direction_key)) if not direction_key.is_empty() else ""
		var distance := int(commission.context.get("scout_distance", 0))
		if not direction.is_empty() and direction != direction_key and distance > 0:
			return TranslationServer.translate("QUEST_LOCATION_SCOUT_BOARD") % [direction, distance]
		return TranslationServer.translate("QUEST_LOCATION_UNCHARTED_FRONTIER")
	var location := commission.location
	if is_instance_valid(location) and location.structure != null and location.structure.structure_info != null:
		return location.structure.structure_info.get_display_name()
	return TranslationServer.translate("UNKNOWN")

static func get_crew(commission: Quest) -> String:
	var names := PackedStringArray()
	for member: NPC in commission.party:
		if is_instance_valid(member):
			names.append(member.get_display_name())
	return TranslationServer.translate("QUEST_PARTY_UNASSIGNED") if names.is_empty() else ", ".join(names)

static func get_status(commission: Quest) -> String:
	var state := commission.state_machine.get_current_state()
	if state == "waiting":
		var departure_day := commission.get_scout_departure_day()
		if departure_day > Manager.instance.time_of_day.get_day_number():
			return TranslationServer.translate("QUEST_SCOUT_SCHEDULED") % departure_day
	if state == "complete":
		return TranslationServer.translate("QUEST_COMMISSION_READY_TO_COLLECT")
	var key := "QUEST_STATE_%s" % state.to_upper()
	var status := str(TranslationServer.translate(key))
	return state.capitalize() if status == key else status
