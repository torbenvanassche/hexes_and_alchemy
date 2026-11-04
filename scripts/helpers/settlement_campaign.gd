class_name SettlementCampaign
extends Node

## The opening chapter follows real construction state; it never consumes supplies
## or completes buildings on the player's behalf.
signal changed()
signal destination_changed()

enum Stage { BLUEPRINT, PLACE_FOUNDATION, MATERIALS, CONSTRUCTION, COMPLETE }

const FORGE := preload("res://resources/structure_info/forge.tres")
const BUILD_QUEST := preload("res://tools/quest_system/resources/quests/build_forge.tres")

var settlement: Settlement
var stage: Stage = Stage.BLUEPRINT
var destination: Node3D
var destination_name := ""
var _completion_announced := false
var _refresh_pending := false

func _ready() -> void:
	_connect_managers.call_deferred()

func _connect_managers() -> void:
	Manager.instance.hub.changed.connect(queue_refresh)
	Manager.instance.quests.quest_list_changed.connect(queue_refresh)
	Manager.instance.operations.operations_changed.connect(queue_refresh)

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
	if not is_instance_valid(settlement):
		return
	_refresh_timber_objective()
	if settlement.has_service(&"Blacksmith"):
		stage = Stage.COMPLETE
	elif get_foundation() != null:
		stage = Stage.CONSTRUCTION if has_materials() else Stage.MATERIALS
	elif Manager.instance.hub.stockpile.get_count(get_blueprint()) > 0:
		stage = Stage.PLACE_FOUNDATION
	else:
		stage = Stage.BLUEPRINT
	if stage == Stage.COMPLETE and not _completion_announced:
		_completion_announced = true
		Manager.instance.journal.complete_task("open_blacksmith")
		var message := tr("CAMPAIGN_FORGE_COMPLETE_NOTICE")
		Manager.instance.hub.record_activity(message)
		if Manager.instance.toast != null:
			Manager.instance.toast.notify_report(message)
		clear_destination()
	if stage == Stage.COMPLETE: Manager.instance.journal.unlock_entry("regional_trade")
	changed.emit()

func _refresh_timber_objective() -> void:
	if Manager.instance.journal.is_task_completed("complete_timber_commission"):
		return
	for operation: HubOperation in Manager.instance.operations.operations:
		var quest := operation.quest
		if quest == null or quest.quest_key != "harvest" or not quest.context.get("reward_claimed", false):
			continue
		if quest.location == null or quest.location.structure == null:
			continue
		var info := quest.location.structure.structure_info
		if info != null and info.id == "forest":
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
	return tr("CAMPAIGN_FORGE_STEP_%s" % Stage.keys()[stage])

func get_guidance() -> String:
	return tr("CAMPAIGN_FORGE_GUIDANCE_%s" % Stage.keys()[stage])

func get_primary_action() -> String:
	match stage:
		Stage.BLUEPRINT:
			return "market"
		Stage.PLACE_FOUNDATION:
			return "stockpile"
		Stage.MATERIALS:
			return "board"
		Stage.CONSTRUCTION:
			return "foundation"
		_:
			return "home"

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
	return null

func perform_action(action: String) -> void:
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
