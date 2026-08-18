class_name FactionDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var roles: Array[String] = []
@export var responsibilities: Array[String] = []
@export var preferred_quest_types: Array[String] = []
@export_range(0.25, 4.0, 0.05) var rest_multiplier := 1.0

func get_display_name() -> String:
	var translation_key := "FACTION_%s_NAME" % id.to_upper()
	var translated := tr(translation_key)
	if translated != translation_key:
		return translated
	return display_name if not display_name.is_empty() else String(id).capitalize()

func get_role_display_names() -> Array[String]:
	var labels: Array[String] = []
	for role_name: String in roles:
		var translation_key := "QUEST_ROLE_%s" % role_name.to_upper()
		var translated := tr(translation_key)
		labels.append(role_name.capitalize().replace("_", " ") if translated == translation_key else translated)
	return labels

func get_responsibility_display_names() -> Array[String]:
	var labels: Array[String] = []
	for responsibility_key: String in responsibilities:
		var translated := tr(responsibility_key)
		labels.append(responsibility_key if translated == responsibility_key else translated)
	return labels

func supports_role(role_name: String) -> bool:
	return roles.has(role_name)

func get_recovery_duration(base_duration: float) -> float:
	return maxf(0.0, base_duration) * rest_multiplier

func prefers_quest(quest: Quest) -> bool:
	if quest == null:
		return false
	if preferred_quest_types.has(quest.quest_key):
		return true
	var profile := quest.get_profile()
	return profile != null and preferred_quest_types.has(profile.get_behaviour())
