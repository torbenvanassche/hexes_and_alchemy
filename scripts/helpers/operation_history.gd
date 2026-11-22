class_name OperationHistory
extends RefCounted

const FULL_RECORDS := 48
const REPORT_LIMIT := 160

static func trim(manager: OperationManager) -> void:
	var settled: Array[HubOperation] = []
	for operation: HubOperation in manager.operations:
		if operation.quest == null: continue
		if Manager.instance.quests.active_quests.has(operation.quest): continue
		if operation.state == HubOperation.State.COMPLETE and not operation.reward_resolved: continue
		if operation.state in [HubOperation.State.COMPLETE, HubOperation.State.CANCELLED, HubOperation.State.FAILED]:
			settled.append(operation)
	while settled.size() > FULL_RECORDS:
		var operation: HubOperation = settled.pop_front()
		var quest := operation.quest
		manager.reports.append({"id": operation.id, "name": operation.get_display_name(), "state": operation.get_state_name(), "result": operation.result_text})
		for connection: Dictionary in quest.state_machine.state_entered.get_connections():
			if connection.callable == manager._on_quest_state_changed.bind(operation): quest.state_machine.state_entered.disconnect(connection.callable)
		if quest.completed.is_connected(manager._on_quest_completed.bind(operation)): quest.completed.disconnect(manager._on_quest_completed.bind(operation))
		if quest.outcome_ready.is_connected(manager._on_quest_outcome_ready.bind(operation)): quest.outcome_ready.disconnect(manager._on_quest_outcome_ready.bind(operation))
		manager.operations.erase(operation)
		operation.quest = null
	while manager.reports.size() > REPORT_LIMIT: manager.reports.pop_front()
