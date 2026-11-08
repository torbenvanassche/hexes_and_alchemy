class_name CommissionSaveState
extends RefCounted
## Restore bindings after world, roster, site state and navigation all exist.
## Routes are recalculated from saved positions, not serialized movement paths.

static func restore_bindings(quest: Quest, codec: SaveCodec) -> void:
	var fates: Dictionary[int, int] = {}
	for old_id: int in quest.party_fates:
		var member := codec.npcs.get(str(old_id)) as NPC
		if is_instance_valid(member): fates[member.get_instance_id()] = quest.party_fates[old_id]
	quest.party_fates = fates
	if not quest.uses_guild_roster() or quest.context.get("reward_claimed", false): return
	if quest.is_state(Quest.QuestState.FAILED) or quest.is_state(Quest.QuestState.CANCELLED): return
	for member: NPC in quest.party:
		if not is_instance_valid(member): continue
		member.assign_quest(quest)
		var position: Variant = quest.context.get("saved_party_positions", {}).get(str(member.get_instance_id()))
		if position is Vector3: member.global_position = position

static func resume(quest: Quest) -> void:
	if not quest.uses_guild_roster() or quest.context.get("reward_claimed", false): return
	if quest.is_state(Quest.QuestState.WAITING): return
	if quest.party.is_empty() or quest.party.any(func(member: NPC) -> bool: return not is_instance_valid(member)):
		Manager.instance.quests.fail_quest(quest, "QUEST_FAILED_MISSING_OBJECTIVE")
		return
	if quest.is_state(Quest.QuestState.RETURNING):
		quest.return_from_quest()
	elif quest.is_state(Quest.QuestState.IN_PROGRESS):
		for member: NPC in quest.party:
			member.global_position = quest.location.global_position
			member.set_state(NPC.NPCState.AT_QUEST)
		quest._check_party_arrived_at_quest()
	elif quest.is_state(Quest.QuestState.EN_ROUTE):
		quest.start()
	elif quest.is_state(Quest.QuestState.COMPLETE):
		for member: NPC in quest.party: member.set_state(NPC.NPCState.DONE)
		if Manager.instance.operations.auto_resolve_completed_quests: quest.parse_reward()
