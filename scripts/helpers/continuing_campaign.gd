class_name ContinuingCampaign
extends Node

signal changed()
var reward_paid := false
var _pending := false
var _signature := ""

func _ready() -> void:
	_connect.call_deferred()

func _connect() -> void:
	Manager.instance.regional.changed.connect(queue_refresh)
	Manager.instance.transport.changed.connect(queue_refresh)
	Manager.instance.hub.faction_activity_changed.connect(queue_refresh)
	Manager.instance.campaign.changed.connect(queue_refresh)
	queue_refresh()

func queue_refresh() -> void:
	if _pending: return
	_pending = true
	_refresh.call_deferred()

func objectives() -> Array[Dictionary]:
	var manager := Manager.instance
	var settlement := manager.active_settlement
	var count := manager.regional.completed_project_count()
	var deliveries := 0
	for record: VillageTradeRecord in manager.transport.villages.values(): deliveries += record.completed
	return [
		{"text": tr("NETWORK_PROJECTS") % [count, manager.regional.catalog.projects.size()], "done": count >= manager.regional.catalog.projects.size(), "action": "requests"},
		{"text": tr("NETWORK_LEVEL"), "done": is_instance_valid(settlement) and settlement.level >= 3, "action": "home"},
		{"text": tr("NETWORK_DELIVERIES") % [deliveries, 5], "done": deliveries >= 5, "action": "shipments"},
		{"text": tr("NETWORK_CARRIER"), "done": manager.transport.carrier.capacity >= 12, "action": "shipments"},
	]

func next_action() -> String:
	for row: Dictionary in objectives():
		if not row.done: return row.action
	return "home"

func _refresh() -> void:
	_pending = false
	if SaveGames.is_loading or not is_instance_valid(Manager.instance.active_settlement): return
	var rows := objectives()
	var signature := str(rows) + str(Manager.instance.regional.chapter_complete)
	if signature == _signature: return
	_signature = signature
	if Manager.instance.regional.chapter_complete and not reward_paid and rows.all(func(row: Dictionary) -> bool: return row.done):
		reward_paid = true
		Manager.instance.hub.add_currency(75)
		Manager.instance.hub.add_prestige(2)
		Manager.instance.toast.notify_report(tr("NETWORK_COMPLETE"), GameUI.SUCCESS)
	changed.emit()
