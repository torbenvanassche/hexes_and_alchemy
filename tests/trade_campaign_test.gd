extends Node

const GRAIN := preload("res://resources/item_info/grain.tres")
const KIT := preload("res://resources/item_info/field_kit.tres")
const WORK := preload("res://resources/item_info/work_supplies.tres")
const PLANKS := preload("res://resources/item_info/wood_log.tres")
var failures: Array[String] = []
var coord := Vector3i.MAX
var deadline := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is MainGrid: node.world_seed = 20261102
	)
	get_window().size = Vector2i(1280, 720)
	deadline = Time.get_ticks_msec() + 90000
	_run.call_deferred()

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > deadline: get_tree().quit(1)

func check(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)

func _fixture(id: String) -> void:
	check(SaveGames.load_development_checkpoint(id), "Cannot load " + id)
	var result: Array = await SaveGames.load_finished
	check(result[0], "Fixture restore failed")
	for frame in 5: await get_tree().process_frame

func _reload(label: String) -> void:
	check(SaveGames.save_slot(label), "Cannot save: " + SaveGames.last_error)
	check(SaveGames.load_slot(SaveGames.slot_id(label)), "Cannot reload: " + SaveGames.last_error)
	var result: Array = await SaveGames.load_finished
	check(result[0], "Campaign restore failed")

func _finish_journey(delivery_only: bool = false) -> void:
	Engine.time_scale = 8
	var transport := Manager.instance.transport
	while not transport.active_shipment.is_empty():
		if delivery_only and transport.active_shipment.phase != "outbound": break
		await get_tree().process_frame
	Engine.time_scale = 1
	for frame in 5: await get_tree().process_frame

func _open(path: String) -> DraggableControl:
	var info := load(path) as SceneInfo
	info.queue(func(_info: SceneInfo) -> void: pass)
	while not info.is_cached: await get_tree().process_frame
	return SceneManager.add(info, false).node as DraggableControl

func _capture(window: DraggableControl, name: String) -> void:
	window.on_enter()
	for frame in 12: await get_tree().process_frame
	check(get_viewport().get_visible_rect().grow(1).encloses(window.get_global_rect()), name + " window is clipped")
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/validation/" + name + ".png")
	window.hide()

func _craft_equipment() -> void:
	var window := await _open("res://resources/scene_info/ui/crafting_ui.tres")
	var crafting := window.content as CraftingUI
	crafting.inventory = Manager.instance.hub.stockpile
	crafting.on_enter()
	for item: ItemInfo in [WORK, WORK, KIT, PLANKS, PLANKS]:
		var index := crafting.recipes.find(item)
		check(index >= 0, "Blacksmith is missing a required recipe")
		if index < 0: continue
		crafting._select_recipe(index)
		var before := crafting.inventory.get_count(item)
		crafting._craft_selected_item()
		while Manager.instance.crafting.active_job != null: await get_tree().process_frame
		check(crafting.inventory.get_count(item) == before + 1, "Crafting failed: " + item.unique_id)
	window.hide()

func _grain_slot() -> ContentSlotResource:
	var market := Manager.instance.transport.village_at(coord).get_node("Buildings/Market") as Market
	for slot: ContentSlotResource in market.buy_inventory.data:
		if slot.get_content() == GRAIN: return slot
	return null

func _run() -> void:
	while not SaveGames.save_block_reason().is_empty(): await get_tree().process_frame
	reparent(SaveGames)
	await _fixture("arrival")
	check(Manager.instance.campaign.stage == SettlementCampaign.Stage.BLUEPRINT, "Opening campaign was skipped")
	await _fixture("foundation")
	check(Manager.instance.campaign.stage == SettlementCampaign.Stage.MATERIALS, "Foundation requirements lost")
	await _fixture("village")
	var manager := Manager.instance
	var transport := manager.transport
	var village := transport.destinations()[0]
	coord = village.get_parent().cube_id
	check(manager.active_settlement.level == 2, "Level 2 fixture changed")
	check(manager.campaign.stage == SettlementCampaign.Stage.IMPROVE_VILLAGE, "Blacksmith does not lead to village requests")
	manager.hub.add_prestige(2)
	check(manager.regional.complete_project("water", true) and manager.regional.complete_project("food", true), "Cannot fund opening village improvements")
	for frame in 4: await get_tree().process_frame
	check(manager.campaign.stage == SettlementCampaign.Stage.FIRST_SHIPMENT, "Improved village does not lead to trade")
	check(not manager.campaign.get_guidance().contains("unlock level 2"), "Campaign asks for an already completed upgrade")
	check(_grain_slot() == null, "Grain unlocked before partnership")
	manager.campaign.refresh()
	check(manager.campaign.stage == SettlementCampaign.Stage.FIRST_SHIPMENT, "Discovery did not advance campaign")
	var gold := manager.hub.currency
	check(transport.dispatch(coord), "First shipment cannot dispatch")
	manager.campaign.refresh()
	check(manager.campaign.requirements_loaded(), "Loaded cargo is reported as missing")
	await _finish_journey(true)
	check(manager.hub.currency == gold + transport.REQUESTS[0].payment, "First payment wrong")
	check(not transport.is_partner(coord), "First delivery incorrectly grants partnership")
	check(manager.campaign.stage == SettlementCampaign.Stage.CRAFT_SHIPMENT, "Crafting goal missing after delivery")
	await _finish_journey()
	check(SaveGames.save_slot("First trade delivery"), "Cannot checkpoint first delivery")
	check(transport.next_request(coord), "Crafted request did not unlock")
	check(transport.get_request(coord) == TransportManager.PARTNERSHIP_REQUEST, "Next request still repeats raw supplies")
	var other := coord + Vector3i(1, 0, -1)
	transport.villages[other] = VillageTradeRecord.from_legacy({"cycle": 1, "completed": 1, "influence": 1, "phase": "fulfilled", "request_id": TransportManager.PARTNERSHIP_REQUEST.id, "deliveries": {TransportManager.PARTNERSHIP_REQUEST.id: 1}})
	check(not transport.is_partner(coord) and not transport.is_partner(other), "Deliveries to separate villages were combined")
	transport.villages.erase(other)
	check(not transport.dispatch(coord), "Equipment dispatched without crafted goods")
	await _craft_equipment()
	manager.campaign.refresh()
	check(manager.campaign.get_primary_action() == "shipments", "Ready equipment still sends player to craft")
	var journal := await _open("res://resources/scene_info/ui/hub_window.tres")
	journal.content.show_tab("trade")
	await _capture(journal, "trade-campaign-ready")
	transport.open_window(coord)
	await _capture(journal, "trade-equipment-request")
	gold = manager.hub.currency
	check(transport.dispatch(coord), "Equipment shipment failed")
	await _reload("Crafted shipment travelling")
	manager = Manager.instance
	transport = manager.transport
	check(transport.get_request(coord).id == TransportManager.PARTNERSHIP_REQUEST.id, "Loaded shipment changed request")
	check(manager.hub.stockpile.get_count(KIT) == 0, "Loading duplicated equipment")
	check(manager.campaign.requirements_loaded() and manager.campaign.get_requirement_count(KIT) == 1, "Campaign lost track of equipment loaded on the horse")
	await _finish_journey(true)
	check(manager.hub.currency == gold + TransportManager.PARTNERSHIP_REQUEST.payment + manager.campaign.chapter.completion_grant, "Equipment/chapter payment wrong")
	check(transport.is_partner(coord), "Crafted delivery did not establish partnership")
	check(manager.campaign.stage == SettlementCampaign.Stage.COMPLETE, "Campaign did not finish")
	check(manager.journal.is_task_completed("supply_village_equipment") and manager.journal.is_task_completed("establish_trade_partnership"), "New journal objectives not completed")
	var grain := _grain_slot()
	check(grain != null and grain.count == 6, "Partner grain stock missing")
	var home_market := manager.active_settlement.get_service(&"Market") as Market
	check(not home_market.buy_inventory.data.any(func(slot: ContentSlotResource) -> bool: return slot.get_content() == GRAIN), "Partner stock leaked into the home market")
	check(transport.village_at(coord).get_node("Buildings/Market/PartnershipGoods").visible, "Village shows no partnership improvement")
	check(manager.market.buy_from_slot(grain, manager.hub.stockpile, 6), "Partner grain cannot be bought")
	check(grain.count == 0 and grain.get_content() == GRAIN, "Sold-out partner goods lose their identity")
	var coins_after_purchase := manager.hub.currency
	await _reload("Partner delivery returning")
	manager = Manager.instance
	transport = manager.transport
	check(transport.is_partner(coord) and _grain_slot().count == 0, "Loading refilled partner stock or lost relationship")
	check(manager.hub.currency == coins_after_purchase, "Loading replayed the payment")
	await _finish_journey()
	check(manager.hub.currency == coins_after_purchase, "Returning carrier paid twice")
	check(_grain_slot().count == 0, "Returning carrier restocked twice")
	var market := transport.village_at(coord).get_node("Buildings/Market") as Market
	market.refresh_service_state()
	market.apply_partnership_stock(false)
	check(_grain_slot().count == 0, "Opening the partner market refilled sold-out goods")
	journal = await _open("res://resources/scene_info/ui/hub_window.tres")
	journal.content.show_tab("projects")
	await _capture(journal, "trade-campaign-complete")
	transport.open_window(coord)
	await _capture(journal, "trade-partner-summary")
	check(transport.next_request(coord), "Optional trade unavailable after partnership")
	check(transport.dispatch(coord), "Optional shipment failed")
	await _finish_journey()
	check(_grain_slot().count == 6, "Optional delivery did not replenish partner stock")
	# Real old save shape: the second rotating request remains rations/timber.
	check(SaveGames.load_slot(SaveGames.slot_id("First trade delivery")), "Cannot return to pre-partner checkpoint")
	await SaveGames.load_finished
	transport = Manager.instance.transport
	var legacy: VillageTradeRecord = transport.villages[coord]
	legacy.cycle = 1
	legacy.phase = "available"
	# Exercise the dictionary-to-record migration used by old checkpoints.
	transport.villages[coord] = VillageTradeRecord.from_legacy({"cycle": legacy.cycle, "phase": legacy.phase, "completed": legacy.completed, "influence": legacy.influence})
	await _reload("Legacy rotating trade")
	transport = Manager.instance.transport
	check(transport.get_request(coord) == transport.REQUESTS[1], "Old second request reinterpreted as crafted equipment")
	check(not transport.is_partner(coord), "Old delivery count granted an unearned partnership")
	check(transport.dispatch(coord), "Legacy rations request cannot dispatch")
	transport.active_shipment.request_id = ""
	transport.villages[coord].request_id = ""
	await _reload("Legacy shipment travelling")
	transport = Manager.instance.transport
	check(transport.active_shipment.request_id == transport.REQUESTS[1].id, "In-flight legacy cargo lost its request identity")
	await _finish_journey(true)
	check(not transport.is_partner(coord) and _grain_slot() == null, "Legacy rations delivery incorrectly unlocked partnership")
	await _fixture("trade_partner")
	coord = Manager.instance.transport.destinations()[0].get_parent().cube_id
	check(Manager.instance.campaign.stage == SettlementCampaign.Stage.IMPROVE_VILLAGE and _grain_slot().count == 6, "Partner checkpoint lost its trade reward or skipped village improvements")
	check(Manager.instance.transport.active_shipment.is_empty(), "Completed checkpoint still has a travelling carrier")
	await _fixture("arrival")
	check(Manager.instance.transport.villages.is_empty() and Manager.instance.campaign.trade_destination == Vector3i.MAX, "Later progress leaked into arrival")
	print("TRADE CAMPAIGN TEST %s" % ("PASS" if failures.is_empty() else str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)
