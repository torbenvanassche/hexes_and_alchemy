class_name FileUtils

static func load_json(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		printerr("File does not exist: %s" % file_path)
		return {}
	var data_file := FileAccess.open(file_path, FileAccess.READ)
	if data_file == null:
		printerr("Could not open file: %s" % file_path)
		return {}
	var parsed_result: Variant = JSON.parse_string(data_file.get_as_text())
	if parsed_result is Dictionary:
		return parsed_result as Dictionary
	printerr("Expected a JSON object in file: %s" % file_path)
	return {}

static func load_items(file_path: String) -> Dictionary:
	var parsed_result := load_json(file_path)
	for item_id: Variant in parsed_result:
		var item: Variant = parsed_result[item_id]
		if item is Dictionary:
			(item as Dictionary)["id"] = item_id
	return parsed_result

static func get_item(dict: Dictionary, item_name: String) -> Dictionary:
	for value: Variant in dict.values():
		var item := value as Dictionary
		if item != null and str(item.get("name", "")) == item_name:
			return item
	return {}

static func get_resource_paths(folder_path: String) -> Array[String]:
	var file_paths: Array[String] = []
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return file_paths
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var file_path := folder_path.path_join(file_name)
			if dir.current_is_dir():
				file_paths.append_array(get_resource_paths(file_path))
			else:
				file_paths.append(file_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return file_paths
