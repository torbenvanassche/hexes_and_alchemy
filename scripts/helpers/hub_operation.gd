class_name HubOperation
extends RefCounted

enum State {
	WAITING,
	EN_ROUTE,
	IN_PROGRESS,
	RETURNING,
	COMPLETE,
	FAILED
}

var id := ""
var quest: Quest
var operation_type := ""
var required_role := ""
var faction_id: StringName = &""
var parent_id := ""
var state: State = State.WAITING
var result_text := ""

func _init(_id: String, _quest: Quest, _parent_id: String = "") -> void:
	id = _id
	quest = _quest
	parent_id = _parent_id
	if quest != null:
		operation_type = quest.quest_key
		_refresh()

func _refresh() -> void:
	if quest == null:
		return
	if quest.is_state(Quest.QuestState.EN_ROUTE):
		state = State.EN_ROUTE
	elif quest.is_state(Quest.QuestState.IN_PROGRESS):
		state = State.IN_PROGRESS
	elif quest.is_state(Quest.QuestState.RETURNING):
		state = State.RETURNING
	elif quest.is_state(Quest.QuestState.COMPLETE):
		state = State.COMPLETE
	else:
		state = State.WAITING

func get_state_name() -> String:
	return State.keys()[state].capitalize().replace("_", " ")
