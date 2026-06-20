class_name GameState extends Resource

var active_quests: Array[Quest] = [];

signal quest_list_changed();
@warning_ignore("unused_signal")
signal quest_availability_changed();

var max_active_quest: int = 10;
var max_npc_per_tavern: int = 5;

var max_quest_distance: int = 50;

func has_quest_for_location_and_type(location: HexBase, quest_type: String) -> bool:
	return active_quests.any(func(q: Quest) -> bool:
		return q != null and q.location == location and q.quest_key == quest_type
	)

func get_available_quest_types(location: HexBase, quest_types: Array[String]) -> Array[String]:
	var available_types: Array[String] = []
	for quest_type: String in quest_types:
		if not has_quest_for_location_and_type(location, quest_type):
			available_types.append(quest_type)
	return available_types

func add_quest(q: Quest) -> void:
	if not active_quests.has(q):
		active_quests.append(q);
		quest_list_changed.emit();
		try_assign_waiting_quests()

func remove_quest(q: Quest) -> void:
	active_quests.erase(q)
	quest_list_changed.emit();

func try_assign_waiting_quests() -> void:
	var tavern := _get_active_tavern()
	if tavern == null:
		return

	var available_npcs := tavern.get_available_npcs()
	if available_npcs.is_empty():
		return

	for quest: Quest in active_quests:
		if quest == null or not quest.is_state(Quest.QuestState.WAITING) or not quest.party.is_empty():
			continue
		if available_npcs.is_empty():
			return

		quest.add_to_party(available_npcs.pick_random().node as NPC)
		quest.start()

func _get_active_tavern() -> Tavern:
	var settlement := Manager.instance.active_settlement
	if settlement == null:
		return null

	for interaction: Interaction in settlement.interactions:
		if interaction is Tavern:
			return interaction as Tavern
	return null
