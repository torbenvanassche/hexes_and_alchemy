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

func has_quest_for_location_and_type(location: HexBase, quest_type: String) -> bool:
	return active_quests.any(func(q: Quest) -> bool:
		return q != null and q.location == location and q.quest_key == quest_type
	);

func get_available_quest_types(location: HexBase, quest_types: Array[String]) -> Array[String]:
	var available_types: Array[String] = [];
	for quest_type: String in quest_types:
		if has_quest_for_location_and_type(location, quest_type):
			continue;
		if not has_eligible_npc_for_quest(location, quest_type):
			continue;
		available_types.append(quest_type);
	return available_types;

func has_eligible_npc_for_quest(location: HexBase, quest_type: String) -> bool:
	return not get_available_npcs_for_quest(location, quest_type).is_empty();

func get_available_npcs_for_quest(location: HexBase, quest_type: String) -> Array[SceneInstance]:
	var tavern := _get_active_tavern();
	if tavern == null:
		return [];

	var minimum_rank := _get_minimum_rank_for_quest(location, quest_type);
	var eligible_npcs: Array[SceneInstance] = [];
	for npc_scene_instance: SceneInstance in tavern.get_available_npcs():
		if _is_npc_instance_rank_eligible(npc_scene_instance, minimum_rank):
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

	for quest: Quest in active_quests:
		if quest == null or not quest.is_state(Quest.QuestState.WAITING) or not quest.party.is_empty():
			continue;
		if available_npcs.is_empty():
			return;

		var selected_npc_instance := _pop_first_eligible_npc(available_npcs, quest);
		if selected_npc_instance == null:
			continue;
		quest.add_to_party(selected_npc_instance.node as NPC);
		quest.start();

func _pop_first_eligible_npc(available_npcs: Array[SceneInstance], quest: Quest) -> SceneInstance:
	var minimum_rank := _get_minimum_rank_for_quest(quest.location, quest.quest_key);
	for i in available_npcs.size():
		var npc_scene_instance := available_npcs[i] as SceneInstance;
		if _is_npc_instance_rank_eligible(npc_scene_instance, minimum_rank):
			available_npcs.remove_at(i);
			return npc_scene_instance;
	return null;

func _is_npc_instance_rank_eligible(npc_scene_instance: SceneInstance, minimum_rank: AdventurerRank.Rank) -> bool:
	if npc_scene_instance == null:
		return false;
	var npc := npc_scene_instance.node as NPC;
	return npc != null and npc.is_rank_at_least(minimum_rank);

func _get_minimum_rank_for_quest(location: HexBase, quest_type: String) -> AdventurerRank.Rank:
	var objective := _get_quest_objective(location);
	if objective == null:
		return AdventurerRank.Rank.F;
	return objective.get_quest_minimum_rank(quest_type);

func _get_quest_objective(location: HexBase) -> QuestObjective:
	if location == null or location.structure == null:
		return null;
	return location.structure.instance as QuestObjective;

func _get_active_tavern() -> Tavern:
	if Manager.instance == null or Manager.instance.active_settlement == null:
		return null;

	for interaction: Interaction in Manager.instance.active_settlement.interactions:
		if interaction is Tavern:
			return interaction as Tavern;
	return null;
