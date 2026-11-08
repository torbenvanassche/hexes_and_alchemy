class_name ShipmentJourney
extends RefCounted

## Runtime journey state. The save boundary alone accepts legacy dictionaries.
var destination := Vector3i.ZERO
var request_id := ""
var phase := ""
var route: Array[Vector3i] = []
var index := 1
var position := Vector3.ZERO
var cargo: Dictionary[ItemInfo, int] = {}
var payment := 0
var reputation := 0
var blocked := false
var route_version := 0
var unload_duration := 0.0
var unload_remaining := 0.0
var delivery_paid := false
var quest: ShipmentQuest

func is_empty() -> bool:
	return phase.is_empty()

func clear() -> void:
	phase = ""
	route.clear()
	cargo.clear()
	quest = null

static func from_legacy(data: Dictionary[String, Variant]) -> ShipmentJourney:
	var journey := ShipmentJourney.new()
	journey.destination = data.get("destination", Vector3i.ZERO)
	journey.request_id = str(data.get("request_id", ""))
	journey.phase = str(data.get("phase", ""))
	journey.route.assign(data.get("route", []))
	journey.index = int(data.get("index", 1))
	journey.position = data.get("position", Vector3.ZERO)
	journey.cargo.assign(data.get("cargo", {}))
	journey.payment = int(data.get("payment", 0))
	journey.reputation = int(data.get("reputation", 0))
	journey.blocked = bool(data.get("blocked", false))
	journey.route_version = int(data.get("route_version", 0))
	journey.unload_duration = float(data.get("unload_duration", 0.0))
	journey.unload_remaining = float(data.get("unload_remaining", 0.0))
	journey.delivery_paid = bool(data.get("delivery_paid", journey.phase in ["unloading", "returning"]))
	journey.quest = data.get("quest") as ShipmentQuest
	return journey
