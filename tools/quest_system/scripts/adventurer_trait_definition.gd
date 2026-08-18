class_name AdventurerTraitDefinition
extends Resource

@export var id: StringName = &""
@export var translation_key_name := ""
@export var job_score_modifiers: Dictionary[String, float] = {}
@export var risk_score_modifiers: Dictionary[String, float] = {}
@export var currency_reward_score_multiplier := 0.0

func get_display_name() -> String:
	if not translation_key_name.is_empty():
		var translated := tr(translation_key_name)
		if translated != translation_key_name:
			return translated
	return String(id).capitalize().replace("_", " ")

func get_quest_score(risk_key: String, job_keys: Array[String], offered_currency: int) -> float:
	var score := float(risk_score_modifiers.get(risk_key, 0.0))
	for job_key: String in job_keys:
		score += float(job_score_modifiers.get(job_key, 0.0))
	return score + float(offered_currency) * currency_reward_score_multiplier
