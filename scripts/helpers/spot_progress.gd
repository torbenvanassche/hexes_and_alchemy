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

func _init(_cube_id: Vector3i, _structure_id: String = "") -> void:
	cube_id = _cube_id
	structure_id = _structure_id

func mark_mapped() -> void:
	if stage == Stage.UNKNOWN:
		stage = Stage.MAPPED

func mark_operation(operation_type: String) -> void:
	operation_count += 1
	last_operation_type = operation_type

func get_stage_name() -> String:
	return Stage.keys()[stage].capitalize()
