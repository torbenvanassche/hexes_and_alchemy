class_name HubState
extends Node

signal changed()

@export var starting_currency := 100
var currency := 0
var prestige := 0
var stockpile: ContentGroup
var factions: Dictionary[StringName, FactionState] = {}
var spots: Dictionary[Vector3i, SpotProgress] = {}

func _ready() -> void:
	currency = starting_currency
	var hub_inventory := Inventory.new()
	hub_inventory.stack_size = 99
	hub_inventory.unlocked_slots = 30
	hub_inventory.max_slots = 30
	stockpile = hub_inventory
	stockpile.name = "HubStockpile"
	add_child(stockpile)
	stockpile.changed.connect(changed.emit)
	_initialize_factions()

func _initialize_factions() -> void:
	factions.clear()
	factions[&"hunters"] = FactionState.new(&"hunters", "Hunters", ["hunter", "laborer"], ["Explore and map new locations", "Gather food and timber"])
	factions[&"adventurers"] = FactionState.new(&"adventurers", "Adventurers", ["adventurer"], ["Handle dangerous locations", "Secure mines and ruins"])
	factions[&"crafters"] = FactionState.new(&"crafters", "Crafters", ["crafter"], ["Turn materials into equipment", "Maintain guild supplies"])
	factions[&"tenders"] = FactionState.new(&"tenders", "Tenders", ["tender"], ["Maintain the settlement", "Support farming and water"])

func get_required_role_for_quest(quest: Quest) -> String:
	if quest == null:
		return ""
	match quest.quest_key:
		"scout", "survey", "prospect":
			return "hunter"
		"forage", "harvest", "plant", "water", "replant", "purify":
			return "laborer"
		"delve", "secure", "salvage", "extract", "deepen", "reinforce":
			return "adventurer"
		_:
			return ""

func register_npc(npc: NPC) -> void:
	if npc == null:
		return
	var faction := get_faction_for_roles(npc.get_operation_roles())
	if faction != null:
		faction.add_member(npc)
		changed.emit()

func unregister_npc(npc: NPC) -> void:
	for faction: FactionState in factions.values():
		faction.remove_member(npc)
	changed.emit()

func get_faction_for_roles(roles: Array[String]) -> FactionState:
	for faction: FactionState in factions.values():
		for role in roles:
			if faction.roles.has(role):
				return faction
	return factions.get(&"adventurers") as FactionState

func get_faction_for_quest(quest: Quest) -> FactionState:
	var required_role := get_required_role_for_quest(quest)
	for faction: FactionState in factions.values():
		if faction.roles.has(required_role):
			return faction
	return factions.get(&"adventurers") as FactionState

func get_spot(hex: HexBase) -> SpotProgress:
	if hex == null:
		return null
	if spots.has(hex.cube_id):
		var existing := spots[hex.cube_id] as SpotProgress
		if existing != null and existing.structure_id == "" and hex.structure != null and hex.structure.structure_info != null:
			existing.structure_id = hex.structure.structure_info.id
		return existing
	var structure_id := ""
	if hex.structure != null and hex.structure.structure_info != null:
		structure_id = hex.structure.structure_info.id
	var spot := SpotProgress.new(hex.cube_id, structure_id)
	spots[hex.cube_id] = spot
	return spot

func mark_mapped(hex: HexBase) -> void:
	var spot := get_spot(hex)
	if spot == null:
		return
	var was_unknown := spot.stage == SpotProgress.Stage.UNKNOWN
	spot.mark_mapped()
	if was_unknown and Manager.instance != null and Manager.instance.operations != null:
		Manager.instance.operations.ensure_starting_operation(hex)
	changed.emit()

func mark_operation(hex: HexBase, operation_type: String) -> void:
	var spot := get_spot(hex)
	if spot == null:
		return
	spot.mark_operation(operation_type)
	changed.emit()

func deposit_items(items: Dictionary[ItemInfo, int]) -> void:
	if stockpile == null:
		return
	for item: ItemInfo in items.keys():
		if item == null:
			continue
		var amount := maxi(0, int(items[item]))
		if amount > 0:
			stockpile.add(item, amount, true)
	changed.emit()

func adopt_inventory(source: ContentGroup) -> void:
	if source == null or stockpile == null or source == stockpile:
		return
	var items: Dictionary[ItemInfo, int] = {}
	for slot: ContentSlotResource in source.data:
		if slot == null or slot.get_content() == null or slot.count <= 0:
			continue
		var item := slot.get_content() as ItemInfo
		if item != null:
			items[item] = items.get(item, 0) + slot.count
	if items.is_empty():
		return
	deposit_items(items)
	for slot: ContentSlotResource in source.data:
		if slot == null:
			continue
		slot.count = 0
		slot.reset()
		slot.changed.emit()
	source.changed.emit()

func withdraw_items(items: Dictionary[ItemInfo, int]) -> bool:
	if stockpile == null or not stockpile.has_all(items):
		return false
	for item: ItemInfo in items.keys():
		stockpile.remove(item, int(items[item]))
	changed.emit()
	return true

func add_currency(amount: int) -> void:
	currency = maxi(0, currency + amount)
	changed.emit()

func reserve_currency(amount: int) -> bool:
	if amount < 0 or currency < amount:
		return false
	currency -= amount
	changed.emit()
	return true

func add_prestige(amount: int) -> void:
	prestige = maxi(0, prestige + amount)
	changed.emit()

func record_operation_completed(quest: Quest) -> void:
	var faction := get_faction_for_quest(quest)
	if faction != null:
		faction.completed_operations += 1
	changed.emit()

func get_stockpile_summary() -> String:
	if stockpile == null:
		return "Stockpile: empty"
	var entries: Array[String] = []
	for slot: ContentSlotResource in stockpile.data:
		if slot == null or slot.get_content() == null or slot.count <= 0:
			continue
		var content := slot.get_content() as ItemInfo
		if content != null:
			entries.append("%s x%s" % [content.get_display_name(), slot.count])
	if entries.is_empty():
		return "Stockpile: empty"
	return "Stockpile: " + ", ".join(entries)
