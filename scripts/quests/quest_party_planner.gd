class_name QuestPartyPlanner
extends RefCounted

class Assignment extends RefCounted:
	var quest: Quest
	var primary: NPC
	var supports: Dictionary[StringName, NPC] = {}
	var members: Array[NPC] = []
	var score := 0.0

static func build(quest: Quest, available_npcs: Array[NPC]) -> Assignment:
	if quest == null:
		return null

	var best_assignment: Assignment = null
	for primary: NPC in available_npcs:
		if primary == null or not primary.wants_quest(quest):
			continue

		var remaining := available_npcs.duplicate()
		remaining.erase(primary)
		var support_assignments: Dictionary[StringName, NPC] = {}
		var members: Array[NPC] = [primary]
		var score := primary.evaluate_quest(quest)
		var complete := true

		for definition: QuestSupportDefinition in quest.get_selected_support_definitions():
			var support_npc := _get_best_support_npc(quest, definition, remaining)
			if support_npc == null:
				complete = false
				break
			support_assignments[definition.id] = support_npc
			members.append(support_npc)
			remaining.erase(support_npc)
			score += support_npc.evaluate_quest_for_role(quest, definition.provider_role) * 0.25

		if not complete:
			continue
		if best_assignment == null or score > best_assignment.score:
			best_assignment = Assignment.new()
			best_assignment.quest = quest
			best_assignment.primary = primary
			best_assignment.supports = support_assignments
			best_assignment.members = members
			best_assignment.score = score
	return best_assignment

static func _get_best_support_npc(
	quest: Quest,
	definition: QuestSupportDefinition,
	available_npcs: Array[NPC]
) -> NPC:
	if definition == null or definition.provider_role == "":
		return null
	var best_npc: NPC = null
	var best_score := -1.0
	for npc: NPC in available_npcs:
		if npc == null or not npc.can_consider_quest_for_role(quest, definition.provider_role):
			continue
		var score := npc.evaluate_quest_for_role(quest, definition.provider_role)
		if best_npc == null or score > best_score:
			best_npc = npc
			best_score = score
	return best_npc

static func commit(assignment: Assignment) -> bool:
	var quest := assignment.quest
	var primary := assignment.primary
	if quest == null or primary == null or not quest.add_to_party(primary):
		return false

	var supports: Dictionary[StringName, NPC] = assignment.supports
	for support_id: StringName in supports:
		var support_npc := supports[support_id] as NPC
		if support_npc != null and quest.add_to_party(support_npc, support_id):
			continue
		for assigned_npc: NPC in quest.party.duplicate():
			if assigned_npc != null:
				assigned_npc.cancel_assigned_quest(quest)
		quest.clear_party_assignments()
		return false
	return true

