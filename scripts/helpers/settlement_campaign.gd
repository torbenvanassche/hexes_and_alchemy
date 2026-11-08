class_name SettlementCampaign
extends Node

## The opening chapter follows real construction state; it never consumes supplies
## or completes buildings on the player's behalf.
signal changed()
signal destination_changed()

enum Stage { BLUEPRINT, PLACE_FOUNDATION, MATERIALS, CONSTRUCTION, COMPLETE, MEET_VILLAGE, FIRST_SHIPMENT, CRAFT_SHIPMENT, IMPROVE_VILLAGE }
@export var chapter: OpeningChapterDefinition = preload("res://resources/campaign/opening_chapter.tres")
var _chapter_completion_announced := false

const FORGE := preload("res://resources/structure_info/forge.tres")
const BUILD_QUEST := preload("res://tools/quest_system/resources/quests/build_forge.tres")

var settlement: Settlement
var stage: Stage = Stage.BLUEPRINT
var destination: Node3D
var destination_name := ""
var trade_destination := Vector3i.MAX
var _completion_announced := false
var _refresh_pending := false

func _ready() -> void:
	_connect_managers.call_deferred()

func _connect_managers() -> void:
	Manager.instance.hub.changed.connect(queue_refresh)
	Manager.instance.hub.mapped_changed.connect(queue_refresh)
	Manager.instance.quests.quest_list_changed.connect(queue_refresh)
	Manager.instance.operations.operations_changed.connect(queue_refresh)
	Manager.instance.transport.changed.connect(queue_refresh)
	Manager.instance.regional.changed.connect(queue_refresh)

func watch_settlement(value: Settlement) -> void:
	if is_instance_valid(settlement) and settlement.level_changed.is_connected(_on_settlement_changed):
		settlement.level_changed.disconnect(_on_settlement_changed)
	settlement = value
	if settlement != null:
		settlement.level_changed.connect(_on_settlement_changed)
	queue_refresh()

func _on_settlement_changed(_level: int) -> void:
	queue_refresh()

func queue_refresh() -> void:
	if _refresh_pending:
		return
	_refresh_pending = true
	refresh.call_deferred()

func refresh() -> void:
	_refresh_pending = false
	if SaveGames.is_loading: return
	if not is_instance_valid(settlement):
		return
	_refresh_timber_objective()
	var forge_open := settlement.has_service(&"Blacksmith")
	if forge_open:
		var coord := get_trade_coord()
		if Manager.instance.regional.completed_project_count() < chapter.required_projects: stage = Stage.IMPROVE_VILLAGE
		elif Manager.instance.transport.is_partner(coord): stage = Stage.COMPLETE
		elif Manager.instance.transport.has_first_delivery(coord): stage = Stage.CRAFT_SHIPMENT
		elif coord != Vector3i.MAX: stage = Stage.FIRST_SHIPMENT
		else: stage = Stage.MEET_VILLAGE
	elif get_foundation() != null:
		stage = Stage.CONSTRUCTION if has_materials() else Stage.MATERIALS
	elif Manager.instance.hub.stockpile.get_count(get_blueprint()) > 0:
		stage = Stage.PLACE_FOUNDATION
	else:
		stage = Stage.BLUEPRINT
	if forge_open and not _completion_announced:
		_completion_announced = true
		Manager.instance.hub.add_currency(chapter.forge_grant)
		Manager.instance.journal.complete_task("open_blacksmith")
		var message := tr("CAMPAIGN_FORGE_COMPLETE_NOTICE") % chapter.forge_grant
		Manager.instance.hub.record_activity(message)
		if Manager.instance.toast != null:
			Manager.instance.toast.notify_report(message)
		clear_destination()
	if stage == Stage.COMPLETE and not _chapter_completion_announced:
		_chapter_completion_announced = true
		Manager.instance.regional.chapter_complete = true
		Manager.instance.journal.complete_task("community_foothold")
		Manager.instance.hub.add_currency(chapter.completion_grant)
		Manager.instance.hub.add_prestige(chapter.completion_prestige)
		var message := tr("CAMPAIGN_OPENING_COMPLETE_NOTICE") % [chapter.completion_grant, chapter.completion_prestige]
		Manager.instance.hub.record_activity(message)
		Manager.instance.toast.notify_report(message, GameUI.SUCCESS)
	if forge_open: Manager.instance.journal.unlock_entry("regional_trade")
	changed.emit()

func is_forge_chapter() -> bool:
	return stage in [Stage.BLUEPRINT, Stage.PLACE_FOUNDATION, Stage.MATERIALS, Stage.CONSTRUCTION]

func get_trade_coord() -> Vector3i:
	var transport := Manager.instance.transport
	var contacts: Array[Vector3i] = []
	contacts.assign(transport.villages.keys())
	contacts.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return str(a) < str(b))
	for coord: Vector3i in contacts:
		if transport.village_at(coord) != null and transport.is_partner(coord):
			trade_destination = coord
			return coord
	if transport.village_at(trade_destination) != null and transport.villages.has(trade_destination): return trade_destination
	for coord: Vector3i in contacts:
		if transport.village_at(coord) != null:
			trade_destination = coord
			return coord
	var discovered := transport.destinations()
	return discovered[0].get_parent().cube_id if not discovered.is_empty() else Vector3i.MAX

func get_title() -> String:
	return tr("COMMUNITY_CHAPTER_TITLE")

func get_purpose() -> String:
	return tr("CAMPAIGN_OPENING_PURPOSE") % chapter.required_projects

func get_current_requirements() -> Dictionary[ItemInfo, int]:
	if is_forge_chapter(): return get_materials()
	if stage == Stage.CRAFT_SHIPMENT: return TransportManager.PARTNERSHIP_REQUEST.cargo
	if stage == Stage.FIRST_SHIPMENT: return Manager.instance.transport.get_request(get_trade_coord()).cargo
	return {}

func requirements_loaded() -> bool:
	var shipment := Manager.instance.transport.active_shipment
	if shipment.is_empty() or shipment.destination != get_trade_coord() or shipment.phase != "outbound": return false
	var wanted := TransportManager.PARTNERSHIP_REQUEST.id if stage == Stage.CRAFT_SHIPMENT else TransportManager.REQUESTS[0].id
	return shipment.request_id == wanted

func get_requirement_count(item: ItemInfo) -> int:
	if requirements_loaded(): return int(Manager.instance.transport.active_shipment.cargo.get(item, 0))
	return Manager.instance.hub.stockpile.get_count(item)

func _refresh_timber_objective() -> void:
	if Manager.instance.journal.is_task_completed("complete_timber_commission"):
		return
	for operation: HubOperation in Manager.instance.operations.operations:
		var quest := operation.quest
		if quest == null or not quest.context.get("reward_claimed", false):
			continue
		if quest.location == null or quest.location.structure == null:
			continue
		var info := quest.location.structure.structure_info
		if info != null and info.id == "forest" and quest.get_profile() != null and quest.get_profile().behaviour == "harvest":
			Manager.instance.journal.complete_task("complete_timber_commission")
			return

func get_blueprint() -> ItemInfo:
	return FORGE.build_cost.keys()[0] as ItemInfo

func get_foundation() -> BuildRequest:
	if not is_instance_valid(settlement):
		return null
	for buildable: Buildable in settlement.buildables:
		if not is_instance_valid(buildable):
			continue
		var request := buildable.current_step as BuildRequest
		if request != null and request.quest != null and request.recipe_path == BUILD_QUEST.resource_path:
			return request
	return null

func get_materials() -> Dictionary[ItemInfo, int]:
	var result: Dictionary[ItemInfo, int] = {}
	var foundation := get_foundation()
	var quest := foundation.quest if foundation != null else BUILD_QUEST
	for item: ItemInfo in quest.requested_items:
		var delivered := quest.progress_tracker.get_count(item) if quest.progress_tracker != null else 0
		result[item] = maxi(0, quest.requested_items[item] - delivered)
	return result

func has_materials() -> bool:
	return Manager.instance.hub.stockpile.has_all(get_materials())

func get_step_text() -> String:
	if stage == Stage.IMPROVE_VILLAGE:
		return tr("CAMPAIGN_OPENING_PROJECT_STEP") % [Manager.instance.regional.completed_project_count(), chapter.required_projects]
	if stage == Stage.COMPLETE: return tr("CAMPAIGN_OPENING_FINISHED")
	if not is_forge_chapter(): return tr("CAMPAIGN_TRADE_STEP_%s" % Stage.keys()[stage])
	return tr("CAMPAIGN_FORGE_STEP_%s" % Stage.keys()[stage])

func get_guidance() -> String:
	if stage == Stage.IMPROVE_VILLAGE: return tr("CAMPAIGN_OPENING_PROJECT_GUIDANCE")
	if stage == Stage.COMPLETE: return tr("CAMPAIGN_OPENING_COMPLETE_GUIDANCE")
	if not is_forge_chapter():
		if requirements_loaded(): return tr("CAMPAIGN_TRADE_GUIDANCE_DELIVERING")
		return tr("CAMPAIGN_TRADE_GUIDANCE_%s" % Stage.keys()[stage])
	return tr("CAMPAIGN_FORGE_GUIDANCE_%s" % Stage.keys()[stage])

func get_primary_action() -> String:
	match stage:
		Stage.IMPROVE_VILLAGE:
			return "requests"
		Stage.COMPLETE:
			return "home"
		Stage.BLUEPRINT:
			return "market"
		Stage.PLACE_FOUNDATION:
			return "stockpile"
		Stage.MATERIALS:
			return "board"
		Stage.CONSTRUCTION:
			return "foundation"
		Stage.MEET_VILLAGE:
			return "village" if get_trade_coord() != Vector3i.MAX else "board"
		Stage.FIRST_SHIPMENT:
			return "shipments"
		Stage.CRAFT_SHIPMENT:
			return "shipments" if requirements_loaded() or Manager.instance.hub.stockpile.has_all(get_current_requirements()) else "blacksmith"
		_:
			return "village"

func get_destination(action: String) -> Node3D:
	if not is_instance_valid(settlement):
		return null
	match action:
		"market":
			return settlement.get_service(&"Market")
		"board":
			return settlement.get_service(&"QuestBoard")
		"foundation":
			return get_foundation()
		"home":
			return settlement.get_service(&"SettlementHome")
		"blacksmith":
			return settlement.get_service(&"Blacksmith")
		"village":
			var village := Manager.instance.transport.village_at(get_trade_coord())
			return village.get_node_or_null("Buildings/Market") if village != null else null
	return null

func can_perform_action(action: String) -> bool:
	if action == "requests": return true
	if action == "shipments": return get_trade_coord() != Vector3i.MAX
	return action == "stockpile" or get_destination(action) != null

func perform_action(action: String) -> void:
	if action == "requests":
		Manager.instance.regional.open_request(Manager.instance.regional.get_next_project_id())
		return
	if action == "shipments":
		Manager.instance.transport.open_window(get_trade_coord())
		return
	if action == "stockpile":
		if Manager.instance.player_instance != null:
			Manager.instance.player_instance.toggle_hub_tab("inventory")
		return
	var target := get_destination(action)
	if target == null:
		return
	destination = target
	destination_name = tr("CAMPAIGN_DESTINATION_%s" % action.to_upper())
	destination_changed.emit()
	# Finding a place closes the management window and leaves the player in control.
	SceneManager.remove_current_ui_scene()

func clear_destination() -> void:
	destination = null
	destination_name = ""
	destination_changed.emit()
