class_name QuestManager extends Node

var active_quests: Array[Quest] = [];

signal quest_list_changed();
@warning_ignore("unused_signal")
signal quest_availability_changed();

@export_group("Limits")
@export var max_active_quest: int = 10;
@export var max_npc_per_tavern: int = 5;

@export_group("Generation")
@export var max_quest_distance: int = 50;
@export var max_scout_targets: int = 12;

func has_quest_for_location_and_type(location: HexBase, quest_type: String) -> bool:
	return active_quests.any(func(q: Quest) -> bool:
		return q != null and q.location == location and q.quest_key == quest_type
	);

func get_available_scout_locations(grid: HexGrid, limit_results: bool = true) -> Array[HexBase]:
	var origin_hex := get_active_quest_origin_hex(grid)
	if grid == null or origin_hex == null:
		return []

	var scout_locations: Array[HexBase] = []
	for scene_instance: SceneInstance in grid.get_tiles_in_radius(origin_hex.cube_id, max_quest_distance):
		var scout_hex := scene_instance.node as HexBase
		if not is_valid_scout_location(scout_hex, grid):
			continue
		if not is_quest_location_reachable(scout_hex, grid):
			continue

		scout_locations.append(scout_hex)

	scout_locations.sort_custom(func(a: HexBase, b: HexBase) -> bool:
		return GridUtils.cube_distance(origin_hex.cube_id, a.cube_id) < GridUtils.cube_distance(origin_hex.cube_id, b.cube_id)
	)
	if limit_results and max_scout_targets > 0 and scout_locations.size() > max_scout_targets:
		scout_locations.resize(max_scout_targets)

	return scout_locations

func get_scout_location_for_distance(grid: HexGrid, requested_distance: int) -> HexBase:
	var origin_hex := get_active_quest_origin_hex(grid)
	if grid == null or origin_hex == null:
		return null

	var scout_locations := get_available_scout_locations(grid, false)
	if scout_locations.is_empty():
		return null

	var target_distance := clampi(requested_distance, 1, max_quest_distance)
	scout_locations.sort_custom(func(a: HexBase, b: HexBase) -> bool:
		var distance_a := GridUtils.cube_distance(origin_hex.cube_id, a.cube_id)
		var distance_b := GridUtils.cube_distance(origin_hex.cube_id, b.cube_id)
		var delta_a := absi(distance_a - target_distance)
		var delta_b := absi(distance_b - target_distance)
		if delta_a == delta_b:
			return distance_a > distance_b
		return delta_a < delta_b
	)
	return scout_locations[0]

func is_valid_scout_location(location: HexBase, grid: HexGrid = null) -> bool:
	if location == null or location.is_explored or not location.is_visible_in_tree():
		return false
	if location.structure != null:
		return false
	if has_quest_for_location_and_type(location, "scout"):
		return false

	if grid == null:
		var active_scene := SceneManager.get_active_scene()
		if active_scene == null:
			return false
		grid = active_scene.node as HexGrid
	if grid == null:
		return false

	var origin_hex := get_active_quest_origin_hex(grid)
	if origin_hex == null:
		return false
	if GridUtils.cube_distance(origin_hex.cube_id, location.cube_id) > max_quest_distance:
		return false

	return _is_adjacent_to_explored_tile(location, grid)

func get_available_quest_types(
	location: HexBase,
	quest_types: Array[String],
	offered_currency_reward: int = 0,
	minimum_rank_override: int = -1
) -> Array[String]:
	var available_types: Array[String] = [];
	for quest_type: String in quest_types:
		if has_quest_for_location_and_type(location, quest_type):
			continue;
		if not has_eligible_npc_for_quest(location, quest_type, offered_currency_reward, minimum_rank_override):
			continue;
		available_types.append(quest_type);
	return available_types;

func get_postable_quest_types(location: HexBase, quest_types: Array[String]) -> Array[String]:
	var postable_types: Array[String] = []
	for quest_type: String in quest_types:
		if has_quest_for_location_and_type(location, quest_type):
			continue
		postable_types.append(quest_type)
	return postable_types

func has_eligible_npc_for_quest(
	location: HexBase,
	quest_type: String,
	offered_currency_reward: int = 0,
	minimum_rank_override: int = -1
) -> bool:
	return not get_available_npcs_for_quest(
		location,
		quest_type,
		offered_currency_reward,
		minimum_rank_override
	).is_empty();

func get_available_npcs_for_quest(
	location: HexBase,
	quest_type: String,
	offered_currency_reward: int = 0,
	minimum_rank_override: int = -1
) -> Array[SceneInstance]:
	var tavern := _get_active_tavern();
	if tavern == null:
		return [];

	var quest_offer := Quest.new(location, quest_type, offered_currency_reward, minimum_rank_override)
	var eligible_npcs: Array[SceneInstance] = [];
	for npc_scene_instance: SceneInstance in tavern.get_available_npcs():
		var npc := _get_npc_from_instance(npc_scene_instance)
		if npc != null and npc.wants_quest(quest_offer):
			eligible_npcs.append(npc_scene_instance);
	return eligible_npcs;

func get_active_quest_origin_hex(grid: HexGrid) -> HexBase:
	if grid == null:
		return null

	var tavern := _get_active_tavern()
	if tavern != null:
		var origin := tavern.global_position
		if tavern.adventurer_spawn != null:
			origin = tavern.adventurer_spawn.global_position

		var tavern_hex := grid.get_hex_at_world_position(origin)
		if tavern_hex != null:
			return tavern_hex

	if Manager.instance != null and Manager.instance.player_instance != null:
		return Manager.instance.player_instance.get_hex()

	return null

func is_quest_location_reachable(location: HexBase, grid: HexGrid = null) -> bool:
	if location == null:
		return false

	if grid == null:
		var active_scene := SceneManager.get_active_scene()
		if active_scene == null:
			return false
		grid = active_scene.node as HexGrid
	if grid == null:
		return false

	var origin_hex := get_active_quest_origin_hex(grid)
	if origin_hex == null:
		return false

	if _active_settlement_allows_boat_travel():
		return not grid.pathfinder.get_hex_path_for_methods(
			origin_hex.cube_id,
			location.cube_id,
			[HexInfo.TraversalTag.WALK, HexInfo.TraversalTag.BOAT]
		).is_empty()
	return not grid.pathfinder.get_hex_path(origin_hex.cube_id, location.cube_id).is_empty()

func add_quest(q: Quest) -> void:
	if active_quests.size() >= max_active_quest:
		return;
	if not active_quests.has(q):
		active_quests.append(q);
		quest_list_changed.emit();
		try_assign_waiting_quests();

func remove_quest(q: Quest) -> void:
	active_quests.erase(q);
	quest_list_changed.emit();

func try_assign_waiting_quests() -> void:
	var tavern := _get_active_tavern();
	if tavern == null:
		return;

	var available_npcs := tavern.get_available_npcs();
	if available_npcs.is_empty():
		return;

	var waiting_quests := _get_waiting_quests()
	if waiting_quests.is_empty():
		return

	var assigned_quests := 0
	for npc_scene_instance: SceneInstance in available_npcs:
		if waiting_quests.is_empty():
			break
		var npc := _get_npc_from_instance(npc_scene_instance)
		if npc == null:
			continue;
		var selected_quest := _get_best_quest_for_npc(npc, waiting_quests)
		if selected_quest == null:
			continue
		selected_quest.add_to_party(npc)
		selected_quest.start()
		waiting_quests.erase(selected_quest)
		assigned_quests += 1

	if assigned_quests > 0:
		quest_list_changed.emit()

func _get_waiting_quests() -> Array[Quest]:
	var waiting_quests: Array[Quest] = []
	for quest: Quest in active_quests:
		if quest != null and quest.is_state(Quest.QuestState.WAITING) and quest.party.is_empty():
			waiting_quests.append(quest)
	return waiting_quests

func _get_best_quest_for_npc(npc: NPC, waiting_quests: Array[Quest]) -> Quest:
	var best_quest: Quest = null
	var best_score := 0.0
	for quest: Quest in waiting_quests:
		var score := npc.evaluate_quest(quest)
		if score > best_score:
			best_score = score
			best_quest = quest
	if best_quest == null or not npc.wants_quest(best_quest):
		return null
	return best_quest

func _get_npc_from_instance(npc_scene_instance: SceneInstance) -> NPC:
	if npc_scene_instance == null:
		return null
	return npc_scene_instance.node as NPC

func _get_active_tavern() -> Tavern:
	if Manager.instance == null or Manager.instance.active_settlement == null:
		return null;

	for interaction: Interaction in Manager.instance.active_settlement.interactions:
		if interaction is Tavern:
			return interaction as Tavern;
	return null;

func _active_settlement_allows_boat_travel() -> bool:
	return (
		Manager.instance != null
		and Manager.instance.active_settlement != null
		and Manager.instance.active_settlement.has_service(&"Shipyard")
	)

func _is_adjacent_to_explored_tile(location: HexBase, grid: HexGrid) -> bool:
	for direction: Vector3i in DataManager.instance.CUBE_DIRS:
		var neighbor := grid.get_hex_at_cube_id(location.cube_id + direction)
		if neighbor != null and neighbor.is_explored:
			return true
	return false
