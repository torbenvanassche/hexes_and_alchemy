class_name SaveHistory
extends RefCounted

const DIRECTORY := "user://saves/history"
var last_error := ""

func archive(path: String, slot: String, limit := 8) -> bool:
	last_error = ""
	if not FileAccess.file_exists(path): return true
	if DirAccess.make_dir_recursive_absolute(DIRECTORY) != OK:
		last_error = "Could not create save history."
		return false
	var id := "%s_%s_%s" % [slot, str(Time.get_unix_time_from_system()).replace(".", "_"), str(Time.get_ticks_usec())]
	if DirAccess.copy_absolute(path, DIRECTORY.path_join(id + ".json")) != OK:
		last_error = "Could not preserve the previous save version."
		return false
	var versions := list_versions(slot)
	for index in range(limit, versions.size()):
		DirAccess.remove_absolute(DIRECTORY.path_join(versions[index].id + ".json"))
	return true

func list_versions(slot: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(DIRECTORY): return result
	for filename: String in DirAccess.get_files_at(DIRECTORY):
		if not filename.begins_with(slot + "_") or not filename.ends_with(".json"): continue
		var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY.path_join(filename)))
		if document is Dictionary:
			result.append({"id": filename.trim_suffix(".json"), "saved_at": document.get("saved_at", ""), "label": document.get("label", slot), "day": document.get("day", 1)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.saved_at == b.saved_at: return str(a.id) > str(b.id)
		return str(a.saved_at) > str(b.saved_at))
	return result

func path_for(id: String) -> String:
	if id.is_empty() or id != id.validate_filename() or id.contains("/"): return ""
	return DIRECTORY.path_join(id + ".json")
