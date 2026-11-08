class_name DiscoveryDefinition
extends Resource

enum Occupation { KEEP, NONE, PRESENT }
@export var id := ""
@export var site_kind := ""
@export_range(0.0, 100.0, 0.1) var weight := 1.0
@export var title_key := ""
@export_multiline var description_key := ""
@export var initial_state := ""
@export var occupation: Occupation = Occupation.KEEP
@export var safe_for_opening := false
## Damaged/occupied sites are kept apart to avoid chains of mandatory repairs.
@export var is_disruption := false

func get_text() -> String:
	return "%s — %s" % [tr(title_key), tr(description_key)]
