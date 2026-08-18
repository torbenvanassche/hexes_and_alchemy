class_name MonsterOccupationDefinition
extends Resource

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export var translation_key_name: String = ""
@export_multiline var description: String = ""
@export var description_key: String = ""
@export var icon: Texture2D

@export_group("Selection")
@export_range(0.0, 100.0, 0.05, "or_greater") var spawn_weight := 1.0

@export_group("Threat")
@export var difficulty: AdventurerRank.Rank = AdventurerRank.Rank.F
@export_range(0, 10, 1, "or_greater") var danger_level := 1
@export_range(0.0, 10.0, 0.05, "or_greater") var danger_weight_multiplier := 1.0
@export_range(0.25, 4.0, 0.05, "or_greater") var security_duration_multiplier := 1.0
@export var defeat_loot_table: LootTable

@export_group("Reports")
@export var spotted_message_key: String = ""
@export var cleared_message_key: String = ""

func get_display_name() -> String:
	if translation_key_name != "":
		var translated := tr(translation_key_name)
		if translated != translation_key_name:
			return translated
	if display_name != "":
		return display_name
	return String(id).capitalize()

func get_description() -> String:
	if description_key != "":
		var translated := tr(description_key)
		if translated != description_key:
			return translated
	return description

func get_difficulty() -> AdventurerRank.Rank:
	return AdventurerRank.clamp_rank(difficulty)

func get_security_duration(base_duration: float) -> float:
	return maxf(0.0, base_duration) * security_duration_multiplier
