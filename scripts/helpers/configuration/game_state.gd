class_name GameState extends Resource

var active_quests: Array[Quest] = [];

func add_quest(q: Quest) -> void:
	if not active_quests.has(q):
		active_quests.append(q);
