class_name AdventurerInjury extends Resource

@export var id: StringName = &"injury"
@export var translation_key_name := ""
@export var translation_key_description := ""
@export_range(1, 3, 1) var severity := 1
@export_range(1, 100, 1) var treatment_cost := 10
@export_range(0.25, 1.0, 0.05) var success_weight_multiplier := 1.0
@export_range(1.0, 3.0, 0.05) var danger_weight_multiplier := 1.0
@export_range(1.0, 3.0, 0.05) var injury_chance_multiplier := 1.0
@export_range(1.0, 3.0, 0.05) var death_chance_multiplier := 1.0
@export_range(1.0, 3.0, 0.05) var quest_duration_multiplier := 1.0
@export_range(0.25, 1.0, 0.05) var loot_quantity_multiplier := 1.0

func get_display_name() -> String:
	var translated := tr(translation_key_name)
	return String(id).capitalize() if translation_key_name.is_empty() or translated == translation_key_name else translated

func get_description() -> String:
	var translated := tr(translation_key_description)
	return "" if translation_key_description.is_empty() or translated == translation_key_description else translated
