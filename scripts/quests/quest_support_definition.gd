class_name QuestSupportDefinition
extends Resource

@export var id: StringName = &""
@export var provider_role: String = ""
@export var name_key: String = ""
@export_multiline var description_key: String = ""
@export var selected_by_default := false
@export_range(0.0, 4.0, 0.01) var danger_weight_multiplier := 1.0
@export var risk_key_when_selected: String = ""

func get_display_name() -> String:
	if name_key != "":
		var translated := tr(name_key)
		if translated != name_key:
			return translated
	return str(id).capitalize().replace("_", " ")

func get_description() -> String:
	if description_key == "":
		return ""
	var translated := tr(description_key)
	return "" if translated == description_key else translated

func get_selected_risk_label() -> String:
	if risk_key_when_selected == "":
		return ""
	var translated := tr(risk_key_when_selected)
	return risk_key_when_selected.replace("QUEST_RISK_", "").capitalize().replace("_", " ") if translated == risk_key_when_selected else translated
