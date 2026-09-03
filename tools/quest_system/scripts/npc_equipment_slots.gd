class_name NpcEquipmentSlots
extends Resource

@export var weapon: EquipmentInfo
@export var armor: EquipmentInfo
@export var tool: EquipmentInfo
@export var accessory: EquipmentInfo

func get_equipped_items() -> Array[EquipmentInfo]:
	var items: Array[EquipmentInfo] = []
	if weapon != null:
		items.append(weapon)
	if armor != null:
		items.append(armor)
	if tool != null:
		items.append(tool)
	if accessory != null:
		items.append(accessory)
	return items

func clear() -> void:
	weapon = null
	armor = null
	tool = null
	accessory = null
	emit_changed()

func get_success_weight_multiplier(quest: Quest) -> float:
	var multiplier := 1.0
	for item in get_equipped_items():
		if item.applies_to_quest(quest):
			multiplier *= item.success_weight_multiplier
	return multiplier

func get_danger_weight_multiplier(quest: Quest) -> float:
	var multiplier := 1.0
	for item in get_equipped_items():
		if item.applies_to_quest(quest):
			multiplier *= item.danger_weight_multiplier
	return multiplier

func get_injury_chance_multiplier() -> float:
	var multiplier := 1.0
	for item in get_equipped_items():
		multiplier *= item.injury_chance_multiplier
	return multiplier

func get_death_chance_multiplier() -> float:
	var multiplier := 1.0
	for item in get_equipped_items():
		multiplier *= item.death_chance_multiplier
	return multiplier

func get_quest_duration_multiplier(quest: Quest) -> float:
	var multiplier := 1.0
	for item in get_equipped_items():
		if item.applies_to_quest(quest):
			multiplier *= item.quest_duration_multiplier
	return multiplier

func get_loot_quantity_multiplier(quest: Quest) -> float:
	var multiplier := 1.0
	for item in get_equipped_items():
		if item.applies_to_quest(quest):
			multiplier *= item.loot_quantity_multiplier
	return multiplier

func get_scouting_radius_bonus() -> int:
	var bonus := 0
	for item in get_equipped_items():
		bonus += item.scouting_radius_bonus
	return bonus
