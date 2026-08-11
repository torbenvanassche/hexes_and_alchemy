class_name ScoutingQuestOutcome extends QuestOutcome

var observed_hex_ids: Array[Vector3i] = []
var revealed_hex_ids: Array[Vector3i] = []
var discovered_structure_ids: Dictionary[StringName, int] = {}

func record_hex(hex: HexBase) -> void:
	if hex == null or is_applied() or observed_hex_ids.has(hex.cube_id):
		return
	observed_hex_ids.append(hex.cube_id)

func apply(quest: Quest) -> void:
	if is_applied():
		return
	var grid := _get_active_grid()
	if grid == null:
		return

	revealed_hex_ids.clear()
	discovered_structure_ids.clear()
	for cube_id: Vector3i in observed_hex_ids:
		var hex := grid.get_hex_at_cube_id(cube_id)
		if hex == null or hex.is_explored:
			continue
		hex.is_explored = true
		revealed_hex_ids.append(cube_id)
		_record_structure(hex)

	super.apply(quest)

func get_revealed_tile_count() -> int:
	return revealed_hex_ids.size()

func get_discovered_structure_counts() -> Dictionary[String, int]:
	var result: Dictionary[String, int] = {}
	for structure_id: StringName in discovered_structure_ids:
		var display_name := _get_structure_display_name(structure_id)
		result[display_name] = int(result.get(display_name, 0)) + int(discovered_structure_ids[structure_id])
	return result

func get_summary() -> String:
	var tile_count := get_revealed_tile_count()
	if tile_count <= 0:
		return tr("QUEST_SCOUT_REPORT_NOTHING")

	var structures := get_discovered_structure_counts()
	if structures.is_empty():
		return tr("QUEST_SCOUT_REPORT_TILES") % [tile_count]

	var discoveries: Array[String] = []
	for display_name: String in structures:
		var count := int(structures[display_name])
		discoveries.append(display_name if count == 1 else "%s x%s" % [display_name, count])
	discoveries.sort()
	return tr("QUEST_SCOUT_REPORT_DISCOVERIES") % [tile_count, ", ".join(discoveries)]

func _record_structure(hex: HexBase) -> void:
	if hex.structure == null or hex.structure.structure_info == null:
		return
	var structure_id := StringName(hex.structure.structure_info.id)
	if structure_id == &"":
		return
	discovered_structure_ids[structure_id] = int(discovered_structure_ids.get(structure_id, 0)) + 1

func _get_structure_display_name(structure_id: StringName) -> String:
	if DataManager.instance != null:
		for structure_info: StructureInfo in DataManager.instance.structures:
			if structure_info != null and StringName(structure_info.id) == structure_id:
				return structure_info.get_display_name()
	return String(structure_id).capitalize()

func _get_active_grid() -> HexGrid:
	var active_scene := SceneManager.get_active_scene()
	if active_scene == null:
		return null
	return active_scene.node as HexGrid
