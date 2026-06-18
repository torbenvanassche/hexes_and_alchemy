class_name GameState extends Resource

var active_quests: Array[Quest] = [];
signal quest_list_changed();
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

func remove_quest(q: Quest) -> void:
	active_quests.erase(q)
	quest_list_changed.emit();
