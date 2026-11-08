class_name GameSnapshot
extends RefCounted

const WORLD_SETTINGS := ["generation_version", "world_chunk_radius", "startup_work_budget_ms", "same_discovery_spacing", "discovery_repeat_penalty", "structure_candidates_per_step", "discovery_variation_radius", "discovery_variant_repeat_penalty", "disruption_spacing", "generate_chunks_near_player", "player_settlement", "chunk_radius", "chunk_size", "pointy_top", "_spacing", "generate_elevation", "elevation_unit_height", "elevation_feature_cell_size", "elevation_feature_density", "elevation_min_radius", "elevation_max_radius", "keep_protected_chunks_flat", "protected_chunk_elevation_buffer", "generate_slope_entrances", "slope_entrance_density", "minimum_slope_entrances_per_area", "elevated_tiles_per_extra_slope_entrance", "custom_regions", "use_global_regions", "generate_ocean", "protected_chunks", "protected_chunk_feature_buffer", "settlement_feature_buffer", "required_starting_structures", "required_structure_max_walk_distance", "repair_failed_starter_terrain", "nearby_settlement", "settlement_min_walk_distance", "settlement_max_walk_distance"]
const NPC_FIELDS := ["npc_info", "recruited_display_name", "recruited_traits", "has_recruited_traits", "rank", "rank_experience", "equipment", "earned_currency", "rest_remaining_seconds", "rest_duration_seconds", "recovering_from_injury", "active_injuries", "career_age_seconds", "retirement_pending", "last_completed_quest_key"]
const SITE_FIELDS := ["state_machine", "depth", "_last_stable_state", "_pending_reward", "_pending_behaviour", "_pending_outcome", "_pending_reveal_occupation", "_loot_claimed", "lost_equipment", "lost_adventurer_names", "_regrow_timer", "_overgrow_timer", "_wither_timer", "candidates", "_candidate_serial", "_name_serial", "_next_natural_arrival_operation", "_rng", "buy_inventory", "sell_inventory", "transport_stable_tile", "transport_stable_approach"]
const HUB_FIELDS := ["currency", "prestige", "spots", "activity_log"]
const REGIONAL_FIELDS := ["projects", "unlocked_recipes", "resolved_incidents", "active_incident", "completed_commissions", "expeditions_completed", "chapter_complete", "incident_remaining", "incident_serial", "selected_project"]
const DISCOVERY_FIELDS := ["discovery_id", "discovery_resolved", "salvaged_remnants", "reinforced_uses", "temporary_supports", "protected_uses", "archive_recorded"]
const REPUTATION_FIELDS := ["reputation", "notoriety", "stewardship", "regional_hazard", "completed_quests", "supported_world_sites"]
const HISTORY_FIELDS := ["offered_currency_reward", "minimum_rank_override", "rank_experience_reward", "scout_revealed_tiles", "scout_discovered_structures", "outcome", "party", "primary_member", "support_members", "party_fates", "supplies", "required_cargo", "work_remaining"]
const TERRAIN_FIELDS := ["rotation", "movement_cost", "generated_elevation_units", "structure_root_tile", "asset_uphill_edge", "slope_rise_units", "connector_mask", "navigation_only_mask", "edge_height_offsets"]

var codec := SaveCodec.new()

func capture(grid: MainGrid) -> Dictionary[String, Variant]:
	codec.grid = grid
	var manager := Manager.instance
	var roster: Array = []
	for settlement: Settlement in manager.settlements:
		for home: FactionHome in settlement.get_services(&"FactionHome"):
			for member: SceneInstance in home.get_roster_npcs():
				var npc := member.node as NPC
				roster.append(TypedData.string_map({"id": str(npc.get_instance_id()), "home": codec.encode(home), "fields": codec.fields(npc, NPC_FIELDS)}))
	var tiles: Array = []
	for coord: Vector3i in grid.tiles:
		var hex := grid.get_hex_at_cube_id(coord)
		var entry: Dictionary[String, Variant] = {"coord": codec.encode(coord), "tile": codec.encode(hex.scene_instance.scene_info), "elevation": hex.elevation_units, "explored": hex.is_explored, "reserved": not hex.can_generate, "blocked": hex.blocked}
		entry["terrain"] = codec.fields(hex, TERRAIN_FIELDS)
		# Passage repairs and settlement footprints can change a tile's biome.
		# Re-generating the same seed alone cannot reconstruct those edits.
		entry["region"] = codec.encode(hex.region)
		if hex.structure != null:
			var root := hex.structure.instance as Node3D
			entry["structure"] = codec.encode(hex.structure.structure_info)
			entry["position"] = codec.encode(root.position)
			entry["rotation"] = codec.encode(root.rotation)
			entry["nodes"] = _capture_structure(root)
		tiles.append(entry)
	var history: Array = []
	for operation: HubOperation in manager.operations.operations:
		var quest := operation.quest
		if quest == null: continue
		var positions: Dictionary[String, Variant] = {}
		for member: NPC in quest.party:
			if is_instance_valid(member): positions[str(member.get_instance_id())] = codec.encode(member.global_position)
		history.append(TypedData.string_map({"quest_id": str(quest.get_instance_id()), "location": codec.encode(quest.location), "type": quest.quest_key, "state": quest.state_machine.get_current_state(), "context": codec.encode(quest.context), "fields": codec.fields(quest, HISTORY_FIELDS), "operation": codec.fields(operation), "active": manager.quests.active_quests.has(quest), "positions": positions}))
	var journal: Dictionary[String, Variant] = {}
	for entry: JournalEntry in manager.journal.entries:
		var tasks: Dictionary[String, bool] = {}
		for task: JournalTask in entry.get_tasks(): tasks[task.id] = task.completed
		journal[entry.id] = {"unlocked": entry.unlocked, "tasks": tasks}
	var factions: Dictionary[StringName, Dictionary] = {}
	for faction: FactionState in manager.hub.factions.values():
		factions[str(faction.id)] = codec.fields(faction, ["completed_operations", "failed_operations", "last_activity"])
	var active_hex := manager.active_settlement.get_parent() as HexBase
	return {
		"world": {
			"seed": str(grid.generation_seed),
			"settings": codec.fields(grid, WORLD_SETTINGS),
			"chunks": codec.encode(grid.chunks.keys()),
			"tiles": tiles,
		},
		"roster": roster,
		"history": history,
		"operation_settings": codec.fields(manager.operations, ["auto_resolve_completed_quests"]),
		"hub": codec.fields(manager.hub, HUB_FIELDS),
		"inventory": codec.inventory(manager.hub.stockpile),
		"factions": factions,
		"journal": journal,
		"reputation": codec.fields(manager.reputation, REPUTATION_FIELDS),
		"time": codec.fields(manager.time_of_day, ["days", "_time"]),
		"player": {"position": codec.encode(manager.player_instance.global_position), "settlement": codec.encode(active_hex.cube_id)},
		"campaign": codec.fields(manager.campaign, ["_completion_announced", "_chapter_completion_announced", "destination", "destination_name", "trade_destination"]),
		"transport": codec.fields(manager.transport, ["villages", "active_shipment", "carrier"]),
		"crafting": codec.fields(manager.crafting, ["active_job"]),
		"regional": codec.fields(manager.regional, REGIONAL_FIELDS),
	}

func _capture_structure(root: Node3D) -> Array:
	var rows: Array = []
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "Node", true, false))
	for node: Node in nodes:
		if not (node is Settlement or node is Interaction or node is Buildable): continue
		var row: Dictionary[String, Variant] = {"path": str(root.get_path_to(node)), "fields": codec.fields(node, SITE_FIELDS)}
		row.fields.merge(codec.fields(node, DISCOVERY_FIELDS))
		if node.has_method("rebuild_boundary"):
			row.fields.merge(codec.fields(node, ["gate_inside", "gate_outside", "gate_open"]))
		if node is Settlement:
			row["level"] = node.level
			row["expanded"] = codec.encode(node.expanded_tiles)
		if node is Buildable: row["build_step"] = node.build_steps.find(node.current_step)
		if node is BuildRequest and node.quest != null:
			row["delivery"] = codec.inventory(node.quest.progress_tracker) if node.quest.progress_tracker != null else {}
		rows.append(row)
	return rows

func restore(data: Dictionary[String, Variant], grid: MainGrid, progress: WorldGenerationProgress = null) -> bool:
	if progress != null: progress.report(0.0, "LOADING_RESTORING")
	codec.grid = grid
	var manager := Manager.instance
	codec.apply_fields(manager.operations, TypedData.string_map(data.get("operation_settings", {})))
	# Remove default NPCs before restoring the roster. Recruitment events are muted
	# while loading; they must not create emergency recruits or assign commissions.
	for settlement: Settlement in manager.settlements.duplicate():
		for home: FactionHome in settlement.get_services(&"FactionHome"):
			for member: SceneInstance in home.get_roster_npcs(): member.destroy()
	await manager.get_tree().process_frame
	# Restore terrain first. Changed structures are removed before replacements so
	# named child paths remain stable and each settlement unregisters cleanly.
	for row in data.world.tiles:
		var coord: Vector3i = codec.decode(row.coord)
		var hex := grid.get_hex_at_cube_id(coord)
		if hex == null: return false
		var info := codec.decode(row.tile) as HexInfo
		var saved_region := codec.decode(row.get("region")) as RegionInfo
		if saved_region != null: grid.set_hex_region(hex, saved_region)
		var wanted := codec.decode(row.get("structure")) as StructureInfo
		if hex.structure != null and (hex.scene_instance.scene_info != info or hex.structure.structure_info != wanted):
			hex.structure.destroy()
			hex.structure = null
			hex.region_instance.unregister_structure(coord)
		if hex.scene_instance.scene_info != info:
			grid.replace(hex.scene_instance, info.get_instance(), hex.region)
			hex = grid.get_hex_at_cube_id(coord)
		hex.set_elevation(int(row.elevation), grid.elevation_unit_height)
		codec.apply_fields(hex, row.terrain)
		grid.generated_elevations[hex.grid_id] = hex.generated_elevation_units
	await manager.get_tree().process_frame
	# Restore ownership before registering newly built services on expanded land.
	if progress != null: progress.report(0.25, "LOADING_RESTORING")
	for row in data.world.tiles:
		var hex := grid.get_hex_at_cube_id(codec.decode(row.coord))
		if hex.structure == null or not hex.structure.instance is Settlement: continue
		var settlement := hex.structure.instance as Settlement
		for state in row.get("nodes", []):
			if state.path != "." or not state.has("expanded"): continue
			settlement.level = int(state.level)
			for coord: Vector3i in codec.decode(state.expanded):
				if not settlement.expanded_tiles.has(coord): settlement.expand_to_hex(grid, grid.get_hex_at_cube_id(coord))
	if not _migrate_obstructing_buildings(data, grid): return false
	for row in data.world.tiles:
		var hex := grid.get_hex_at_cube_id(codec.decode(row.coord))
		var wanted := codec.decode(row.get("structure")) as StructureInfo
		if wanted != null and hex.structure == null:
			if not hex.set_structure(wanted, true): return false
		if hex.structure != null:
			var root := hex.structure.instance as Node3D
			root.position = codec.decode(row.position)
			root.rotation = codec.decode(row.rotation)
		hex.can_generate = not bool(row.reserved)
		hex.blocked = bool(row.blocked)
		hex.is_explored = bool(row.explored)
		hex.set_explored(bool(row.explored))
	await manager.get_tree().process_frame
	# Completed homes must be open before their saved members can be recruited.
	var active_hex := grid.get_hex_at_cube_id(codec.decode(data.player.settlement))
	if active_hex == null or active_hex.structure == null or not active_hex.structure.instance is Settlement: return false
	manager.set_active_settlement(active_hex.structure.instance as Settlement)
	for row in data.world.tiles:
		var hex := grid.get_hex_at_cube_id(codec.decode(row.coord))
		if hex.structure == null: continue
		for state in row.get("nodes", []):
			var node := _saved_node(hex.structure.instance, state.path)
			if node is Buildable:
				for step: Interaction in node.build_steps: step.visible = false
				node.current_step = node.build_steps[int(state.build_step)]
				node.current_step.visible = true
	manager.active_settlement.refresh_service_states()
	# Recreate people before decoding historical operations and equipment links.
	if progress != null: progress.report(0.45, "LOADING_PEOPLE")
	for row in data.roster:
		var home := codec.decode(row.home) as FactionHome
		var profile := codec.decode(row.fields.npc_info) as NpcInfo
		if home == null or profile == null: return false
		var member := home.create_member(profile, {"display_name": str(row.fields.recruited_display_name)})
		if member == null: return false
		codec.npcs[row.id] = member.node
	for row in data.roster:
		var npc := codec.npcs[row.id] as NPC
		codec.apply_fields(npc, row.fields)
		npc.global_position = npc.get_recovery_position() if npc.rest_remaining_seconds > 0 else npc.get_operation_home_position()
		npc.set_state(NPC.NPCState.RESTING if npc.rest_remaining_seconds > 0 else NPC.NPCState.IDLE)
	for row in data.history:
		var quest: Quest
		match row.type:
			"shipment": quest = ShipmentQuest.new(codec.decode(row.location))
			"delivery": quest = DeliveryQuest.new(codec.decode(row.location))
			_: quest = Quest.new(codec.decode(row.location), row.type)
		quest.state_machine._current_state = row.state
		quest.state_machine._current_state_index = quest.state_machine.states.find(row.state)
		codec.quests[row.quest_id] = quest
	for row in data.history:
		var quest := codec.quests[row.quest_id] as Quest
		quest.context.assign(codec.decode(row.context))
		codec.apply_fields(quest, row.fields)
		if quest is DeliveryQuest and not row.fields.has("required_cargo"):
			quest.required_cargo.assign(quest.context.get("required_cargo", {}))
			quest.context.erase("required_cargo")
		var operation := manager.operations.register_quest(quest)
		codec.apply_fields(operation, row.operation)
		if bool(row.get("active", not quest.uses_guild_roster() and row.state not in ["complete", "failed", "cancelled"])):
			manager.quests.restore_active_quest(quest)
			var positions: Dictionary[String, Variant] = {}
			for old_id: String in row.get("positions", {}):
				var member := codec.npcs.get(old_id) as NPC
				if is_instance_valid(member): positions[str(member.get_instance_id())] = codec.decode(row.positions[old_id])
			quest.context["saved_party_positions"] = positions
	for row in data.world.tiles:
		var hex := grid.get_hex_at_cube_id(codec.decode(row.coord))
		if hex.structure == null: continue
		var root := hex.structure.instance as Node3D
		for state in row.get("nodes", []):
			var node := _saved_node(root, state.path)
			if node == null: return false
			codec.apply_fields(node, state.fields)
			if node is QuestObjective and not state.fields.has("discovery_resolved"):
				node.discovery_resolved = true
			if node is Settlement:
				node.level = int(state.level)
				for coord: Vector3i in codec.decode(state.expanded):
					if not node.expanded_tiles.has(coord): node.expand_to_hex(grid, grid.get_hex_at_cube_id(coord))
			if node is Buildable:
				for step: Interaction in node.build_steps: step.visible = false
				node.current_step = node.build_steps[int(state.build_step)]
				node.current_step.visible = true
			if node is BuildRequest and not state.get("delivery", {}).is_empty():
				node.quest.initialize()
				codec.restore_inventory(node.quest.progress_tracker, state.delivery)
	for entry: JournalEntry in manager.journal.entries:
		var saved := TypedData.string_map(data.journal.get(entry.id, {}))
		entry.unlocked = bool(saved.get("unlocked", entry.unlocked))
		for task: JournalTask in entry.get_tasks(): task.completed = bool(saved.get("tasks", {}).get(task.id, false))
	for key in data.factions:
		if manager.hub.factions.has(StringName(key)): codec.apply_fields(manager.hub.factions[StringName(key)], data.factions[key])
	codec.apply_fields(manager.hub, data.hub)
	for old_coord: Vector3i in codec.relocated_sites:
		var spot := manager.hub.spots.get(old_coord) as SpotProgress
		if spot != null:
			var new_coord := codec.relocated_sites[old_coord]
			manager.hub.spots.erase(old_coord)
			spot.cube_id = new_coord
			manager.hub.spots[new_coord] = spot
	codec.restore_inventory(manager.hub.stockpile, data.inventory)
	codec.apply_fields(manager.reputation, data.reputation)
	codec.apply_fields(manager.time_of_day, data.time)
	manager.time_of_day._update_phase()
	manager.time_of_day._update_sun_rotation()
	manager.time_of_day._update_lighting()
	manager.time_of_day._update_time_signal(true)
	# Completed improvements are presentation derived from saved project state.
	if progress != null: progress.report(0.70, "LOADING_RESTORING")
	manager.regional.restore_state(TypedData.string_map(data.get("regional", {})), codec)
	codec.apply_fields(manager.campaign, data.campaign)
	if manager.campaign.destination is QuestBoard:
		manager.campaign.destination_name = tr("WINDOW_QUEST_BOARD")
	# Occupation markers read HubState, so refresh them after restoring its spots.
	for row in data.world.tiles:
		var hex := grid.get_hex_at_cube_id(codec.decode(row.coord))
		if hex.structure == null: continue
		for state in row.get("nodes", []):
			_restore_site_visuals(_saved_node(hex.structure.instance, state.path), state.fields)
	manager.operations._next_id = data.history.size() + 1
	manager.active_settlement.refresh_service_states()
	grid.invalidate_settlement_structure_exclusion_cache()
	for settlement: Settlement in manager.settlements:
		if settlement.has_method("rebuild_boundary"):
			(settlement.get_parent() as HexBase).refresh_structure_footprint(true)
			settlement.call("rebuild_boundary")
	# Recreating sites can temporarily carve passages through terrain whose
	# neighbours have not been restored yet. The saved terrain is authoritative;
	# apply it again after every footprint/boundary has finished, then rebuild.
	var terrain_budget := GenerationBudget.new(grid)
	var restored_tiles := 0
	for row in data.world.tiles:
		restored_tiles += 1
		if progress != null: progress.report(0.75 + 0.15 * float(restored_tiles) / data.world.tiles.size(), "LOADING_RESTORING")
		# Legacy documents predate biome preservation and the current village
		# clearance rules. Keep their intentional footprint migrations intact.
		if not row.has("region"): continue
		await terrain_budget.checkpoint()
		var hex := grid.get_hex_at_cube_id(codec.decode(row.coord))
		var info := codec.decode(row.tile) as HexInfo
		var region := codec.decode(row.get("region")) as RegionInfo
		if region != null: grid.set_hex_region(hex, region)
		if hex.scene_instance.scene_info != info and hex.structure == null:
			grid.replace(hex.scene_instance, info.get_instance(), hex.region)
			hex = grid.get_hex_at_cube_id(codec.decode(row.coord))
		hex.set_elevation(int(row.elevation), grid.elevation_unit_height)
		codec.apply_fields(hex, row.terrain)
		hex.can_generate = not bool(row.reserved)
		hex.blocked = bool(row.blocked)
		hex.is_explored = bool(row.explored)
		grid.generated_elevations[hex.grid_id] = hex.generated_elevation_units
	await grid.pathfinder.rebuild_budgeted(terrain_budget)
	for quest: Quest in manager.quests.get_commissions(): CommissionSaveState.restore_bindings(quest, codec)
	if progress != null: progress.report(0.95, "LOADING_NAVIGATION")
	manager.transport.restore_saved_state(TypedData.string_map(data.get("transport", {})), codec)
	manager.transport.restore_visual()
	codec.apply_fields(manager.crafting, TypedData.string_map(data.get("crafting", {})))
	manager.player_instance.global_position = codec.decode(data.player.position)
	manager.player_instance.velocity = Vector3.ZERO
	manager.spring_arm_camera.snap_to_target()
	manager.campaign.refresh()
	manager.journal.journal_changed.emit()
	manager.hub.changed.emit()
	manager.reputation.changed.emit()
	manager.operations.operations_changed.emit()
	return true

## Older saves allowed foundations over compound services and gate approaches.
## Move the entire saved payload, including delivered materials and build steps,
## to a nearby valid plot before recreating services and historical references.
func _migrate_obstructing_buildings(data: Dictionary[String, Variant], grid: MainGrid) -> bool:
	var rows: Dictionary[Vector3i, Dictionary] = {}
	var occupied: Dictionary[Vector3i, bool] = {}
	for row: Dictionary[String, Variant] in data.world.tiles:
		var coord: Vector3i = codec.decode(row.coord)
		rows[coord] = row
		if row.has("structure"): occupied[coord] = true
	for row: Dictionary[String, Variant] in data.world.tiles.duplicate():
		var info := codec.decode(row.get("structure")) as PlaceableStructureInfo
		if info == null or info.placement_handler == null: continue
		if info.placement_handler.resource_path != "res://scripts/structures/settlement_placement_handler.gd": continue
		var old_coord: Vector3i = codec.decode(row.coord)
		var hex := grid.get_hex_at_cube_id(old_coord)
		var handler: RefCounted = info.placement_handler.new()
		var settlement: Settlement = handler._get_settlement_for_hex(hex)
		if settlement == null: continue
		if settlement.is_construction_site_clear(grid, hex, true): continue
		var candidates := settlement.get_settlement_hexes(grid)
		candidates.sort_custom(func(a: HexBase, b: HexBase) -> bool:
			var da := GridUtils.cube_distance(old_coord, a.cube_id)
			var db := GridUtils.cube_distance(old_coord, b.cube_id)
			return str(a.cube_id) < str(b.cube_id) if da == db else da < db
		)
		var target: HexBase
		for candidate: HexBase in candidates:
			if occupied.has(candidate.cube_id) or not rows.has(candidate.cube_id): continue
			if handler.can_place(info, candidate, null):
				target = candidate
				break
		if target == null:
			codec.errors.append("No clear settlement plot for saved " + info.id)
			return false
		# A previous restore may already have instantiated this same building.
		if hex.structure != null and hex.structure.structure_info == info:
			hex.structure.destroy()
			hex.structure = null
			hex.region_instance.unregister_structure(old_coord)
		var destination: Dictionary[String, Variant] = rows[target.cube_id]
		for key: String in ["structure", "position", "rotation", "nodes"]:
			destination[key] = row[key]
			row.erase(key)
		var rotation_y: float = handler.get_rotation_y(info, target)
		destination.position = codec.encode(info.get_placement_offset(target, rotation_y))
		destination.rotation = codec.encode(Vector3(0, rotation_y, 0))
		destination.terrain.structure_root_tile = codec.encode(target.cube_id)
		occupied.erase(old_coord)
		occupied[target.cube_id] = true
		codec.relocated_sites[old_coord] = target.cube_id
	return true

func _saved_node(root: Node, path: String) -> Node:
	return root.get_node_or_null(NodePath("Buildings/Market" if path == "Arrival/Trade" else path))

func _restore_site_visuals(node: Node, fields: Dictionary[String, Variant]) -> void:
	if not node is QuestObjective: return
	var state := (node as QuestObjective).state_machine.get_current_state_index()
	for method: String in ["_set_forest_state", "_set_crop_state", "_set_mine_state", "_set_ruins_state", "_set_water_state"]:
		if node.has_method(method): node.call(method, state)
	if node.has_method("_update_danger_marker"): node.call("_update_danger_marker")
	if node is FarmTile:
		node._on_crop_state_entered(node.state_machine.get_current_state())
		for key: String in ["_overgrow_timer", "_wither_timer"]:
			if fields.has(key) and fields[key] is Dictionary and fields[key].has("$timer") and node.get(key) != null:
				node.get(key).time_left = float(fields[key]["$timer"])
	if node.has_method("_start_regrow") and node.state_machine.get_current_state() == "DEPLETED":
		var timer: Variant = fields.get("_regrow_timer")
		var remaining := float(timer["$timer"]) if timer is Dictionary else float(node.get("regrow_time"))
		node.call("_start_regrow", remaining)
