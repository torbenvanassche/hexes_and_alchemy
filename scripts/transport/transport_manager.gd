class_name TransportManager
extends Node

signal changed()
const REQUESTS := [preload("res://resources/shipments/workshop_supplies.tres"), preload("res://resources/shipments/travel_supplies.tres")]
const PARTNERSHIP_REQUEST := preload("res://resources/shipments/village_equipment.tres")

@export var carrier: TransportCarrier = preload("res://resources/shipments/packhorse.tres")
var villages: Dictionary[Vector3i, VillageTradeRecord] = {}
var active_shipment := ShipmentJourney.new()
var last_error := ""
var _carrier_visual: Node3D
var _last_display_second := -1
var _discovery_refresh_pending := false
var _discovery_grid_id := 0
var stops := TransportStops.new()
const STABLE_ROUTE_VERSION := 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_connect_discovery.call_deferred()

func _connect_discovery() -> void:
	Manager.instance.hub.mapped_changed.connect(_queue_discovery_refresh)
	_queue_discovery_refresh()

func _queue_discovery_refresh() -> void:
	if _discovery_refresh_pending: return
	_discovery_refresh_pending = true
	_refresh_discovered_villages.call_deferred()

func _refresh_discovered_villages() -> void:
	_discovery_refresh_pending = false
	if SaveGames.is_loading: return
	for village: Settlement in destinations():
		register_discovered_village(village.get_parent().cube_id)

func is_village_discovered(coord: Vector3i) -> bool:
	var village := village_at(coord)
	return village != null and not village.allows_player_construction and (village.get_parent() as HexBase).is_explored

## Decode old dictionary saves once; gameplay only sees typed records.
func restore_saved_state(fields: Dictionary[String, Variant], codec: SaveCodec) -> void:
	villages.clear()
	var saved_villages: Variant = codec.decode(fields.get("villages"))
	if saved_villages is Dictionary:
		for coord: Vector3i in saved_villages:
			var saved: Variant = saved_villages[coord]
			villages[coord] = saved if saved is VillageTradeRecord else VillageTradeRecord.from_legacy(TypedData.string_map(saved))
	var saved_journey: Variant = codec.decode(fields.get("active_shipment"))
	if saved_journey is ShipmentJourney:
		active_shipment = saved_journey
	elif saved_journey is Dictionary:
		active_shipment = ShipmentJourney.from_legacy(TypedData.string_map(saved_journey))
	else:
		active_shipment = ShipmentJourney.new()
	if fields.has("carrier"): carrier = codec.decode(fields.carrier) as TransportCarrier

func get_grid() -> MainGrid:
	var active := SceneManager.get_active_scene()
	return active.node as MainGrid if is_instance_valid(active) and is_instance_valid(active.node) else null

func destinations() -> Array[Settlement]:
	var result: Array[Settlement] = []
	var grid := get_grid()
	if grid == null: return result
	for settlement: Settlement in Manager.instance.settlements:
		if not is_instance_valid(settlement) or settlement.allows_player_construction or not grid.is_ancestor_of(settlement): continue
		var hex := settlement.get_parent() as HexBase
		if hex != null and hex.is_explored: result.append(settlement)
	result.sort_custom(func(a: Settlement, b: Settlement) -> bool: return str(a.get_parent().cube_id) < str(b.get_parent().cube_id))
	return result

func village_at(coord: Vector3i) -> Settlement:
	var grid := get_grid()
	if grid == null: return null
	var hex := grid.get_hex_at_cube_id(coord)
	return hex.structure.instance as Settlement if hex != null and hex.structure != null else null

func get_record(coord: Vector3i) -> VillageTradeRecord:
	_normalise_record(coord)
	return villages[coord] if villages.has(coord) else VillageTradeRecord.new()

func _normalise_record(coord: Vector3i) -> void:
	if not villages.has(coord): return
	var record := villages[coord]
	# Older saves rotated two requests by cycle. Never reinterpret an old cargo
	# as the new crafted delivery, or grant partnership from a delivery count.
	if record.request_id.is_empty():
		record.request_id = REQUESTS[record.cycle % REQUESTS.size()].id
	if not active_shipment.is_empty() and active_shipment.destination == coord and active_shipment.request_id.is_empty():
		active_shipment.request_id = record.request_id

func has_first_delivery(coord: Vector3i) -> bool:
	return get_record(coord).deliveries.get(REQUESTS[0].id, 0) > 0

func is_partner(coord: Vector3i) -> bool:
	return has_first_delivery(coord) and get_record(coord).deliveries.get(PARTNERSHIP_REQUEST.id, 0) > 0

func get_relationship_text(coord: Vector3i) -> String:
	if is_partner(coord): return tr("SHIPMENT_RELATION_PARTNER")
	if has_first_delivery(coord): return tr("SHIPMENT_RELATION_TRUSTED")
	return tr("SHIPMENT_RELATION_KNOWN") if is_village_discovered(coord) else tr("SHIPMENT_RELATION_UNKNOWN")

func _request_by_id(request_id: String) -> ShipmentRequest:
	if request_id == PARTNERSHIP_REQUEST.id: return PARTNERSHIP_REQUEST
	for request: ShipmentRequest in REQUESTS:
		if request.id == request_id: return request
	return REQUESTS[0]

func register_discovered_village(coord: Vector3i) -> void:
	if not is_village_discovered(coord): return
	if not villages.has(coord):
		villages[coord] = VillageTradeRecord.new()
		villages[coord].request_id = REQUESTS[0].id
		if not SaveGames.is_loading: Manager.instance.hub.record_activity(tr("SHIPMENT_CONTACT_NOTICE"))
		sync_journal()
		changed.emit()

func get_request(coord: Vector3i) -> ShipmentRequest:
	var record := get_record(coord)
	if not active_shipment.is_empty() and active_shipment.destination == coord:
		return _request_by_id(active_shipment.request_id)
	return _request_by_id(record.request_id)

func _home_hex() -> HexBase:
	var grid := get_grid()
	var home := Manager.instance.active_settlement
	if grid == null or stops.get_stable(grid, home) == null: return null
	return grid.get_hex_at_cube_id(home.transport_stable_tile)

func _arrival_hex(coord: Vector3i) -> HexBase:
	var village := village_at(coord)
	var grid := get_grid()
	if grid == null or stops.get_stable(grid, village) == null: return null
	return grid.get_hex_at_cube_id(village.transport_stable_tile)

## Copy the existing navigation topology: rebuilding HexAStar here repeatedly
## rescanned every world tile against every wall when any UI wanted a preview.
## A separate graph still keeps unknown terrain out of merchant routes.
func known_route(start: HexBase, finish: HexBase) -> Array[HexBase]:
	if start == null or finish == null: return []
	if not start.is_explored or not finish.is_explored: return []
	var grid := get_grid()
	stops.ensure_all(grid)
	var inside := stops.interiors(grid)
	var source := grid.pathfinder
	var nav := AStar2D.new()
	for coord: Vector3i in source.cube_to_id:
		var hex := grid.get_hex_at_cube_id(coord)
		if hex == null or inside.has(coord) or not hex.is_explored or not hex.is_traversable(HexInfo.TraversalTag.WALK): continue
		var point: int = source.cube_to_id[coord]
		nav.add_point(point, source.get_point_position(point), hex.movement_cost)
	for point: int in nav.get_point_ids():
		for neighbor: int in source.get_point_connections(point):
			if nav.has_point(neighbor) and stops.permits_edge(source.id_to_cube[point], source.id_to_cube[neighbor]) and not nav.are_points_connected(point, neighbor):
				nav.connect_points(point, neighbor)
	var from_id: int = source.cube_to_id.get(start.cube_id, -1)
	var to_id: int = source.cube_to_id.get(finish.cube_id, -1)
	if not nav.has_point(from_id) or not nav.has_point(to_id): return []
	var result: Array[HexBase] = []
	for point: int in nav.get_id_path(from_id, to_id):
		result.append(grid.get_hex_at_cube_id(source.id_to_cube[point]))
	return result

func route_to(coord: Vector3i) -> Array[HexBase]:
	return known_route(_home_hex(), _arrival_hex(coord))

func dispatch_block_reason(coord: Vector3i) -> String:
	if SaveGames.is_loading: return tr("SHIPMENT_LOADING")
	if not is_village_discovered(coord): return tr("SHIPMENT_DISCOVER_FIRST")
	if not active_shipment.is_empty(): return tr("SHIPMENT_CARRIER_BUSY")
	if get_record(coord).phase != "available": return tr("SHIPMENT_ALREADY_DELIVERED")
	if get_request(coord) == PARTNERSHIP_REQUEST:
		if not has_first_delivery(coord): return tr("SHIPMENT_FIRST_DELIVERY_REQUIRED")
		if not Manager.instance.active_settlement.has_service(&"Blacksmith"): return tr("SHIPMENT_BLACKSMITH_REQUIRED")
	if cargo_size(get_request(coord)) > carrier.capacity: return tr("SHIPMENT_OVER_CAPACITY")
	if _home_hex() == null or _arrival_hex(coord) == null: return tr("SHIPMENT_NO_STABLE")
	if route_to(coord).is_empty(): return tr("SHIPMENT_NO_ROUTE")
	if not Manager.instance.hub.stockpile.has_all(get_request(coord).cargo): return tr("SHIPMENT_MISSING_CARGO")
	return ""

func cargo_size(request: ShipmentRequest) -> int:
	var total := 0
	for count: int in request.cargo.values(): total += count
	return total

func dispatch(coord: Vector3i) -> bool:
	last_error = dispatch_block_reason(coord)
	if not last_error.is_empty(): return false
	register_discovered_village(coord)
	var path := route_to(coord)
	var request := get_request(coord)
	# Set the occupied state before inventory signals can trigger another dispatch.
	var coords: Array[Vector3i] = []
	for hex: HexBase in path: coords.append(hex.cube_id)
	active_shipment = ShipmentJourney.new()
	active_shipment.destination = coord
	active_shipment.request_id = request.id
	active_shipment.phase = "outbound"
	active_shipment.route = coords
	active_shipment.position = stops.loading_position(get_grid(), Manager.instance.active_settlement)
	active_shipment.cargo = request.cargo.duplicate()
	active_shipment.payment = request.payment
	active_shipment.reputation = request.reputation_reward
	active_shipment.route_version = STABLE_ROUTE_VERSION
	var quest := ShipmentQuest.new(get_grid().get_hex_at_cube_id(coord))
	quest.prepare(request, {}, request.payment, request.reputation_reward)
	active_shipment.quest = quest
	if not quest.reserve_cargo(Manager.instance.hub.stockpile):
		active_shipment.clear()
		last_error = tr("SHIPMENT_MISSING_CARGO")
		return false
	_ensure_shipment_quest()
	villages[coord].phase = "outbound"
	_ensure_carrier_visual()
	_carrier_visual.global_position = active_shipment.position
	_carrier_visual.get_node("Cargo").visible = true
	_notice("SHIPMENT_DISPATCHED_NOTICE")
	changed.emit()
	return true

func next_request(coord: Vector3i) -> bool:
	if not active_shipment.is_empty() or not villages.has(coord) or villages[coord].phase != "fulfilled": return false
	_normalise_record(coord)
	villages[coord].cycle += 1
	villages[coord].request_id = PARTNERSHIP_REQUEST.id if has_first_delivery(coord) and not is_partner(coord) else REQUESTS[(int(villages[coord].cycle) + 1) % REQUESTS.size()].id
	villages[coord].phase = "available"
	changed.emit()
	return true

func recall() -> bool:
	if active_shipment.is_empty() or active_shipment.phase != "outbound": return false
	if not _reroute(_home_hex()): return false
	active_shipment.phase = "recalled"
	villages[active_shipment.destination].phase = "recalled"
	var quest := _ensure_shipment_quest()
	if quest != null: quest.context["recalled"] = true
	changed.emit()
	return true

func resume_route() -> bool:
	if active_shipment.is_empty(): return false
	if active_shipment.phase == "unloading": return false
	var endpoint := _arrival_hex(active_shipment.destination) if active_shipment.phase == "outbound" else _home_hex()
	return _reroute(endpoint)

func _reroute(endpoint: HexBase) -> bool:
	var start := get_grid().get_hex_at_world_position(active_shipment.position)
	var path := known_route(start, endpoint)
	if path.is_empty():
		last_error = tr("SHIPMENT_NO_ROUTE")
		return false
	var coords: Array[Vector3i] = []
	for hex: HexBase in path: coords.append(hex.cube_id)
	active_shipment.route = coords
	active_shipment.index = mini(1, coords.size() - 1)
	active_shipment.blocked = false
	active_shipment.route_version = STABLE_ROUTE_VERSION
	changed.emit()
	return true

func _process(delta: float) -> void:
	if SaveGames.is_loading: return
	var grid := get_grid()
	if grid == null or not grid.initialized: return
	if _discovery_grid_id != grid.get_instance_id():
		_discovery_grid_id = grid.get_instance_id()
		_refresh_discovered_villages()
	stops.ensure_all(grid)
	if active_shipment.is_empty():
		_park_idle_horse(delta)
		return
	_ensure_carrier_visual()
	if active_shipment.phase == "unloading":
		active_shipment.unload_remaining = maxf(0.0, float(active_shipment.unload_remaining) - delta)
		if active_shipment.unload_remaining <= 0.0: _begin_return()
	elif not active_shipment.blocked: _advance(delta)
	if not active_shipment.is_empty():
		_carrier_visual.global_position = active_shipment.position
		_carrier_visual.get_node("Cargo").visible = not active_shipment.cargo.is_empty()
		if _carrier_visual.has_method("update_motion"):
			_carrier_visual.update_motion(delta, not active_shipment.blocked and active_shipment.phase != "unloading")
		var hex := get_grid().get_hex_at_world_position(_carrier_visual.global_position)
		_carrier_visual.visible = hex != null and hex.is_explored
		var second := ceili(remaining_seconds())
		if second != _last_display_second:
			_last_display_second = second
			changed.emit()

func _advance(delta: float) -> void:
	var budget := delta
	while budget > 0.0 and not active_shipment.is_empty():
		var index := int(active_shipment.index)
		var route: Array = active_shipment.route
		if index >= route.size(): _arrive(); return
		var next := get_grid().get_hex_at_cube_id(route[index])
		var previous := get_grid().get_hex_at_cube_id(route[maxi(0, index - 1)])
		if next == null or previous == null or not _edge_open(previous, next):
			active_shipment.blocked = true
			_notice("SHIPMENT_BLOCKED_NOTICE")
			changed.emit()
			return
		var target := _waypoint_position(index)
		var position: Vector3 = active_shipment.position
		var distance := Vector2(target.x - position.x, target.z - position.z).length()
		# Road construction can lower movement_cost without a separate transport rule.
		var speed := carrier.travel_speed / maxf(0.25, next.movement_cost)
		var duration := distance / speed
		var step := minf(budget, duration)
		var ratio := 1.0 if distance < 0.001 else minf(1.0, speed * step / distance)
		var moved := position.lerp(target, ratio)
		var ground := get_grid().get_hex_at_world_position(moved)
		if ground != null: moved.y = ground.get_surface_height_at_for_method(moved, HexInfo.TraversalTag.WALK)
		active_shipment.position = moved
		if _carrier_visual.has_method("record_distance"):
			_carrier_visual.record_distance(position.distance_to(moved))
		var direction := target - position
		if Vector2(direction.x, direction.z).length() > 0.001:
			if _carrier_visual.has_method("face_travel_direction"):
				_carrier_visual.face_travel_direction(direction)
			else: _carrier_visual.rotation.y = atan2(direction.x, direction.z)
		budget -= step
		if ratio >= 1.0:
			active_shipment.index = index + 1
		elif step <= 0.0: return

func _edge_open(a: HexBase, b: HexBase) -> bool:
	var inside := stops.interiors(get_grid())
	if inside.has(a.cube_id) or inside.has(b.cube_id): return false
	if a == b: return a.is_traversable(HexInfo.TraversalTag.WALK)
	if not stops.permits_edge(a.cube_id, b.cube_id): return false
	var nav := get_grid().pathfinder
	return a.is_explored and b.is_explored and nav.cube_to_id.has(a.cube_id) and nav.cube_to_id.has(b.cube_id) and nav.are_points_connected(nav.cube_to_id[a.cube_id], nav.cube_to_id[b.cube_id]) and get_grid().can_traverse_between(a, b, HexInfo.TraversalTag.WALK)

func _arrive() -> void:
	_normalise_record(active_shipment.destination)
	var record: VillageTradeRecord = villages[active_shipment.destination]
	var quest := _ensure_shipment_quest()
	if active_shipment.phase == "outbound":
		# A real quest work phase gives the carrier time to unload at the stable.
		# Transition before signals; the outcome owns the single delivery payout.
		active_shipment.phase = "unloading"
		active_shipment.unload_duration = carrier.unloading_seconds
		active_shipment.unload_remaining = carrier.unloading_seconds
		record.phase = "unloading"
		if quest != null:
			quest.set_state(Quest.QuestState.IN_PROGRESS)
			if not quest.context.get("delivery_paid", false):
				record.completed += 1
				record.influence += 1
				var request_id := str(active_shipment.request_id)
				record.deliveries[request_id] = int(record.deliveries.get(request_id, 0)) + 1
				quest.resolve_delivery()
				active_shipment.delivery_paid = true
				active_shipment.cargo.clear()
				_apply_partnership(active_shipment.destination, true)
				sync_journal()
	else:
		if active_shipment.phase == "recalled":
			if quest != null: Manager.instance.quests.cancel_quest(quest, "SHIPMENT_RECALLED_RESULT")
			record.phase = "available"
		else:
			if quest != null: quest.finish_return()
			record.phase = "fulfilled"
		active_shipment.clear()
		_park_idle_horse()
		_notice("SHIPMENT_RETURNED_NOTICE")
	changed.emit()

func _begin_return() -> void:
	if active_shipment.is_empty() or active_shipment.phase != "unloading": return
	active_shipment.phase = "returning"
	villages[active_shipment.destination].phase = "returning"
	_ensure_shipment_quest()
	if not _reroute(_home_hex()):
		active_shipment.blocked = true
		_notice("SHIPMENT_BLOCKED_NOTICE")
	changed.emit()

func _ensure_shipment_quest() -> ShipmentQuest:
	if active_shipment.is_empty(): return null
	var quest := active_shipment.quest as ShipmentQuest
	if quest == null:
		var destination := get_grid().get_hex_at_cube_id(active_shipment.destination)
		if destination == null: return null
		quest = ShipmentQuest.new(destination)
		var delivered := bool(active_shipment.delivery_paid)
		quest.prepare(get_request(active_shipment.destination), active_shipment.cargo, int(active_shipment.payment), int(active_shipment.reputation), delivered)
		active_shipment.quest = quest
	# A definition may complete on delivery while its carrier still returns home.
	if quest.is_state(Quest.QuestState.COMPLETE) or quest.is_state(Quest.QuestState.CANCELLED) or quest.is_state(Quest.QuestState.FAILED): return quest
	if not Manager.instance.quests.active_quests.has(quest): Manager.instance.quests.add_quest(quest)
	var state := Quest.QuestState.EN_ROUTE
	if active_shipment.phase == "unloading": state = Quest.QuestState.IN_PROGRESS
	elif active_shipment.phase in ["returning", "recalled"]: state = Quest.QuestState.RETURNING
	if not quest.is_state(state): quest.set_state(state)
	return quest

func remaining_seconds() -> float:
	if active_shipment.is_empty(): return 0.0
	if active_shipment.phase == "unloading": return float(active_shipment.unload_remaining)
	var previous: Vector3 = active_shipment.position
	var total := 0.0
	for i in range(int(active_shipment.index), active_shipment.route.size()):
		var hex := get_grid().get_hex_at_cube_id(active_shipment.route[i])
		if hex == null: return total
		var target := _waypoint_position(i)
		total += Vector2(previous.x - target.x, previous.z - target.z).length() * maxf(0.25, hex.movement_cost) / carrier.travel_speed
		previous = target
	return total

func _waypoint_position(index: int) -> Vector3:
	if index == active_shipment.route.size() - 1:
		var loading := Vector3.INF
		if active_shipment.phase in ["outbound", "unloading"]:
			var village := village_at(active_shipment.destination)
			if village != null: loading = stops.loading_position(get_grid(), village)
		else: loading = stops.loading_position(get_grid(), Manager.instance.active_settlement)
		if loading.is_finite(): return loading
	var hex := get_grid().get_hex_at_cube_id(active_shipment.route[index])
	return hex.global_position if hex != null else active_shipment.position

func restore_visual() -> void:
	stops.ensure_all(get_grid())
	# Earlier checkpoints required a market visit. Discovered villages now become
	# delivery destinations on load without changing any existing delivery proof.
	for village: Settlement in destinations():
		register_discovered_village(village.get_parent().cube_id)
	for coord: Vector3i in villages:
		_normalise_record(coord)
		_apply_partnership(coord, false)
	sync_journal()
	if not active_shipment.is_empty():
		_ensure_shipment_quest()
		# Older journeys went through town to the market. Move a horse still inside
		# a settlement to its stable, then replan without replaying cargo or rewards.
		var endpoint := _arrival_hex(active_shipment.destination) if active_shipment.phase in ["outbound", "unloading"] else _home_hex()
		if endpoint == null: active_shipment.blocked = true
		var legacy := int(active_shipment.route_version) < STABLE_ROUTE_VERSION
		if legacy:
			var current := get_grid().get_hex_at_world_position(active_shipment.position)
			for settlement: Settlement in Manager.instance.settlements:
				if settlement.contains_hex(get_grid(), current):
					var position := stops.loading_position(get_grid(), settlement)
					if position.is_finite(): active_shipment.position = position
					break
		if endpoint != null and (legacy or active_shipment.route.back() != endpoint.cube_id):
			if not _reroute(endpoint): active_shipment.blocked = true
		_ensure_carrier_visual()
		_carrier_visual.global_position = active_shipment.position
	else: _park_idle_horse()
	changed.emit()

func sync_journal() -> void:
	if villages.is_empty(): return
	Manager.instance.journal.unlock_entry("regional_trade")
	Manager.instance.journal.complete_task("meet_neighbouring_village")
	for coord: Vector3i in villages:
		if has_first_delivery(coord): Manager.instance.journal.complete_task("deliver_first_shipment")
		if is_partner(coord):
			Manager.instance.journal.complete_task("supply_village_equipment")
			Manager.instance.journal.complete_task("establish_trade_partnership")

func _apply_partnership(coord: Vector3i, restock: bool) -> void:
	if not is_partner(coord): return
	var record: VillageTradeRecord = villages[coord]
	var village := village_at(coord)
	var market := village.get_node_or_null("Buildings/Market") if village != null else null
	if market == null: return
	var newly_established := not bool(record.partnership_reward_applied)
	record.partnership_reward_applied = true
	market.apply_partnership_stock(restock or newly_established)
	if newly_established and not SaveGames.is_loading:
		Manager.instance.hub.record_activity(tr("SHIPMENT_PARTNERSHIP_NOTICE"))
		Manager.instance.toast.notify_report(tr("SHIPMENT_PARTNERSHIP_NOTICE"))

func _ensure_carrier_visual() -> void:
	if is_instance_valid(_carrier_visual): return
	_carrier_visual = carrier.scene.instantiate() as Node3D
	get_grid().add_child(_carrier_visual)
	if not active_shipment.is_empty(): _carrier_visual.global_position = active_shipment.position

func _park_idle_horse(delta: float = 0.0) -> void:
	var home := Manager.instance.active_settlement
	var stable := stops.get_stable(get_grid(), home)
	if stable == null:
		if is_instance_valid(_carrier_visual): _carrier_visual.hide()
		return
	_ensure_carrier_visual()
	_carrier_visual.global_position = stops.loading_position(get_grid(), home)
	if _carrier_visual.has_method("face_heading"):
		_carrier_visual.face_heading(stable.global_rotation.y)
	else: _carrier_visual.rotation.y = stable.global_rotation.y
	if _carrier_visual.has_method("update_motion"):
		_carrier_visual.update_motion(delta, false)
	_carrier_visual.get_node("Cargo").hide()
	_carrier_visual.visible = stable.is_visible_in_tree()

func _notice(key: String) -> void:
	Manager.instance.hub.record_activity(tr(key))
	Manager.instance.toast.notify_report(tr(key))

func open_window(coord: Vector3i = Vector3i.MAX) -> void:
	var journal := DataManager.instance.get_scene_by_name("hub_window")
	if journal != null: journal.queue(_open_trade_page.bind(coord))

func _open_trade_page(journal: SceneInfo, coord: Vector3i) -> void:
	var instance := SceneManager.add(journal, false)
	(instance.node.content as HubWindowUI).show_trade(coord)
	instance.on_enter.emit()
