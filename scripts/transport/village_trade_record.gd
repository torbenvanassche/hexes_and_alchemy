class_name VillageTradeRecord
extends RefCounted

var cycle := 0
var completed := 0
var influence := 0
var phase := "available"
var request_id := ""
var deliveries: Dictionary[String, int] = {}
var partnership_reward_applied := false

func is_empty() -> bool:
	return request_id.is_empty()

static func from_legacy(data: Dictionary[String, Variant]) -> VillageTradeRecord:
	var record := VillageTradeRecord.new()
	record.cycle = int(data.get("cycle", 0))
	record.completed = int(data.get("completed", 0))
	record.influence = int(data.get("influence", 0))
	record.phase = str(data.get("phase", "available"))
	record.request_id = str(data.get("request_id", ""))
	if record.request_id.is_empty():
		record.request_id = TransportManager.REQUESTS[record.cycle % TransportManager.REQUESTS.size()].id
	if data.has("deliveries"):
		record.deliveries.assign(data.deliveries)
	elif record.completed > 0:
		record.deliveries[TransportManager.REQUESTS[0].id] = 1
	record.partnership_reward_applied = bool(data.get("partnership_reward_applied", false))
	return record
