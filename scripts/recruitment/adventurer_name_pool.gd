class_name AdventurerNamePool
extends Resource

@export var first_names: Array[String] = []
@export var last_names: Array[String] = []
@export_range(1, 100, 1) var collision_attempts := 12

func generate_name(rng: RandomNumberGenerator) -> String:
	if rng == null or first_names.is_empty():
		return ""
	var first_name := first_names[rng.randi_range(0, first_names.size() - 1)]
	if last_names.is_empty():
		return first_name
	var last_name := last_names[rng.randi_range(0, last_names.size() - 1)]
	return "%s %s" % [first_name, last_name]

func generate_available_name(
	rng: RandomNumberGenerator,
	used_names: Array[String],
	fallback_serial: int
) -> String:
	for _attempt in collision_attempts:
		var candidate_name := generate_name(rng)
		if candidate_name.is_empty():
			return ""
		if not used_names.has(candidate_name):
			return candidate_name
	var first_name := _get_random_first_name(rng)
	return tr("NPC_GENERATED_NAME_NUMBERED") % [first_name, fallback_serial] if not first_name.is_empty() else ""

func _get_random_first_name(rng: RandomNumberGenerator) -> String:
	if rng == null or first_names.is_empty():
		return ""
	return first_names[rng.randi_range(0, first_names.size() - 1)]
