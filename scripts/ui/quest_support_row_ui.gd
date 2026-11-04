class_name QuestSupportRowUI
extends PanelContainer

signal selection_changed(definition: QuestSupportDefinition, selected: bool)

@onready var selection_toggle: CheckBox = $Margin/Content/SelectionToggle
@onready var support_name: Label = $Margin/Content/Copy/Header/SupportName
@onready var availability: Label = $Margin/Content/Copy/Header/Availability
@onready var description: Label = $Margin/Content/Copy/Description
@onready var impact: HBoxContainer = $Margin/Content/Copy/Impact
@onready var risk_icon: TextureRect = $Margin/Content/Copy/Impact/RiskIcon
@onready var risk_label: Label = $Margin/Content/Copy/Impact/RiskLabel
@onready var danger_label: Label = $Margin/Content/Copy/Impact/DangerLabel
@onready var danger_meter: HSlider = $Margin/Content/Copy/Impact/Danger
@onready var danger_value: Label = $Margin/Content/Copy/Impact/DangerValue

var definition: QuestSupportDefinition
var available_provider_count := -1
var _selected := false
var _suppress_toggle_signal := false

func _ready() -> void:
	selection_toggle.toggled.connect(_on_selection_toggled)
	_apply_data()

func setup(value: QuestSupportDefinition, selected: bool, provider_count: int) -> void:
	definition = value
	_selected = selected
	available_provider_count = provider_count
	if is_node_ready():
		_apply_data()

func is_selected() -> bool:
	return _selected

func _apply_data() -> void:
	if not is_node_ready():
		return
	var has_definition := definition != null
	visible = has_definition
	if not has_definition:
		return

	_suppress_toggle_signal = true
	selection_toggle.button_pressed = _selected
	_suppress_toggle_signal = false

	support_name.text = definition.get_display_name()
	var description_text := definition.get_description()
	description.text = description_text
	description.visible = description_text != ""

	var impact_text := _get_impact_text()
	impact.visible = impact_text != ""
	_refresh_effects()

	_refresh_availability()
	var tooltip_lines: Array[String] = [support_name.text]
	if description_text != "":
		tooltip_lines.append(description_text)
	if impact_text != "":
		tooltip_lines.append(impact_text)
	var tooltip := "\n".join(tooltip_lines)
	tooltip_text = tooltip
	selection_toggle.tooltip_text = tooltip

func _refresh_effects() -> void:
	var risk := definition.get_selected_risk_label()
	risk_icon.visible = not risk.is_empty()
	risk_label.visible = not risk.is_empty()
	var icon_name := "risk_uncertain"
	if definition.risk_key_when_selected == "QUEST_RISK_SAFE":
		icon_name = "risk_safe"
	elif definition.risk_key_when_selected == "QUEST_RISK_DANGEROUS":
		icon_name = "risk_dangerous"
	risk_icon.texture = load("res://sprites/ui/line/%s.svg" % icon_name)
	var risk_hint := tr("QUEST_SUPPORT_RISK_WHEN_SELECTED") % risk
	risk_icon.tooltip_text = risk_hint
	risk_label.tooltip_text = risk_hint
	var percent := roundi(definition.danger_weight_multiplier * 100.0)
	danger_meter.max_value = maxf(100, percent)
	danger_meter.value = percent
	danger_value.text = "%d%%" % percent
	var danger_hint := tr("QUEST_SUPPORT_DANGER_HINT") % percent
	for control: Control in [danger_label, danger_meter, danger_value]:
		control.tooltip_text = danger_hint

func _get_impact_text() -> String:
	if definition == null:
		return ""
	var parts: Array[String] = []
	var selected_risk := definition.get_selected_risk_label()
	if selected_risk != "":
		parts.append(tr("QUEST_SUPPORT_RISK_WHEN_SELECTED") % [selected_risk])
	if not is_equal_approx(definition.danger_weight_multiplier, 1.0):
		parts.append(tr("QUEST_SUPPORT_DANGER_WEIGHT") % [roundi(definition.danger_weight_multiplier * 100.0)])
	return " | ".join(parts)

func _refresh_availability() -> void:
	if definition == null or definition.provider_role == "" or available_provider_count < 0:
		availability.text = ""
		availability.visible = false
		return

	availability.visible = true
	if available_provider_count > 0:
		availability.text = tr("QUEST_SUPPORT_AVAILABLE_COUNT") % [available_provider_count]
		availability.modulate = GameUI.SUCCESS
	elif _selected:
		availability.text = tr("QUEST_SUPPORT_WILL_WAIT")
		availability.modulate = GameUI.WARNING
	else:
		availability.text = tr("QUEST_SUPPORT_NONE_AVAILABLE")
		availability.modulate = GameUI.MUTED

func _on_selection_toggled(selected: bool) -> void:
	if _suppress_toggle_signal or definition == null:
		return
	_selected = selected
	_refresh_availability()
	selection_changed.emit(definition, selected)
