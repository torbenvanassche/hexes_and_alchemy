class_name Alchemist extends SettlementService

@export_range(0, 100, 1) var enchantment_cost := 25

signal services_changed()

func interact() -> void:
	open_additional_ui_windows()

func can_interact() -> bool:
	return true

func get_adventurers() -> Array[NPC]:
	var result: Array[NPC] = []
	var owner_settlement := get_settlement()
	if owner_settlement == null:
		return result
	for service in owner_settlement.get_services(&"FactionHome"):
		var home := service as FactionHome
		if home == null:
			continue
		for instance in home.get_roster_npcs():
			var npc := instance.node as NPC
			if npc != null:
				result.append(npc)
	return result

func get_relics() -> Array[EquipmentInfo]:
	var result: Array[EquipmentInfo] = []
	if Manager.instance == null or Manager.instance.hub == null or Manager.instance.hub.stockpile == null:
		return result
	for slot in Manager.instance.hub.stockpile.data:
		var item := slot.get_content() as EquipmentInfo if slot != null else null
		if item != null and item.tier == EquipmentInfo.Tier.RELIC and not result.has(item):
			result.append(item)
	return result

func treat_injury(npc: NPC, injury: AdventurerInjury) -> bool:
	if npc == null or injury == null or npc.current_quest != null or Manager.instance == null or Manager.instance.hub == null:
		return false
	if not Manager.instance.hub.reserve_currency(injury.treatment_cost):
		return false
	if not npc.treat_injury(injury):
		Manager.instance.hub.add_currency(injury.treatment_cost)
		return false
	services_changed.emit()
	if Manager.instance.toast != null:
		Manager.instance.toast.notify(tr("ALCHEMIST_TREATMENT_NOTICE") % [npc.get_display_name(), injury.get_display_name()])
	return true

func enchant_relic(item: EquipmentInfo) -> bool:
	if item == null or item.tier != EquipmentInfo.Tier.RELIC or Manager.instance == null or Manager.instance.hub == null:
		return false
	var stockpile := Manager.instance.hub.stockpile
	if stockpile == null or stockpile.get_count(item) <= 0 or not Manager.instance.hub.reserve_currency(enchantment_cost):
		return false
	if stockpile.remove(item, 1) != 0:
		Manager.instance.hub.add_currency(enchantment_cost)
		return false
	var enchanted := item.create_randomized_relic()
	if enchanted == null:
		stockpile.add(item, 1, true)
		Manager.instance.hub.add_currency(enchantment_cost)
		return false
	stockpile.add(enchanted, 1, true)
	services_changed.emit()
	if Manager.instance.toast != null:
		Manager.instance.toast.notify(tr("ALCHEMIST_ENCHANT_NOTICE") % enchanted.get_display_name())
	return true
