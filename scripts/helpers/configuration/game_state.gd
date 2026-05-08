class_name GameState extends Resource

var active_quests: Array[Quest] = [];
signal quest_list_changed();

func add_quest(q: Quest) -> void:
	if not active_quests.has(q):
		active_quests.append(q);
		quest_list_changed.emit();

func remove_quest(q: Quest) -> void:
	active_quests.erase(q)
	quest_list_changed.emit();
	
func assign_quest(npc: NPC) -> Quest:
	var q: Quest = active_quests.pick_random();
	q.add_to_party(npc);
	return q;
