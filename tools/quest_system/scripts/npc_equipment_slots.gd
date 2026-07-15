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
