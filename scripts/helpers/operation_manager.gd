class_name OperationManager
extends Node

signal operations_changed()

@export var auto_resolve_completed_quests := true

var operations: Array[HubOperation] = []
var _next_id := 1

func register_quest(quest: Quest, parent_id: String = "") -> HubOperation:
	if quest == null:
		return null
	for operation in operations:
		if operation != null and operation.quest == quest:
			return operation
	var operation := HubOperation.new("operation_%s" % _next_id, quest, parent_id)
	_next_id += 1
	var hub := _get_hub()
	if hub != null:
		operation.required_role = hub.get_required_role_for_quest(quest)
		var faction := hub.get_faction_for_quest(quest)
		operation.faction_id = faction.id if faction != null else &""
	operations.append(operation)
	if not quest.state_machine.state_entered.is_connected(_on_quest_state_changed.bind(operation)):
		quest.state_machine.state_entered.connect(_on_quest_state_changed.bind(operation))
	if not quest.completed.is_connected(_on_quest_completed.bind(operation)):
		quest.completed.connect(_on_quest_completed.bind(operation))
	if not quest.outcome_ready.is_connected(_on_quest_outcome_ready.bind(operation)):
		quest.outcome_ready.connect(_on_quest_outcome_ready.bind(operation))
	_capture_available_quest_types(quest)
	if quest.location != null and hub != null:
		hub.mark_operation(quest.location, quest.quest_key)
	operations_changed.emit()
	return operation

func _on_quest_outcome_ready(resolved_outcome: QuestOutcome, _operation: HubOperation) -> void:
	if resolved_outcome == null:
		return
	var summary := resolved_outcome.get_summary()
	if summary == "":
		return
	var hub := _get_hub()
	if hub != null:
		hub.record_activity(summary)
	if Manager.instance != null and Manager.instance.toast != null:
		Manager.instance.toast.notify_report(summary)
	operations_changed.emit()

func _on_quest_state_changed(_state: String, operation: HubOperation) -> void:
	if operation == null:
		return
	var previous_state := operation.state
	operation._refresh()
	if previous_state != operation.state and operation.state in [HubOperation.State.EN_ROUTE, HubOperation.State.IN_PROGRESS, HubOperation.State.RETURNING]:
		var hub := _get_hub()
		if hub != null:
			hub.record_activity(tr("HUB_ACTIVITY_OPERATION_STATE") % [operation.get_display_name(), operation.get_state_name()])
	operations_changed.emit()
	if operation.state == HubOperation.State.COMPLETE and auto_resolve_completed_quests and not operation.reward_resolved:
		operation.reward_resolved = true
		if operation.quest != null:
			operation.quest.context["reward_resolved"] = true
			operation.quest.parse_reward()

func _on_quest_completed(operation: HubOperation) -> void:
	if operation == null:
		return
	operation.state = HubOperation.State.COMPLETE
	operation.reward_resolved = true
	operation.result_text = tr("OPERATION_RESULT_COMPLETED")
	var quest := operation.quest
	var hub := _get_hub()
	if hub != null and not operation.completion_recorded:
		operation.completion_recorded = true
		hub.record_operation_completed(quest)
	_update_spot_after_operation(quest)
	_announce_newly_available_work(quest)
	operations_changed.emit()

func on_quest_completed(quest: Quest) -> void:
	for operation in operations:
		if operation != null and operation.quest == quest:
			_on_quest_completed(operation)
			return

func _update_spot_after_operation(quest: Quest) -> void:
	var hub := _get_hub()
	if hub == null or quest == null or quest.location == null:
		return
	var spot := hub.get_spot(quest.location)
	if spot == null:
		return
	var objective := quest.get_objective()
	var profile := quest.get_profile()
	if profile != null:
		var completion_stage := profile.get_completion_spot_stage(objective)
		if completion_stage != SpotProgress.Stage.UNKNOWN:
			spot.stage = completion_stage
	elif quest.quest_key == "scout":
		spot.stage = SpotProgress.Stage.MAPPED
	spot.last_operation_type = quest.quest_key

func _capture_available_quest_types(quest: Quest) -> void:
	if quest == null:
		return
	var objective := quest.get_objective()
	if objective == null:
		return
	quest.context["available_quest_types_when_posted"] = objective.get_filtered_quest_types().duplicate()

func _announce_newly_available_work(quest: Quest) -> void:
	if quest == null or quest.location == null or Manager.instance == null or Manager.instance.quests == null:
		return
	var objective := quest.get_objective()
	if objective == null:
		return
	var previously_available: Array = quest.context.get("available_quest_types_when_posted", [])
	var postable_types := Manager.instance.quests.get_postable_quest_types(
		quest.location,
		objective.get_filtered_quest_types()
	)
	var labels: Array[String] = []
	for quest_type: String in postable_types:
		if previously_available.has(quest_type):
			continue
		var profile := objective.get_profile(quest_type)
		labels.append(profile.get_display_name() if profile != null else quest_type.capitalize())
	if labels.is_empty():
		return
	var location_name := tr("HUB_UNKNOWN_LOCATION")
	if quest.location.structure != null and quest.location.structure.structure_info != null:
		location_name = quest.location.structure.structure_info.get_display_name()
	var message := tr("QUEST_NEW_WORK_AVAILABLE") % [location_name, ", ".join(labels)]
	var hub := _get_hub()
	if hub != null:
		hub.record_activity(message)
	if Manager.instance.toast != null:
		Manager.instance.toast.notify_report(message)
	Manager.instance.quests.quest_availability_changed.emit()

func get_active_operations() -> Array[HubOperation]:
	var active: Array[HubOperation] = []
	for operation in operations:
		if operation != null and operation.state != HubOperation.State.COMPLETE:
			active.append(operation)
	return active

func _get_hub() -> HubState:
	return Manager.instance.hub if Manager.instance != null else null
