class_name GameState extends Resource

var active_quests: Array[Quest] = [];
signal quest_list_changed();
var max_active_quest: int = 10;
var max_npc_per_tavern: int = 5;

var max_quest_distance: int = 50;

func add_quest(q: Quest) -> void:
	if not active_quests.has(q):
		active_quests.append(q);
		quest_list_changed.emit();

func remove_quest(q: Quest) -> void:
	active_quests.erase(q)
	quest_list_changed.emit();
