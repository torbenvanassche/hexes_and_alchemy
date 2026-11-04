extends Node

signal slots_changed()
signal load_finished(success: bool, message: String)

const VERSION := 1
const DIRECTORY := "user://saves"
const DEVELOPMENT_DIRECTORY := "res://development/checkpoints"
const DEVELOPMENT_CHECKPOINTS := [
	{"id": "arrival", "label": "01 · Fresh arrival", "description": "The opening settlement, starting guild and 100 coins. No campaign progress."},
	{"id": "foundation", "label": "02 · Forge foundation", "description": "Forge placed; 1 of 2 timber delivered. Gather the remaining timber and 5 iron ore."},
	{"id": "blacksmith", "label": "03 · Blacksmith open", "description": "Level 2 settlement with a working blacksmith, basic supplies and 250 coins for testing."},
	{"id": "village", "label": "04 · Neighbouring village", "description": "The neighbouring village and route are revealed. Start at its entrance with the level 2 settlement established."},
]
var is_loading := false
var last_error := ""
var _pending: Dictionary = {}
var _old_manager_id := 0
var _restoring := false
var _load_started := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_prepare_grid)

func save_block_reason() -> String:
	if is_loading: return "A save is being loaded."
	if not is_instance_valid(Manager.instance): return "The world is not ready."
	if not is_instance_valid(Manager.instance.player_instance) or not is_instance_valid(Manager.instance.active_settlement):
		return "The world is not ready."
	var active := SceneManager.get_active_scene()
	if not is_instance_valid(active) or not is_instance_valid(active.node) or not active.node is MainGrid or not active.node.initialized:
		return "The world is not ready."
	var grid := active.node as MainGrid
	if grid.is_streaming_busy(): return "The world is still generating. Resume briefly before saving."
	if not Manager.instance.quests.active_quests.is_empty():
		return "Finish or cancel commissions and collect their rewards before saving this checkpoint."
	return ""

func save_slot(label: String) -> bool:
	last_error = save_block_reason()
	if not last_error.is_empty(): return false
	label = label.strip_edges()
	if label.is_empty(): label = "Quick save"
	var slot := slot_id(label)
	var snapshot := GameSnapshot.new()
	var data := snapshot.capture(SceneManager.get_active_scene().node as MainGrid)
	if not snapshot.codec.errors.is_empty():
		last_error = "; ".join(snapshot.codec.errors)
		return false
	var document := create_document(label, data)
	if DirAccess.make_dir_recursive_absolute(DIRECTORY) != OK:
		last_error = "Could not create the saves folder."
		return false
	var path := _path(slot)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Could not write the save file."
		return false
	file.store_string(JSON.stringify(document))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		last_error = "The save could not be written completely."
		return false
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"): DirAccess.remove_absolute(path + ".bak")
		if DirAccess.rename_absolute(path, path + ".bak") != OK:
			last_error = "Could not back up the previous checkpoint."
			return false
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		if FileAccess.file_exists(path + ".bak"): DirAccess.rename_absolute(path + ".bak", path)
		last_error = "Could not finish writing the checkpoint."
		return false
	slots_changed.emit()
	return true

func create_document(label: String, data: Dictionary) -> Dictionary:
	var payload := JSON.stringify(data, "", true, true)
	return {"version": VERSION, "label": label, "saved_at": Time.get_datetime_string_from_system(), "day": Manager.instance.time_of_day.get_day_number(), "stage": Manager.instance.campaign.stage, "payload": payload, "checksum": payload.sha256_text()}

func list_development_checkpoints() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not OS.is_debug_build(): return result
	for definition in DEVELOPMENT_CHECKPOINTS:
		if FileAccess.file_exists(DEVELOPMENT_DIRECTORY.path_join(definition.id + ".json")):
			result.append(definition.duplicate())
	return result

func load_development_checkpoint(id: String) -> bool:
	if not OS.is_debug_build():
		last_error = "Development checkpoints are available in debug builds."
		return false
	for definition in DEVELOPMENT_CHECKPOINTS:
		if definition.id == id:
			return _load_data(_read_document(DEVELOPMENT_DIRECTORY.path_join(id + ".json")))
	last_error = "Unknown development checkpoint."
	return false

func list_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(DIRECTORY): return result
	for filename: String in DirAccess.get_files_at(DIRECTORY):
		if not filename.ends_with(".json"): continue
		var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY.path_join(filename)))
		if document is Dictionary and document.get("version") == VERSION:
			result.append({"slot": filename.trim_suffix(".json"), "label": document.get("label", filename), "saved_at": document.get("saved_at", ""), "day": document.get("day", 1)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.saved_at) > str(b.saved_at))
	return result

func read_slot(slot: String) -> Dictionary:
	last_error = ""
	if slot != slot.validate_filename() or slot.is_empty():
		last_error = "Invalid save slot."
		return {}
	return _read_document(_path(slot))

func _read_document(path: String) -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(path):
		last_error = "This checkpoint no longer exists."
		return {}
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not document is Dictionary or document.get("version") != VERSION:
		last_error = "This save is damaged or uses an unsupported version."
		return {}
	var payload: String = document.get("payload", "")
	if payload.sha256_text() != document.get("checksum", ""):
		last_error = "This save is incomplete or damaged. The previous backup is preserved."
		return {}
	var data: Variant = JSON.parse_string(payload)
	if not data is Dictionary or not _validate_snapshot(data):
		last_error = "This save does not contain a complete game state."
		return {}
	if not _validate_resources(data):
		last_error = "This save references game content that is no longer available."
		return {}
	return data

func load_slot(slot: String) -> bool:
	return _load_data(read_slot(slot))

func _load_data(data: Dictionary) -> bool:
	if is_loading:
		last_error = "A save is being loaded."
		return false
	if data.is_empty(): return false
	_pending = data
	is_loading = true
	_load_started = Time.get_ticks_msec()
	_old_manager_id = Manager.instance.get_instance_id() if is_instance_valid(Manager.instance) else 0
	get_tree().paused = false
	Engine.time_scale = 1.0
	var main_scene := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	if get_tree().change_scene_to_packed(main_scene) != OK:
		_fail_load("Could not open the game world.")
		return false
	return true

func _prepare_grid(node: Node) -> void:
	if not is_loading or not node is MainGrid: return
	var codec := SaveCodec.new()
	codec.apply_fields(node, _pending.world.settings)
	node.world_seed = int(_pending.world.seed)
	node.generate_chunks_near_player = false
	node.initial_chunk_override.assign(codec.decode(_pending.world.chunks))

func _process(_delta: float) -> void:
	if not is_loading: return
	if Time.get_ticks_msec() - _load_started > 60000:
		_fail_load("The saved world could not finish loading.")
		return
	if _restoring: return
	if not is_instance_valid(Manager.instance) or Manager.instance.get_instance_id() == _old_manager_id: return
	var active := SceneManager.get_active_scene()
	if active == null or not is_instance_valid(active.node) or not active.node is MainGrid: return
	var grid := active.node as MainGrid
	if not grid.initialized or grid.is_streaming_busy() or not is_instance_valid(Manager.instance.player_instance): return
	_restoring = true
	_restore.call_deferred(grid)

func _restore(grid: MainGrid) -> void:
	get_tree().paused = true
	for frame in 3: await get_tree().process_frame
	var snapshot := GameSnapshot.new()
	var success := await snapshot.restore(_pending, grid)
	grid.generate_chunks_near_player = bool(_pending.world.settings.get("generate_chunks_near_player", true))
	_pending.clear()
	_restoring = false
	is_loading = false
	get_tree().paused = false
	if success:
		Manager.instance.toast.notify_report("Checkpoint loaded")
		load_finished.emit(true, "Checkpoint loaded")
	else:
		_fail_load("The checkpoint could not be restored completely.")

func _fail_load(message: String) -> void:
	last_error = message
	_pending.clear()
	is_loading = false
	_restoring = false
	get_tree().paused = false
	if is_instance_valid(Manager.instance) and is_instance_valid(Manager.instance.toast):
		Manager.instance.toast.notify_report(message)
	load_finished.emit(false, message)

func _validate_snapshot(data: Dictionary) -> bool:
	for key: String in ["world", "hub", "inventory", "journal", "factions", "reputation", "time", "player", "campaign"]:
		if not data.get(key) is Dictionary: return false
	if not data.get("roster") is Array or not data.get("history") is Array: return false
	if not data.world.has_all(["seed", "settings", "chunks", "tiles"]): return false
	if not data.world.settings is Dictionary or not data.world.chunks is Array or data.world.chunks.is_empty(): return false
	if not data.world.tiles is Array or data.world.tiles.is_empty(): return false
	if not data.player.has_all(["position", "settlement"]) or not _valid_inventory(data.inventory): return false
	for row in data.world.tiles:
		if not row is Dictionary or not row.has_all(["coord", "tile", "elevation", "explored", "reserved", "blocked", "terrain"]): return false
		if not row.terrain is Dictionary: return false
		if row.has("structure"):
			if not row.has_all(["position", "rotation", "nodes"]) or not row.nodes is Array: return false
			for state in row.nodes:
				if not state is Dictionary or not state.has_all(["path", "fields"]) or not state.fields is Dictionary: return false
				if state.has("delivery") and not state.delivery.is_empty() and not _valid_inventory(state.delivery): return false
	for row in data.roster:
		if not row is Dictionary or not row.has_all(["id", "home", "fields"]) or not row.fields is Dictionary: return false
		if not row.fields.has_all(["npc_info", "recruited_display_name"]): return false
	for row in data.history:
		if not row is Dictionary or not row.has_all(["quest_id", "location", "type", "state", "context", "fields", "operation"]): return false
	return true

func _valid_inventory(data: Dictionary) -> bool:
	if not data.has_all(["stack", "slots"]) or not data.slots is Array: return false
	for slot in data.slots:
		if not slot is Dictionary or not slot.has_all(["item", "count", "max", "unlocked"]): return false
	return true

func _validate_resources(value: Variant) -> bool:
	if value is Array:
		for item in value:
			if not _validate_resources(item): return false
	elif value is Dictionary:
		for key: String in ["$resource", "$object"]:
			if value.has(key):
				var path: String = value[key]
				if not path.begins_with("res://") or not ResourceLoader.exists(path): return false
		for item in value.values():
			if not _validate_resources(item): return false
	return true

func slot_id(label: String) -> String:
	return label.strip_edges().to_lower().sha256_text().substr(0, 24)

func _path(slot: String) -> String:
	return DIRECTORY.path_join(slot + ".json")
