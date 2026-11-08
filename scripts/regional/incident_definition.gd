class_name IncidentDefinition
extends Resource

@export var id := ""
@export var title_key := ""
@export_multiline var description_key := ""
@export var site_kind := ""
@export var eligible_states: Array[String] = []
@export var problem_state := ""
@export var repair_types: Array[String] = []
@export var funding_cost := 35
@export var coin_reward := 20

func get_title() -> String:
	return tr(title_key)
