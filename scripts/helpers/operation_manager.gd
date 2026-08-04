class_name OperationManager
extends Node

signal operations_changed()

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
	if quest.location != null and hub != null:
		hub.mark_operation(quest.location, quest.quest_key)
	operations_changed.emit()
	return operation

func ensure_starting_operation(location: HexBase) -> void:
	if location == null or location.structure == null or Manager.instance == null:
		return
	if Manager.instance.quests.has_quests_for_location(location):
		return
	var objective := location.structure.instance as QuestObjective
	var quest_key := ""
	if objective is AncientRuins:
		quest_key = "survey"
	elif objective is Mineshaft:
		quest_key = "prospect"
	if quest_key == "":
		return
	var quest := Quest.new(location, quest_key, 0, -1)
	quest.context["generated_by_hub"] = true
	Manager.instance.quests.add_quest(quest)

func _on_quest_state_changed(_state: String, operation: HubOperation) -> void:
	if operation == null:
		return
	operation._refresh()
	operations_changed.emit()

func _on_quest_completed(operation: HubOperation) -> void:
	if operation == null:
		return
	operation.state = HubOperation.State.COMPLETE
	operation.result_text = "Completed"
	var quest := operation.quest
	var hub := _get_hub()
	if hub != null:
		hub.record_operation_completed(quest)
	_update_spot_after_operation(quest)
	_create_follow_up(quest, operation.id)
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
	var behaviour := quest.quest_key
	if objective != null:
		behaviour = objective.get_quest_behaviour(quest.quest_key, quest.quest_key)
	match behaviour:
		"survey", "prospect":
			spot.stage = SpotProgress.Stage.SURVEYED
		"secure":
			spot.stage = SpotProgress.Stage.CLEARED
		"delve":
			if objective != null and objective.state_machine.get_current_state() == "DANGEROUS":
				spot.stage = SpotProgress.Stage.DANGEROUS
			else:
				spot.stage = SpotProgress.Stage.CLEARED
		"extract", "forage", "harvest", "timber":
			spot.stage = SpotProgress.Stage.AVAILABLE
		"scout":
			spot.stage = SpotProgress.Stage.MAPPED
	spot.last_operation_type = quest.quest_key

func _create_follow_up(quest: Quest, parent_id: String) -> void:
	if quest == null or quest.location == null or quest.context.get("follow_up_created", false):
		return
	var objective := quest.get_objective()
	var next_key := ""
	var objective_state := objective.state_machine.get_current_state() if objective != null else ""
	if objective is AncientRuins:
		match quest.quest_key:
			"survey":
				next_key = "delve"
			"delve":
				if objective_state == "DANGEROUS":
					next_key = "secure"
			"secure":
				next_key = "salvage"
	elif objective is Mineshaft:
		match quest.quest_key:
			"prospect":
				next_key = "extract"
			"extract":
				if objective_state == "UNSTABLE":
					next_key = "reinforce"
			"reinforce":
				next_key = "extract"
	if next_key == "":
		return
	if Manager.instance != null and Manager.instance.quests.has_quest_for_location_and_type(quest.location, next_key):
		return
	quest.context["follow_up_created"] = true
	var follow_up := Quest.new(quest.location, next_key, 0, -1)
	follow_up.context["parent_operation_id"] = parent_id
	follow_up.context["generated_by_hub"] = true
	Manager.instance.quests.add_quest(follow_up)

func get_active_operations() -> Array[HubOperation]:
	var active: Array[HubOperation] = []
	for operation in operations:
		if operation != null and operation.state != HubOperation.State.COMPLETE:
			active.append(operation)
	return active

func _get_hub() -> HubState:
	return Manager.instance.hub if Manager.instance != null else null
