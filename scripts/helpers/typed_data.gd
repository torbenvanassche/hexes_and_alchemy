class_name TypedData
extends RefCounted

## Convert engine/JSON dictionaries at the boundary, before using typed maps.
static func string_map(value: Variant) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = {}
	if value is Dictionary: result.assign(value)
	return result

## JSON objects always have string keys. Arrays retain their JSON element types.
static func json_value(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary[String, Variant] = {}
		for key: String in value: result[key] = json_value(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value: result.append(json_value(entry))
		return result
	return value
