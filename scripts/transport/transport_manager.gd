class_name TransportManager
extends Node

signal changed()
const REQUESTS := [preload("res://resources/shipments/workshop_supplies.tres"), preload("res://resources/shipments/travel_supplies.tres")]

const WINDOW := preload("res://resources/scene_info/ui/transport_ui.tres")
@export var carrier: TransportCarrier = preload("res://resources/shipments/packhorse.tres")
var villages: Dictionary[Vector3i, Dictionary] = {}
var active_shipment: Dictionary = {}
var last_error := ""
var _carrier_visual: Node3D
var _last_display_second := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

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

func get_record(coord: Vector3i) -> Dictionary:
	return villages.get(coord, {})

func meet_village(coord: Vector3i) -> void:
	var village := village_at(coord)
	if village == null or not destinations().has(village): return
	if not villages.has(coord):
		villages[coord] = {"cycle": 0, "completed": 0, "influence": 0, "phase": "available"}
		Manager.instance.hub.record_activity(tr("SHIPMENT_CONTACT_NOTICE"))
		sync_journal()
		changed.emit()

func get_request(coord: Vector3i) -> ShipmentRequest:
	return REQUESTS[int(villages.get(coord, {}).get("cycle", 0)) % REQUESTS.size()]

func _home_hex() -> HexBase:
	var grid := get_grid()
	var home := Manager.instance.active_settlement
	return grid.get_hex_at_world_position(home.spawn_position.global_position) if grid != null and is_instance_valid(home) else null

func _arrival_hex(coord: Vector3i) -> HexBase:
	var village := village_at(coord)
	return get_grid().get_hex_at_world_position(village.spawn_position.global_position) if village != null else null

## A private pathfinder keeps exploration restrictions local to merchant routes.
func known_route(start: HexBase, finish: HexBase) -> Array[HexBase]:
	if start == null or finish == null: return []
	if not start.is_explored or not finish.is_explored: return []
	var nav := HexAStar.new(get_grid())
	nav.rebuild()
	for coord: Vector3i in nav.cube_to_id:
		if not get_grid().get_hex_at_cube_id(coord).is_explored: nav.set_point_disabled(nav.cube_to_id[coord])
	return nav.get_hex_path(start.cube_id, finish.cube_id)

func route_to(coord: Vector3i) -> Array[HexBase]:
	return known_route(_home_hex(), _arrival_hex(coord))

func dispatch_block_reason(coord: Vector3i) -> String:
	if SaveGames.is_loading: return tr("SHIPMENT_LOADING")
	if not villages.has(coord): return tr("SHIPMENT_VISIT_FIRST")
	if not active_shipment.is_empty(): return tr("SHIPMENT_CARRIER_BUSY")
	if villages[coord].phase != "available": return tr("SHIPMENT_ALREADY_DELIVERED")
	if cargo_size(get_request(coord)) > carrier.capacity: return tr("SHIPMENT_OVER_CAPACITY")
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
	var path := route_to(coord)
	var request := get_request(coord)
	# Set the occupied state before inventory signals can trigger another dispatch.
	var coords: Array[Vector3i] = []
	for hex: HexBase in path: coords.append(hex.cube_id)
	active_shipment = {"destination": coord, "phase": "outbound", "route": coords, "index": 1, "position": Manager.instance.active_settlement.spawn_position.global_position, "cargo": request.cargo.duplicate(), "payment": request.payment, "reputation": request.reputation_reward, "blocked": false}
	if not Manager.instance.hub.withdraw_items(request.cargo):
		active_shipment.clear()
		last_error = tr("SHIPMENT_MISSING_CARGO")
		return false
	villages[coord].phase = "outbound"
	_ensure_carrier_visual()
	_notice("SHIPMENT_DISPATCHED_NOTICE")
	changed.emit()
	return true

func next_request(coord: Vector3i) -> bool:
	if not active_shipment.is_empty() or not villages.has(coord) or villages[coord].phase != "fulfilled": return false
	villages[coord].cycle += 1
	villages[coord].phase = "available"
	changed.emit()
	return true

func recall() -> bool:
	if active_shipment.is_empty() or active_shipment.phase != "outbound": return false
	if not _reroute(_home_hex()): return false
	active_shipment.phase = "recalled"
	villages[active_shipment.destination].phase = "recalled"
	changed.emit()
	return true

func resume_route() -> bool:
	if active_shipment.is_empty(): return false
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
	changed.emit()
	return true

func _process(delta: float) -> void:
	if SaveGames.is_loading or active_shipment.is_empty(): return
	_ensure_carrier_visual()
	if not active_shipment.blocked: _advance(delta)
	if not active_shipment.is_empty():
		_carrier_visual.global_position = active_shipment.position
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
		# Open an operable village gate before crossing, like NPC gate interactions.
		for settlement: Settlement in Manager.instance.settlements:
			if settlement.has_method("prepare_gate_passage") and not settlement.prepare_gate_passage(previous.cube_id, next.cube_id):
				return
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
		var direction := target - position
		if Vector2(direction.x, direction.z).length() > 0.001:
			_carrier_visual.rotation.y = atan2(direction.x, direction.z)
		budget -= step
		if ratio >= 1.0:
			active_shipment.index = index + 1
		elif step <= 0.0: return

func _edge_open(a: HexBase, b: HexBase) -> bool:
	if a == b: return a.is_traversable(HexInfo.TraversalTag.WALK)
	var nav := get_grid().pathfinder
	return a.is_explored and b.is_explored and nav.cube_to_id.has(a.cube_id) and nav.cube_to_id.has(b.cube_id) and nav.are_points_connected(nav.cube_to_id[a.cube_id], nav.cube_to_id[b.cube_id]) and get_grid().can_traverse_between(a, b, HexInfo.TraversalTag.WALK)

func _arrive() -> void:
	var record: Dictionary = villages[active_shipment.destination]
	if active_shipment.phase == "outbound":
		# Transition first: loading or repeated updates cannot apply the reward twice.
		active_shipment.phase = "returning"
		record.phase = "returning"
		record.completed += 1
		record.influence += 1
		sync_journal()
		active_shipment.cargo.clear()
		Manager.instance.hub.add_currency(int(active_shipment.payment))
		Manager.instance.reputation.reputation += int(active_shipment.reputation)
		Manager.instance.reputation.changed.emit()
		Manager.instance.hub.add_prestige(1)
		var route: Array = active_shipment.route
		route.reverse()
		active_shipment.index = 1
		_notice("SHIPMENT_DELIVERED_NOTICE")
	else:
		if active_shipment.phase == "recalled":
			var returned: Dictionary[ItemInfo, int] = {}
			returned.assign(active_shipment.cargo)
			Manager.instance.hub.deposit_items(returned)
			record.phase = "available"
		else: record.phase = "fulfilled"
		active_shipment.clear()
		if is_instance_valid(_carrier_visual): _carrier_visual.queue_free()
		_carrier_visual = null
		_notice("SHIPMENT_RETURNED_NOTICE")
	changed.emit()

func remaining_seconds() -> float:
	if active_shipment.is_empty(): return 0.0
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
		if active_shipment.phase == "outbound":
			var village := village_at(active_shipment.destination)
			if village != null: return village.spawn_position.global_position
		else: return Manager.instance.active_settlement.spawn_position.global_position
	return get_grid().get_hex_at_cube_id(active_shipment.route[index]).global_position

func restore_visual() -> void:
	sync_journal()
	if not active_shipment.is_empty():
		# Older saves ended at the former entrance trade point. Replan to the market.
		var endpoint := _arrival_hex(active_shipment.destination) if active_shipment.phase == "outbound" else _home_hex()
		if endpoint != null and active_shipment.route.back() != endpoint.cube_id:
			if not _reroute(endpoint): active_shipment.blocked = true
		_ensure_carrier_visual()
		_carrier_visual.global_position = active_shipment.position
	changed.emit()

func sync_journal() -> void:
	if villages.is_empty(): return
	Manager.instance.journal.unlock_entry("regional_trade")
	Manager.instance.journal.complete_task("meet_neighbouring_village")
	for record: Dictionary in villages.values():
		if int(record.completed) > 0:
			Manager.instance.journal.complete_task("deliver_first_shipment")
			return

func _ensure_carrier_visual() -> void:
	if is_instance_valid(_carrier_visual): return
	_carrier_visual = carrier.scene.instantiate() as Node3D
	get_grid().add_child(_carrier_visual)
	_carrier_visual.global_position = active_shipment.position

func _notice(key: String) -> void:
	Manager.instance.hub.record_activity(tr(key))
	Manager.instance.toast.notify_report(tr(key))

func open_window(coord: Vector3i = Vector3i.MAX) -> void:
	var instance := SceneManager.add(WINDOW, false)
	instance.node.content.select_destination(coord)
	instance.on_enter.emit()
