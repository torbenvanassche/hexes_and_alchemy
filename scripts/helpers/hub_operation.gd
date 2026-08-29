class_name HubOperation
extends RefCounted

enum State {
	WAITING,
	EN_ROUTE,
	IN_PROGRESS,
	RETURNING,
	COMPLETE,
	FAILED,
	CANCELLED
}

var id := ""
var quest: Quest
var operation_type := ""
var required_role := ""
var faction_id: StringName = &""
var parent_id := ""
var state: State = State.WAITING
var result_text := ""
var assigned_npcs: Array[NPC] = []
var reward_resolved := false
var completion_recorded := false

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
	assigned_npcs.clear()
	for npc in quest.party:
		if npc != null and is_instance_valid(npc):
			assigned_npcs.append(npc)
	if quest.is_state(Quest.QuestState.EN_ROUTE):
		state = State.EN_ROUTE
	elif quest.is_state(Quest.QuestState.IN_PROGRESS):
		state = State.IN_PROGRESS
	elif quest.is_state(Quest.QuestState.RETURNING):
		state = State.RETURNING
	elif quest.is_state(Quest.QuestState.COMPLETE):
		state = State.COMPLETE
	elif quest.is_state(Quest.QuestState.FAILED):
		state = State.FAILED
	elif quest.is_state(Quest.QuestState.CANCELLED):
		state = State.CANCELLED
	else:
		state = State.WAITING

func get_state_name() -> String:
	var state_key := "OPERATION_STATE_%s" % State.keys()[state]
	var translated := tr(state_key)
	return translated if translated != state_key else State.keys()[state].capitalize().replace("_", " ")

func get_display_name() -> String:
	if quest != null:
		var profile := quest.get_profile()
		if profile != null:
			return profile.get_display_name()
	var translation_key := "QUEST_TYPE_%s" % operation_type.to_upper()
	var translated := tr(translation_key)
	return operation_type.capitalize().replace("_", " ") if translated == translation_key else translated

func get_activity_name() -> String:
	if quest == null:
		return tr("OPERATION_ACTIVITY_IDLE")
	if state == State.WAITING:
		return tr("OPERATION_ACTIVITY_WAITING")
	if state == State.EN_ROUTE:
		return tr("OPERATION_ACTIVITY_EN_ROUTE")
	if state == State.IN_PROGRESS:
		return tr("OPERATION_ACTIVITY_IN_PROGRESS")
	if state == State.RETURNING:
		return tr("OPERATION_ACTIVITY_RETURNING")
	if state == State.FAILED:
		return tr("OPERATION_ACTIVITY_FAILED")
	if state == State.CANCELLED:
		return tr("OPERATION_ACTIVITY_CANCELLED")
	return tr("OPERATION_ACTIVITY_COMPLETE")

func get_assigned_npc_names() -> String:
	var names: Array[String] = []
	for npc in assigned_npcs:
		if npc == null or not is_instance_valid(npc):
			continue
		names.append(npc.get_display_name())
	return ", ".join(names) if not names.is_empty() else tr("OPERATION_UNASSIGNED")
