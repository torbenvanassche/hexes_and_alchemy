class_name TradeDemand
extends RefCounted

const ORDERS: Array[ShipmentRequest] = [
	preload("res://resources/shipments/partner_provisions.tres"),
	preload("res://resources/shipments/partner_tools.tres"),
	preload("res://resources/shipments/partner_water.tres"),
]

static func next_for(coord: Vector3i, cycle: int) -> ShipmentRequest:
	var index := posmod(coord.x * 7 + coord.z * 11 + cycle, ORDERS.size())
	return ORDERS[index]

static func by_id(id: String) -> ShipmentRequest:
	for request: ShipmentRequest in ORDERS:
		if request.id == id: return request
	return null

static func bonus_payment(base: int, reputation: int, influence: int) -> int:
	# A modest earned benefit; manifests snapshot the agreed payout on dispatch.
	var bonus := minf(0.2, float(maxi(0, reputation)) * 0.005 + float(maxi(0, influence)) * 0.01)
	return roundi(base * (1.0 + bonus))
