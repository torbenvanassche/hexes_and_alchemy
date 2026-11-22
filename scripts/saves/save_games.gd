extends Node

signal slots_changed()
signal load_finished(success: bool, message: String)
signal load_started()
var loading_progress := WorldGenerationProgress.new()

const VERSION := 2
const DIRECTORY := "user://saves"
const DEVELOPMENT_DIRECTORY := "res://development/checkpoints"
const DEVELOPMENT_CHECKPOINTS := [
	{"id": "arrival", "label": "01 · Fresh arrival", "description": "The opening settlement, starting guild and 100 coins. No campaign progress."},
	{"id": "foundation", "label": "02 · Forge foundation", "description": "Forge placed; 1 of 2 timber delivered. Gather the remaining timber and 5 iron ore."},
	{"id": "blacksmith", "label": "03 · Choose village requests", "description": "Blacksmith open, level 2, no village improvements yet. 250 coins, 4 prestige and supplies for testing."},
	{"id": "first_improvement", "label": "04 · One village improvement", "description": "Well built and water request complete. Choose a second request; the neighbouring village is not revealed yet."},
	{"id": "village_improved", "label": "05 · Village improved", "description": "Water and food requests complete. Discover the neighbour to begin the trade part of the chapter."},
	{"id": "trade_ready", "label": "06 · Ready for first shipment", "description": "Two improvements complete; village and route revealed. Dispatch the repair supplies from the journal Trade page."},
	{"id": "first_shipment", "label": "07 · Craft the partnership shipment", "description": "Repair delivery completed and horse returned. Craft the equipment for the second delivery."},
	{"id": "chapter_complete", "label": "08 · Opening chapter complete", "description": "Two improvements and trade partnership complete. Chapter grant paid once; continue upgrading or exploring."},
	{"id": "well_blueprint", "label": "Alt · Place the well", "description": "Water fieldwork complete and blueprint issued. Test placement and cancellation; construction supplies are in stores."},
	{"id": "well_foundation", "label": "Alt · Build the well", "description": "Well foundation placed. Deliver the construction supplies to finish the water request and activate its benefit."},
	{"id": "village", "label": "Alt · Village discovered early", "description": "Blacksmith open and village revealed, but no improvements. Test exploring or trading ahead of the suggested chapter order."},
	{"id": "trade_partner", "label": "Alt · Trade before improvements", "description": "Both deliveries complete and grain unlocked, with village requests still pending. Finish two requests to conclude the chapter."},
	{"id": "active_commission", "label": "Alt · Commission in progress", "description": "A paid forage commission is working. Auto-collect is off. Inspect resumed work, then collect its rewards."},
]
var history := SaveHistory.new()
var autosave_enabled := true
var autosave_minutes := 5
var _autosave_remaining := 300.0
var _autosave_index := 0
var _checkpoint_kind := "manual"
const SETTINGS_PATH := "user://save_preferences.cfg"
signal autosaved(label: String)
var is_loading := false
var last_error := ""
var _pending: Dictionary[String, Variant] = {}
var _old_manager_id := 0
var _restoring := false
var _load_started := 0

func is_restoring() -> bool:
	return _restoring

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_prepare_grid)
	_load_preferences()
	_register_shortcuts()

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
	return ""

func save_slot(label: String, kind := "manual") -> bool:
	_checkpoint_kind = kind
	last_error = save_block_reason()
	if not last_error.is_empty(): return false
	label = label.strip_edges()
	if label.is_empty(): label = "Quick save"
	var slot := slot_id(label if kind == "manual" else "@%s:%s" % [kind, label])
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
		if not history.archive(path, slot):
			last_error = history.last_error
			return false
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

func create_document(label: String, data: Dictionary[String, Variant]) -> Dictionary[String, Variant]:
	var payload := JSON.stringify(data, "", true, true)
	return {"version": VERSION, "kind": _checkpoint_kind, "label": label, "saved_at": Time.get_datetime_string_from_system(), "day": Manager.instance.time_of_day.get_day_number(), "stage": Manager.instance.campaign.stage, "payload": payload, "checksum": payload.sha256_text()}

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
		var damaged := not document is Dictionary
		if damaged and FileAccess.file_exists(DIRECTORY.path_join(filename) + ".bak"):
			document = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY.path_join(filename) + ".bak"))
		if document is Dictionary and int(document.get("version", 0)) in [1, VERSION]:
			result.append(TypedData.string_map({"slot": filename.trim_suffix(".json"), "label": ("[Damaged] " if damaged else "") + str(document.get("label", filename)), "saved_at": document.get("saved_at", ""), "day": document.get("day", 1), "kind": document.get("kind", "manual"), "backup": FileAccess.file_exists(DIRECTORY.path_join(filename) + ".bak")}))
	result.sort_custom(func(a: Dictionary[String, Variant], b: Dictionary[String, Variant]) -> bool: return str(a.saved_at) > str(b.saved_at))
	return result

func read_slot(slot: String) -> Dictionary[String, Variant]:
	last_error = ""
	if slot != slot.validate_filename() or slot.is_empty():
		last_error = "Invalid save slot."
		return {}
	return _read_document(_path(slot))

func _read_document(path: String) -> Dictionary[String, Variant]:
	last_error = ""
	if not FileAccess.file_exists(path):
		last_error = "This checkpoint no longer exists."
		return {}
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not document is Dictionary or not int(document.get("version", 0)) in [1, VERSION]:
		last_error = "This save is damaged or uses an unsupported version."
		return {}
	var payload: String = document.get("payload", "")
	if payload.sha256_text() != document.get("checksum", ""):
		last_error = "This save is incomplete or damaged. The previous backup is preserved."
		return {}
	var data: Variant = TypedData.json_value(JSON.parse_string(payload))
	if not data is Dictionary or not _validate_snapshot(data):
		last_error = "This save does not contain a complete game state."
		return {}
	if not _validate_resources(data):
		last_error = "This save references game content that is no longer available."
		return {}
	if int(data.get("schema_version", 1)) > SnapshotMigrations.CURRENT_SCHEMA:
		last_error = "This save requires a newer version of the game."
		return {}
	return SnapshotMigrations.upgrade(data)

func load_slot(slot: String) -> bool:
	return _load_data(read_slot(slot))

func _load_data(data: Dictionary[String, Variant]) -> bool:
	if is_loading:
		last_error = "A save is being loaded."
		return false
	if data.is_empty(): return false
	# Preserve the current session before replacing it, including development loads.
	if save_block_reason().is_empty() and not save_slot("Before rollback", "recovery"): return false
	_pending = data
	is_loading = true
	_autosave_remaining = autosave_minutes * 60.0
	loading_progress = WorldGenerationProgress.new()
	load_started.emit()
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
	if not _pending.world.settings.has("generation_version"): node.generation_version = 1
	node.world_seed = int(_pending.world.seed)
	node.generate_chunks_near_player = false
	node.initial_chunk_override.assign(codec.decode(_pending.world.chunks))

func _process(_delta: float) -> void:
	if not is_loading:
		_tick_autosave(_delta)
		return
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
	var success := await snapshot.restore(_pending, grid, loading_progress)
	grid.generate_chunks_near_player = bool(_pending.world.settings.get("generate_chunks_near_player", true))
	_pending.clear()
	_restoring = false
	is_loading = false
	get_tree().paused = false
	if success:
		Manager.instance.quests.resume_restored_commissions()
		Manager.instance.campaign.refresh()
		Manager.instance.regional.queue_refresh()
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

func _validate_snapshot(data: Dictionary[String, Variant]) -> bool:
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

func _valid_inventory(data: Dictionary[String, Variant]) -> bool:
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

func list_versions(slot: String) -> Array[Dictionary]:
	return history.list_versions(slot)

func load_version(id: String) -> bool:
	var path := history.path_for(id)
	if path.is_empty():
		last_error = "Invalid save version."
		return false
	return _load_data(_read_document(path))

func load_backup(slot: String) -> bool:
	if slot.is_empty() or slot != slot.validate_filename():
		last_error = "Invalid save slot."
		return false
	return _load_data(_read_document(_path(slot) + ".bak"))

func set_autosave(enabled: bool, minutes: int) -> void:
	autosave_enabled = enabled
	autosave_minutes = clampi(minutes, 1, 30)
	_autosave_remaining = autosave_minutes * 60.0
	var config := ConfigFile.new()
	config.set_value("autosave", "enabled", autosave_enabled)
	config.set_value("autosave", "minutes", autosave_minutes)
	config.set_value("autosave", "index", _autosave_index)
	config.save(SETTINGS_PATH)

func _load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		autosave_enabled = bool(config.get_value("autosave", "enabled", true))
		autosave_minutes = clampi(int(config.get_value("autosave", "minutes", 5)), 1, 30)
		_autosave_index = int(config.get_value("autosave", "index", 0)) % 5
	_autosave_remaining = autosave_minutes * 60.0

func _tick_autosave(delta: float) -> void:
	if not autosave_enabled or get_tree().paused or not is_instance_valid(Manager.instance): return
	_autosave_remaining -= delta
	if _autosave_remaining > 0.0: return
	if not save_block_reason().is_empty():
		_autosave_remaining = 5.0
		return
	var label := "Autosave %d" % (_autosave_index + 1)
	if save_slot(label, "auto"):
		_autosave_index = (_autosave_index + 1) % 5
		set_autosave(autosave_enabled, autosave_minutes)
		autosaved.emit(label)
	else:
		_autosave_remaining = 30.0

func _register_shortcuts() -> void:
	for binding: Array in [["quick_save", KEY_F5], ["quick_load", KEY_F9]]:
		if InputMap.has_action(binding[0]): continue
		InputMap.add_action(binding[0])
		var key := InputEventKey.new()
		key.physical_keycode = binding[1]
		InputMap.action_add_event(binding[0], key)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
	if is_loading: return
	_register_shortcuts()
	if not InputMap.has_action("quick_save") or not InputMap.has_action("quick_load"):
		return
	if event.is_action_pressed("quick_save"):
		var success := save_slot("Quick save", "quick")
		if is_instance_valid(Manager.instance) and Manager.instance.toast != null:
			Manager.instance.toast.notify("Quick save created." if success else last_error)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load"):
		if not load_slot(slot_id("@quick:Quick save")) and is_instance_valid(Manager.instance):
			Manager.instance.toast.notify(last_error, GameUI.WARNING)
		get_viewport().set_input_as_handled()
