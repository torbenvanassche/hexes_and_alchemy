class_name SpotProgress
extends RefCounted

enum Stage {
	UNKNOWN,
	MAPPED,
	SURVEYED,
	DANGEROUS,
	SECURED,
	CLEARED,
	AVAILABLE,
	EXHAUSTED,
	INFESTED
}

var cube_id: Vector3i
var structure_id := ""
var stage: Stage = Stage.UNKNOWN
var danger_level := 0
var operation_count := 0
var last_operation_type := ""
var occupation: MonsterOccupationDefinition
var occupation_selection_resolved := false
var occupation_revealed := false

func _init(_cube_id: Vector3i, _structure_id: String = "") -> void:
	cube_id = _cube_id
	structure_id = _structure_id

func mark_mapped() -> void:
	if stage == Stage.UNKNOWN:
		stage = Stage.MAPPED

func mark_operation(operation_type: String) -> void:
	operation_count += 1
	last_operation_type = operation_type

func set_occupation(definition: MonsterOccupationDefinition, revealed: bool = false) -> void:
	occupation = definition
	occupation_selection_resolved = true
	occupation_revealed = revealed
	danger_level = definition.danger_level if definition != null else 0
	if revealed:
		stage = Stage.INFESTED if definition != null else Stage.SURVEYED

func resolve_no_occupation(revealed: bool = false) -> void:
	set_occupation(null, revealed)

func has_occupation() -> bool:
	return occupation != null

func is_occupation_revealed() -> bool:
	return occupation_revealed

func reveal_occupation() -> MonsterOccupationDefinition:
	occupation_selection_resolved = true
	occupation_revealed = true
	stage = Stage.INFESTED if occupation != null else Stage.SURVEYED
	return occupation

func clear_occupation(mark_secured: bool = true) -> MonsterOccupationDefinition:
	var cleared := occupation
	occupation = null
	occupation_selection_resolved = true
	occupation_revealed = true
	danger_level = 0
	if mark_secured:
		stage = Stage.SECURED
	return cleared

func get_stage_name() -> String:
	var translation_key := "SPOT_STAGE_%s" % Stage.keys()[stage]
	var translated := tr(translation_key)
	return Stage.keys()[stage].capitalize() if translated == translation_key else translated
