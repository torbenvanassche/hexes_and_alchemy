class_name AdventurerModifiers
extends RefCounted

static func get_equipment_success_multiplier(npc: NPC, quest: Quest) -> float:
	var multiplier := npc.equipment.get_success_weight_multiplier(quest) if npc.equipment != null else 1.0
	for injury in npc.active_injuries:
		multiplier *= injury.success_weight_multiplier
	return multiplier

static func get_equipment_danger_multiplier(npc: NPC, quest: Quest) -> float:
	var multiplier := npc.equipment.get_danger_weight_multiplier(quest) if npc.equipment != null else 1.0
	for injury in npc.active_injuries:
		multiplier *= injury.danger_weight_multiplier
	return multiplier

static func get_equipment_duration_multiplier(npc: NPC, quest: Quest) -> float:
	var multiplier := npc.equipment.get_quest_duration_multiplier(quest) if npc.equipment != null else 1.0
	for injury in npc.active_injuries:
		multiplier *= injury.quest_duration_multiplier
	return multiplier

static func get_equipment_loot_multiplier(npc: NPC, quest: Quest) -> float:
	var multiplier := npc.equipment.get_loot_quantity_multiplier(quest) if npc.equipment != null else 1.0
	for injury in npc.active_injuries:
		multiplier *= injury.loot_quantity_multiplier
	return multiplier

