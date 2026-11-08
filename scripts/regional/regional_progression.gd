class_name RegionalProgression
extends Node

signal changed()
@export var catalog: RegionalCatalog = preload("res://resources/regional/catalog.tres")
@export_range(30.0, 1800.0, 10.0) var incident_interval := 180.0
var projects: Dictionary[String, CommunityProjectState] = {}
var unlocked_recipes: Dictionary[String, bool] = {}
var resolved_incidents: Dictionary[String, bool] = {}
var active_incident: IncidentState
var completed_commissions := 0
var expeditions_completed := 0
var chapter_complete := false
var incident_remaining := 180.0
var incident_serial := 0
var selected_project := "water"
var last_error := ""
var discoveries := DiscoveryRandomizer.new()
var _refresh_pending := false
var _grid_id := 0
var _was_unlocked := false
var _presentation := CommunityPresentation.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	discoveries.definitions = catalog.discoveries
	_ensure_projects()
	_connect_managers.call_deferred()

func _connect_managers() -> void:
	Manager.instance.hub.mapped_changed.connect(queue_refresh)
	Manager.instance.campaign.changed.connect(_on_campaign_changed)
	Manager.instance.operations.operation_completed.connect(_on_operation_completed)
	queue_refresh()

func _on_campaign_changed() -> void:
	var unlocked := is_unlocked()
	if unlocked != _was_unlocked:
		_was_unlocked = unlocked
		queue_refresh()

func get_next_project_id() -> String:
	if projects.has(selected_project) and not projects[selected_project].completed: return selected_project
	for definition: CommunityProjectDefinition in catalog.projects:
		if not project_complete(definition.id): return definition.id
	return catalog.projects[0].id

func _ensure_projects() -> void:
	for definition: CommunityProjectDefinition in catalog.projects:
		if not projects.has(definition.id): projects[definition.id] = CommunityProjectState.new()

func register_site(site: QuestObjective) -> void:
	discoveries.register_site(site)
	var kind := DiscoveryRandomizer.get_kind(site)
	# Definitions remain shared resources; only the site's profile list is extended.
	site.quest_profiles = site.quest_profiles.duplicate()
	for commission_set: SiteCommissionSet in catalog.commissions:
		if commission_set.site_kind != kind: continue
		for profile: QuestProfile in commission_set.profiles:
			if not site.quest_profiles.has(profile): site.quest_profiles.append(profile)
	queue_refresh()

func queue_refresh() -> void:
	if _refresh_pending: return
	_refresh_pending = true
	_refresh.call_deferred()

func _refresh() -> void:
	_refresh_pending = false
	if SaveGames.is_loading: return
	var grid := Manager.instance.transport.get_grid()
	if grid == null or not grid.initialized: return
	discoveries.refresh(grid)
	_update_chapter()
	_presentation.refresh(self)
	changed.emit()

func _process(delta: float) -> void:
	if SaveGames.is_loading: return
	var grid := Manager.instance.transport.get_grid()
	if grid == null or not grid.initialized: return
	if _grid_id != grid.get_instance_id():
		_grid_id = grid.get_instance_id()
		queue_refresh()
	if active_incident == null and is_unlocked() and completed_project_count() > 0 and completed_commissions >= 3:
		incident_remaining = maxf(0.0, incident_remaining - delta)
		if incident_remaining <= 0.0:
			if not try_start_incident(): incident_remaining = 30.0

func is_unlocked() -> bool:
	return is_instance_valid(Manager.instance.active_settlement) and Manager.instance.active_settlement.has_service(&"Blacksmith")

func get_definition(id: String) -> CommunityProjectDefinition:
	for definition: CommunityProjectDefinition in catalog.projects:
		if definition.id == id: return definition
	return null

func completed_project_count() -> int:
	var count := 0
	for state: CommunityProjectState in projects.values():
		if state.completed: count += 1
	return count

func project_complete(id: String) -> bool:
	return projects.has(id) and projects[id].completed

func completion_block_reason(id: String, funded := false) -> String:
	var definition := get_definition(id)
	if definition == null or not is_unlocked(): return tr("COMMUNITY_FORGE_FIRST")
	if projects[id].completed: return tr("COMMUNITY_FINISHED")
	if funded: return tr("COMMUNITY_NO_INSTANT_FUNDING")
	if definition.construction != null and projects[id].blueprint_issued:
		return tr("COMMUNITY_BUILD_FOUNDATION") if get_project_buildable(id) == null else tr("COMMUNITY_DELIVER_FOUNDATION")
	if not projects[id].fieldwork_done: return tr("COMMUNITY_FIELDWORK_REQUIRED")
	var hub := Manager.instance.hub
	if hub.prestige < definition.prestige_cost: return tr("COMMUNITY_NEED_PRESTIGE") % definition.prestige_cost
	var price := definition.coin_cost
	if hub.currency < price: return tr("COMMUNITY_NEED_COINS") % price
	if definition.construction == null and not hub.stockpile.has_all(definition.materials): return tr("COMMUNITY_NEED_MATERIALS")
	if definition.blueprint != null and hub.stockpile.get_available_slots(definition.blueprint, true).is_empty(): return tr("CRAFTING_INVENTORY_FULL")
	return ""

func complete_project(id: String, funded := false) -> bool:
	last_error = completion_block_reason(id, funded)
	if not last_error.is_empty(): return false
	var definition := get_definition(id)
	var state := projects[id]
	var hub := Manager.instance.hub
	# Guard before inventory/standing signals can call back into the action.
	if definition.construction != null: state.blueprint_issued = true
	else: state.completed = true
	hub.add_currency(-definition.coin_cost)
	hub.add_prestige(-definition.prestige_cost)
	if definition.construction != null:
		hub.stockpile.add(definition.blueprint, 1)
		Manager.instance.toast.notify_item_reward(definition.blueprint, 1, GameUI.SUCCESS)
		queue_refresh()
		changed.emit()
		return true
	hub.withdraw_items(definition.materials)
	_grant_project_rewards(definition)
	return true

func get_project_buildable(id: String) -> Buildable:
	var definition := get_definition(id)
	if definition == null or definition.construction == null: return null
	var grid := Manager.instance.transport.get_grid()
	if grid == null: return null
	for buildable: Buildable in Manager.instance.active_settlement.buildables:
		if not is_instance_valid(buildable): continue
		var hex := grid.get_hex_at_world_position(buildable.global_position)
		if hex != null and hex.structure != null and hex.structure.structure_info == definition.construction: return buildable
	return null

func remaining_materials(id: String) -> Dictionary[ItemInfo, int]:
	var definition := get_definition(id)
	var result: Dictionary[ItemInfo, int] = {}
	if definition == null: return result
	var building := get_project_buildable(id)
	var foundation := building.current_step as BuildRequest if building != null else null
	for item: ItemInfo in definition.materials:
		var delivered := foundation.quest.progress_tracker.get_count(item) if foundation != null and foundation.quest.progress_tracker != null else 0
		result[item] = maxi(0, definition.materials[item] - delivered)
	return result

func finish_construction(id: String) -> bool:
	var definition := get_definition(id)
	if definition == null or project_complete(id) or not projects[id].blueprint_issued: return false
	var building := get_project_buildable(id)
	if building == null or building.current_step is BuildRequest: return false
	projects[id].completed = true
	_grant_project_rewards(definition)
	return true

func place_project(id: String) -> void:
	var definition := get_definition(id)
	if definition == null or definition.construction == null: return
	var building := get_project_buildable(id)
	if building == null:
		WorldPlacement.begin(definition.construction, Manager.instance.hub.stockpile)
	else:
		Manager.instance.campaign.destination = building.current_step
		Manager.instance.campaign.destination_name = definition.get_title()
		Manager.instance.campaign.destination_changed.emit()
		SceneManager.remove_current_ui_scene()

func _grant_project_rewards(definition: CommunityProjectDefinition) -> void:
	var id := definition.id
	var hub := Manager.instance.hub
	Manager.instance.reputation.reputation += definition.reputation_reward
	Manager.instance.reputation.changed.emit()
	if not definition.recipe_unlock.is_empty(): unlocked_recipes[definition.recipe_unlock] = true
	hub.deposit_items(definition.reward_items)
	Manager.instance.journal.unlock_entry("community_chapter")
	Manager.instance.journal.complete_task("community_" + id)
	hub.record_activity(tr("COMMUNITY_COMPLETED") % definition.get_title())
	Manager.instance.toast.notify_project_completed(definition)
	queue_refresh()
	changed.emit()

func _on_operation_completed(quest: Quest) -> void:
	if quest == null or not quest.uses_guild_roster(): return
	completed_commissions += 1
	var site := quest.get_objective()
	var kind := DiscoveryRandomizer.get_kind(site)
	var success := quest.outcome == null or not quest.outcome.is_dangerous
	if success:
		for definition: CommunityProjectDefinition in catalog.projects:
			if definition.site_kind == kind and definition.commission_types.has(quest.quest_key):
				projects[definition.id].fieldwork_done = true
				projects[definition.id].fieldwork_site = quest.location.cube_id
		if kind == "ancient_ruins":
			expeditions_completed += 1
			Manager.instance.journal.complete_task("community_expedition")
		if quest.quest_key == "catalogue": unlocked_recipes["surveyors_kit"] = true
		if active_incident != null and quest.location != null and active_incident.site == quest.location.cube_id and active_incident.definition.repair_types.has(quest.quest_key):
			_finish_incident(true)
	queue_refresh()

func _update_chapter() -> void:
	if not is_unlocked(): return
	Manager.instance.journal.unlock_entry("community_chapter")
	for id: String in projects:
		if projects[id].completed: Manager.instance.journal.complete_task("community_" + id)
	if expeditions_completed > 0: Manager.instance.journal.complete_task("community_expedition")

func recipe_available(item: ItemInfo) -> bool:
	return item.recipe_unlock_key.is_empty() or unlocked_recipes.has(item.recipe_unlock_key)

func duration_multiplier(kind: String, behaviour: String) -> float:
	var multiplier := 1.0
	for definition: CommunityProjectDefinition in catalog.projects:
		if project_complete(definition.id) and (definition.duration_site_kinds.has(kind) or definition.duration_behaviours.has(behaviour)):
			multiplier = minf(multiplier, definition.work_duration_multiplier)
	return multiplier

func crafting_multiplier(item_id: String) -> float:
	var multiplier := 1.0
	for definition: CommunityProjectDefinition in catalog.projects:
		if project_complete(definition.id) and definition.crafting_item_ids.has(item_id):
			multiplier = minf(multiplier, definition.crafting_duration_multiplier)
	return multiplier

func reward_bonus(kind: String, quest_key: String) -> Dictionary[ItemInfo, int]:
	var result: Dictionary[ItemInfo, int] = {}
	for definition: CommunityProjectDefinition in catalog.projects:
		if not project_complete(definition.id) or definition.site_kind != kind or not definition.bonus_quest_keys.has(quest_key): continue
		for item: ItemInfo in definition.bonus_items:
			result[item] = result.get(item, 0) + definition.bonus_items[item]
	return result

func find_site(kind: String, quest_types: Array[String]) -> QuestObjective:
	var candidates: Array[QuestObjective] = []
	for site: QuestObjective in discoveries.sites:
		if not is_instance_valid(site) or site.hex == null or not site.hex.is_explored: continue
		if DiscoveryRandomizer.get_kind(site) != kind: continue
		if not Manager.instance.quests.is_quest_location_reachable(site.hex): continue
		if quest_types.is_empty() and not site.get_filtered_quest_types().is_empty():
			candidates.append(site)
			continue
		for key: String in quest_types:
			if site.get_filtered_quest_types().has(key):
				candidates.append(site)
				break
	if candidates.is_empty(): return null
	var origin := Manager.instance.active_settlement.get_parent() as HexBase
	candidates.sort_custom(func(a: QuestObjective, b: QuestObjective) -> bool: return GridUtils.cube_distance(origin.cube_id, a.hex.cube_id) < GridUtils.cube_distance(origin.cube_id, b.hex.cube_id))
	return candidates[0]

func open_project_work(id: String) -> void:
	var definition := get_definition(id)
	if definition == null: return
	selected_project = id
	var site := get_project_work_site(id)
	if site == null:
		_open_commission(null, [], true)
		return
	_open_commission(site, definition.commission_types)

func get_project_work_site(id: String) -> QuestObjective:
	var definition := get_definition(id)
	if definition == null: return null
	var site := find_site(definition.site_kind, definition.commission_types)
	return site if site != null else find_site(definition.site_kind, [])

func _open_commission(site: QuestObjective, preferred: Array[String], scouting := false) -> void:
	if not scouting and not is_instance_valid(site): return
	var info := DataManager.instance.get_scene_by_name("quest_creation_ui")
	info.queue(func(loaded: SceneInfo) -> void:
		if not scouting and not is_instance_valid(site): return
		var window := SceneManager.add(loaded, false)
		var ui := (window.node as DraggableControl).content as QuestCreationUI
		if scouting: ui.setup_scouting_request()
		else: ui.force_data(site)
		window.on_enter.emit()
		if is_instance_valid(site):
			var selection := ""
			for key: String in preferred:
				if not site.get_filtered_quest_types().has(key): continue
				if selection.is_empty(): selection = key
				if site.has_required_supplies(key, Manager.instance.hub.stockpile) and _has_available_provider(site.get_profile(key)):
					selection = key
					break
			if not selection.is_empty(): ui.select_commission_type(selection)
	)

func _has_available_provider(profile: QuestProfile) -> bool:
	if profile == null: return false
	for faction: FactionState in Manager.instance.hub.factions.values():
		if faction.get_available_member_count_for_role(profile.get_required_role()) > 0: return true
	return false

func try_start_incident() -> bool:
	if active_incident != null or not is_unlocked() or completed_project_count() == 0 or completed_commissions < 3: return false
	var grid := Manager.instance.transport.get_grid()
	var rng := grid.create_rng("local_incident:%d" % incident_serial)
	var options: Array[IncidentDefinition] = catalog.incidents.duplicate()
	if options.size() > 1 and rng.randf() < 0.5: options.reverse()
	for definition: IncidentDefinition in options:
		if resolved_incidents.has(definition.id): continue
		for site: QuestObjective in discoveries.sites:
			if not is_instance_valid(site) or site.hex == null or not site.hex.is_explored: continue
			if DiscoveryRandomizer.get_kind(site) != definition.site_kind or not definition.eligible_states.has(site.state_machine.get_current_state()): continue
			if Manager.instance.quests.has_quests_for_location(site.hex): continue
			if site is WaterSource and site.protected_uses > 0: continue
			if site is Mineshaft and site.reinforced_uses > 0: continue
			active_incident = IncidentState.new()
			active_incident.definition = definition
			active_incident.site = site.hex.cube_id
			active_incident.previous_state = site.state_machine.get_current_state()
			site.apply_site_state(definition.problem_state)
			incident_serial += 1
			Manager.instance.toast.notify_report(definition.get_title(), GameUI.WARNING)
			Manager.instance.hub.record_activity(definition.get_title())
			changed.emit()
			return true
	return false

func open_incident_work() -> void:
	if active_incident == null: return
	var hex := Manager.instance.transport.get_grid().get_hex_at_cube_id(active_incident.site)
	var site := hex.structure.instance as QuestObjective if hex != null and hex.structure != null else null
	_open_commission(site, active_incident.definition.repair_types)

func fund_incident() -> bool:
	if active_incident == null: return false
	var price := active_incident.definition.funding_cost
	if Manager.instance.hub.currency < price:
		last_error = tr("COMMUNITY_NEED_COINS") % price
		return false
	var hex := Manager.instance.transport.get_grid().get_hex_at_cube_id(active_incident.site)
	if hex != null and Manager.instance.quests.has_quests_for_location(hex):
		last_error = tr("COMMUNITY_WORK_RUNNING")
		return false
	Manager.instance.hub.add_currency(-price)
	if hex != null and hex.structure != null:
		var site := hex.structure.instance as QuestObjective
		if site != null: site.apply_site_state(active_incident.previous_state)
	_finish_incident(false)
	return true

func _finish_incident(commissioned: bool) -> void:
	var definition := active_incident.definition
	resolved_incidents[definition.id] = true
	active_incident = null
	incident_remaining = incident_interval
	if commissioned: Manager.instance.hub.add_currency(definition.coin_reward)
	Manager.instance.toast.notify_report(tr("COMMUNITY_INCIDENT_RESOLVED") % definition.get_title(), GameUI.SUCCESS)
	changed.emit()

func restore_state(fields: Dictionary[String, Variant], codec: SaveCodec) -> void:
	codec.apply_fields(self, fields)
	_ensure_projects()
	# Old saves completed water as a decorative prop. Preserve earned progress
	# and issue a placement permit once, without charging or paying rewards again.
	for definition: CommunityProjectDefinition in catalog.projects:
		var state := projects[definition.id]
		if definition.construction != null and state.completed and not state.blueprint_issued:
			state.blueprint_issued = true
			if get_project_buildable(definition.id) == null:
				Manager.instance.hub.stockpile.add(definition.blueprint, 1, true)
	_presentation.refresh(self)
	queue_refresh()

func get_incident_requester() -> CommunityProjectDefinition:
	if active_incident != null:
		for definition: CommunityProjectDefinition in catalog.projects:
			if definition.site_kind == active_incident.definition.site_kind: return definition
	return catalog.projects[0]

func open_request(id: String) -> void:
	var info := DataManager.instance.get_scene_by_name("quest_list_ui")
	info.queue(func(loaded: SceneInfo) -> void:
		var window := SceneManager.add(loaded, false)
		window.on_enter.emit()
		var board := (window.node as DraggableControl).content as QuestListUI
		board.show_request(id)
	)
