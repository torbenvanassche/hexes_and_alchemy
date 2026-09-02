class_name QuestManager extends Node

var active_quests: Array[Quest] = [];

signal quest_list_changed();
@warning_ignore("unused_signal")
signal quest_availability_changed();
signal quest_added(quest: Quest)
signal quest_removed(quest: Quest)
signal quest_failed(quest: Quest, reason_key: String)
signal quest_cancelled(quest: Quest, reason_key: String)
signal quest_state_changed(quest: Quest, state: String)

@export_group("Limits")
@export var max_active_quest: int = 10;

@export_group("Generation")
@export var max_quest_distance: int = 50;
@export var max_scout_targets: int = 12;
@export_range(0.0, 1.0, 0.01) var scout_direction_weight: float = 0.65;

func has_quest_for_location_and_type(location: HexBase, quest_type: String) -> bool:
	return active_quests.any(func(q: Quest) -> bool:
		return q != null and q.location == location and q.quest_key == quest_type
	);

func has_quests_for_location(location: HexBase) -> bool:
	return not get_quests_for_location(location).is_empty()

func get_quests_for_location(location: HexBase) -> Array[Quest]:
	var quests: Array[Quest] = []
	if location == null:
		return quests
	for quest: Quest in active_quests:
		if quest != null and quest.location == location:
			quests.append(quest)
	return quests

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

func get_scout_location_for_direction_and_distance(
	grid: HexGrid,
	direction_index: int,
	requested_distance: int
) -> HexBase:
	var origin_hex := get_active_quest_origin_hex(grid)
	if grid == null or origin_hex == null:
		return null

	var scout_locations := get_available_scout_locations(grid, false)
	if scout_locations.is_empty():
		return null

	var directions := DataManager.instance.CUBE_DIRS
	if direction_index < 0 or direction_index >= directions.size():
		return get_scout_location_for_distance(grid, requested_distance)

	var target_distance := clampi(requested_distance, 1, max_quest_distance)
	var direction: Vector3i = directions[direction_index]
	var ideal_cube := origin_hex.cube_id + Vector3i(
		direction.x * target_distance,
		direction.y * target_distance,
		direction.z * target_distance
	)
	scout_locations.sort_custom(func(a: HexBase, b: HexBase) -> bool:
		var score_a := _get_scout_direction_score(origin_hex.cube_id, a.cube_id, ideal_cube, target_distance)
		var score_b := _get_scout_direction_score(origin_hex.cube_id, b.cube_id, ideal_cube, target_distance)
		if is_equal_approx(score_a, score_b):
			return GridUtils.cube_distance(origin_hex.cube_id, a.cube_id) > GridUtils.cube_distance(origin_hex.cube_id, b.cube_id)
		return score_a < score_b
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

	return true

func get_available_quest_types(
	location: HexBase,
	quest_types: Array[String],
	offered_currency_reward: int = 0,
	minimum_rank_override: int = -1
) -> Array[String]:
	if active_quests.size() >= max_active_quest:
		return []
	if has_quests_for_location(location):
		return []
	var available_types: Array[String] = [];
	for quest_type: String in quest_types:
		if has_quest_for_location_and_type(location, quest_type):
			continue;
		if not has_eligible_npc_for_quest(location, quest_type, offered_currency_reward, minimum_rank_override):
			continue;
		available_types.append(quest_type);
	return available_types;

func get_postable_quest_types(location: HexBase, quest_types: Array[String]) -> Array[String]:
	if active_quests.size() >= max_active_quest:
		return []
	if has_quests_for_location(location):
		return []
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
	var quest_offer := Quest.new(location, quest_type, offered_currency_reward, minimum_rank_override)
	var eligible_npcs: Array[SceneInstance] = [];
	for npc_scene_instance: SceneInstance in _get_available_faction_members():
		var npc := _get_npc_from_instance(npc_scene_instance)
		if npc != null and npc.wants_quest(quest_offer):
			eligible_npcs.append(npc_scene_instance);
	return eligible_npcs;

func get_available_npcs_for_role(role: String, minimum_rank: int = 0) -> Array[SceneInstance]:
	var eligible: Array[SceneInstance] = []
	var required_rank := AdventurerRank.clamp_rank(minimum_rank)
	for npc_scene_instance: SceneInstance in _get_available_faction_members():
		var npc := _get_npc_from_instance(npc_scene_instance)
		if npc != null and npc.can_perform_role(role) and npc.is_rank_at_least(required_rank):
			eligible.append(npc_scene_instance)
	return eligible

func get_available_support_provider_count(quest: Quest, definition: QuestSupportDefinition) -> int:
	if quest == null or definition == null:
		return 0
	var available: Array[NPC] = []
	for npc_scene_instance: SceneInstance in _get_available_faction_members():
		var npc := _get_npc_from_instance(npc_scene_instance)
		if npc != null:
			available.append(npc)

	var highest_count := 0
	for primary: NPC in available:
		if primary == null or not primary.wants_quest(quest):
			continue
		var provider_count := 0
		for support_npc: NPC in available:
			if support_npc == primary:
				continue
			if support_npc.can_consider_quest_for_role(quest, definition.provider_role):
				provider_count += 1
		highest_count = maxi(highest_count, provider_count)
	return highest_count

func get_active_quest_origin_hex(grid: HexGrid) -> HexBase:
	if grid == null:
		return null

	if Manager.instance != null and Manager.instance.active_settlement != null:
		var settlement := Manager.instance.active_settlement
		var origin := settlement.global_position
		if settlement.spawn_position != null:
			origin = settlement.spawn_position.global_position
		var settlement_hex := grid.get_hex_at_world_position(origin)
		if settlement_hex != null:
			return settlement_hex

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

func get_posting_error(q: Quest) -> String:
	if q == null or q.location == null or q.quest_key == "":
		return "QUEST_POST_LOCATION_UNAVAILABLE"
	if active_quests.size() >= max_active_quest:
		return "QUEST_POST_LIMIT_REACHED"
	if has_quests_for_location(q.location):
		return "QUEST_POST_LOCATION_UNAVAILABLE"
	return ""

func add_quest(q: Quest) -> bool:
	if get_posting_error(q) != "":
		return false
	if not active_quests.has(q):
		active_quests.append(q);
		var state_callable := _on_quest_state_changed.bind(q)
		if not q.state_machine.state_entered.is_connected(state_callable):
			q.state_machine.state_entered.connect(state_callable)
		if Manager.instance != null and Manager.instance.operations != null:
			Manager.instance.operations.register_quest(q, str(q.context.get("parent_operation_id", "")))
		quest_added.emit(q)
		quest_list_changed.emit();
		quest_availability_changed.emit()
		try_assign_waiting_quests();
		return true
	return false

func remove_quest(q: Quest) -> void:
	if not active_quests.has(q):
		return
	var state_callable := _on_quest_state_changed.bind(q)
	if q != null and q.state_machine.state_entered.is_connected(state_callable):
		q.state_machine.state_entered.disconnect(state_callable)
	active_quests.erase(q);
	quest_removed.emit(q)
	quest_list_changed.emit();
	quest_availability_changed.emit()

func _on_quest_state_changed(state: String, quest: Quest) -> void:
	quest_state_changed.emit(quest, state)

func release_quest_supplies(quest: Quest) -> void:
	if quest == null or not quest.context.get("supplies_reserved", false):
		return
	var source := quest.context.get("supply_source") as ContentGroup
	if source == null and Manager.instance != null and Manager.instance.hub != null:
		source = Manager.instance.hub.stockpile
	if source != null and quest.supplies != null:
		quest.supplies.transfer_all_to(source, _get_inventory_contents(quest.supplies), true)
	quest.context["supplies_reserved"] = false

func refund_quest_reward(quest: Quest) -> void:
	if quest == null or not quest.context.get("reward_reserved", false):
		return
	var amount := quest.get_offered_currency_reward()
	var source: Variant = quest.context.get("reward_source")
	if source is HubState:
		(source as HubState).add_currency(amount)
	elif source is PlayerController:
		(source as PlayerController).currency += amount
	quest.context["reward_reserved"] = false

func fail_quest(quest: Quest, reason_key: String) -> void:
	if quest == null or quest.is_state(Quest.QuestState.FAILED) or quest.is_state(Quest.QuestState.CANCELLED):
		return
	_cancel_party(quest)
	release_quest_supplies(quest)
	refund_quest_reward(quest)
	quest.mark_failed(reason_key)
	quest_failed.emit(quest, reason_key)
	remove_quest(quest)

func cancel_quest(quest: Quest, reason_key: String = "QUEST_CANCELLED") -> void:
	if quest == null or quest.is_state(Quest.QuestState.COMPLETE) or quest.is_state(Quest.QuestState.CANCELLED):
		return
	_cancel_party(quest)
	release_quest_supplies(quest)
	refund_quest_reward(quest)
	quest.mark_cancelled(reason_key)
	quest_cancelled.emit(quest, reason_key)
	remove_quest(quest)

func _cancel_party(quest: Quest) -> void:
	for npc: NPC in quest.party.duplicate():
		if npc != null:
			if npc.arrived.is_connected(quest._check_party_arrived_at_quest):
				npc.arrived.disconnect(quest._check_party_arrived_at_quest)
			if npc.arrived.is_connected(quest.return_completed):
				npc.arrived.disconnect(quest.return_completed)
			if npc.movement_failed.is_connected(quest._on_party_movement_failed):
				npc.movement_failed.disconnect(quest._on_party_movement_failed)
			npc.cancel_assigned_quest(quest)
	quest.clear_party_assignments()

func _get_inventory_contents(inventory: ContentGroup) -> Dictionary:
	var amounts: Dictionary = {}
	if inventory == null:
		return amounts
	for slot: ContentSlotResource in inventory.data:
		if slot == null or slot.get_content() == null or slot.count <= 0:
			continue
		var content := slot.get_content()
		amounts[content] = int(amounts.get(content, 0)) + slot.count
	return amounts

func try_assign_waiting_quests() -> void:
	var available_npcs: Array[NPC] = []
	for npc_scene_instance: SceneInstance in _get_available_faction_members():
		var available_npc := _get_npc_from_instance(npc_scene_instance)
		if available_npc != null:
			available_npcs.append(available_npc)
	if available_npcs.is_empty():
		return;

	var waiting_quests := _get_waiting_quests()
	if waiting_quests.is_empty():
		return

	var assigned_quests := 0
	while not available_npcs.is_empty() and not waiting_quests.is_empty():
		var best_assignment: Dictionary = {}
		for quest: Quest in waiting_quests:
			var assignment := _build_party_assignment(quest, available_npcs)
			if assignment.is_empty():
				continue
			if best_assignment.is_empty() or float(assignment.get("score", 0.0)) > float(best_assignment.get("score", 0.0)):
				best_assignment = assignment

		if best_assignment.is_empty():
			break

		var selected_quest := best_assignment.get("quest") as Quest
		if selected_quest == null:
			break
		if not _reserve_quest_supplies(selected_quest):
			waiting_quests.erase(selected_quest)
			continue
		if not _commit_party_assignment(best_assignment):
			release_quest_supplies(selected_quest)
			waiting_quests.erase(selected_quest)
			continue

		for assigned_npc: NPC in best_assignment.get("members", []):
			available_npcs.erase(assigned_npc)
		selected_quest.start()
		waiting_quests.erase(selected_quest)
		assigned_quests += 1

	if assigned_quests > 0:
		quest_list_changed.emit()

func _reserve_quest_supplies(quest: Quest) -> bool:
	if quest == null or quest.context.get("supplies_reserved", false):
		return true
	var objective := quest.get_objective()
	if objective == null:
		fail_quest(quest, "QUEST_FAILED_MISSING_OBJECTIVE")
		return false
	if Manager.instance == null or Manager.instance.hub == null:
		return false
	if not objective.assign_required_supplies(quest, Manager.instance.hub.stockpile):
		return false
	quest.context["supplies_reserved"] = true
	quest.context["supply_source"] = Manager.instance.hub.stockpile
	return true

func _get_waiting_quests() -> Array[Quest]:
	var waiting_quests: Array[Quest] = []
	for quest: Quest in active_quests:
		if quest != null and quest.is_state(Quest.QuestState.WAITING) and quest.party.is_empty():
			waiting_quests.append(quest)
	return waiting_quests

func _build_party_assignment(quest: Quest, available_npcs: Array[NPC]) -> Dictionary:
	if quest == null:
		return {}

	var best_assignment: Dictionary = {}
	for primary: NPC in available_npcs:
		if primary == null or not primary.wants_quest(quest):
			continue

		var remaining := available_npcs.duplicate()
		remaining.erase(primary)
		var support_assignments: Dictionary[StringName, NPC] = {}
		var members: Array[NPC] = [primary]
		var score := primary.evaluate_quest(quest)
		var complete := true

		for definition: QuestSupportDefinition in quest.get_selected_support_definitions():
			var support_npc := _get_best_support_npc(quest, definition, remaining)
			if support_npc == null:
				complete = false
				break
			support_assignments[definition.id] = support_npc
			members.append(support_npc)
			remaining.erase(support_npc)
			score += support_npc.evaluate_quest_for_role(quest, definition.provider_role) * 0.25

		if not complete:
			continue
		if best_assignment.is_empty() or score > float(best_assignment.get("score", 0.0)):
			best_assignment = {
				"quest": quest,
				"primary": primary,
				"supports": support_assignments,
				"members": members,
				"score": score,
			}
	return best_assignment

func _get_best_support_npc(
	quest: Quest,
	definition: QuestSupportDefinition,
	available_npcs: Array[NPC]
) -> NPC:
	if definition == null or definition.provider_role == "":
		return null
	var best_npc: NPC = null
	var best_score := -1.0
	for npc: NPC in available_npcs:
		if npc == null or not npc.can_consider_quest_for_role(quest, definition.provider_role):
			continue
		var score := npc.evaluate_quest_for_role(quest, definition.provider_role)
		if best_npc == null or score > best_score:
			best_npc = npc
			best_score = score
	return best_npc

func _commit_party_assignment(assignment: Dictionary) -> bool:
	var quest := assignment.get("quest") as Quest
	var primary := assignment.get("primary") as NPC
	if quest == null or primary == null or not quest.add_to_party(primary):
		return false

	var supports: Dictionary = assignment.get("supports", {})
	for support_id: StringName in supports:
		var support_npc := supports[support_id] as NPC
		if support_npc != null and quest.add_to_party(support_npc, support_id):
			continue
		for assigned_npc: NPC in quest.party.duplicate():
			if assigned_npc != null:
				assigned_npc.cancel_assigned_quest(quest)
		quest.clear_party_assignments()
		return false
	return true

func _get_npc_from_instance(npc_scene_instance: SceneInstance) -> NPC:
	if npc_scene_instance == null:
		return null
	return npc_scene_instance.node as NPC

func _get_active_faction_homes() -> Array[FactionHome]:
	var homes: Array[FactionHome] = []
	if Manager.instance == null or Manager.instance.active_settlement == null:
		return homes

	for interaction: Interaction in Manager.instance.active_settlement.interactions:
		var home := interaction as FactionHome
		if home != null:
			homes.append(home)
	return homes

func _get_available_faction_members() -> Array[SceneInstance]:
	var members: Array[SceneInstance] = []
	for home: FactionHome in _get_active_faction_homes():
		members.append_array(home.get_available_npcs())
	return members

func _active_settlement_allows_boat_travel() -> bool:
	return (
		Manager.instance != null
		and Manager.instance.active_settlement != null
		and Manager.instance.active_settlement.has_service(&"Shipyard")
	)

func _get_scout_direction_score(
	origin_cube: Vector3i,
	candidate_cube: Vector3i,
	ideal_cube: Vector3i,
	target_distance: int
) -> float:
	var candidate_distance := GridUtils.cube_distance(origin_cube, candidate_cube)
	var distance_delta := absi(candidate_distance - target_distance)
	var direction_delta := GridUtils.cube_distance(candidate_cube, ideal_cube)
	return float(distance_delta) * (1.0 - scout_direction_weight) + float(direction_delta) * scout_direction_weight
