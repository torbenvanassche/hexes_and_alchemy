class_name HubState
extends Node

signal changed()
signal faction_activity_changed()
signal activity_log_changed()

@export var starting_currency := 100
var currency := 0
var prestige := 0
var stockpile: ContentGroup
var factions: Dictionary[StringName, FactionState] = {}
var spots: Dictionary[Vector3i, SpotProgress] = {}
var activity_log: Array[String] = []
@export_range(4, 64, 1) var max_activity_entries := 24

const FACTION_DEFINITIONS: Array[FactionDefinition] = [
	preload("res://resources/faction_definitions/hunters.tres"),
	preload("res://resources/faction_definitions/adventurers.tres"),
	preload("res://resources/faction_definitions/crafters.tres"),
	preload("res://resources/faction_definitions/tenders.tres"),
]

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
	for definition: FactionDefinition in FACTION_DEFINITIONS:
		if definition == null:
			continue
		var faction := FactionState.new(definition.id, definition.display_name, definition.roles, definition.responsibilities)
		faction.apply_definition(definition)
		factions[definition.id] = faction

func get_required_role_for_quest(quest: Quest) -> String:
	if quest == null:
		return ""
	var profile := quest.get_profile()
	if profile != null and profile.required_role != "":
		return profile.required_role
	var job_key := profile.get_behaviour() if profile != null else quest.quest_key
	match job_key:
		"scout", "survey":
			return "hunter"
		"prospect", "extract", "deepen":
			return "delver"
		"reinforce", "maintain", "reopen":
			return "crafter"
		"forage", "harvest", "plant", "water", "replant", "purify", "clear", "fill", "draw":
			return "tender"
		"delve", "salvage":
			return "delver"
		"secure":
			return "security"
		_:
			return ""

func register_npc(npc: NPC) -> void:
	if npc == null:
		return
	var faction := get_faction_for_npc(npc)
	if faction != null:
		faction.add_member(npc)
		if not npc.activity_changed.is_connected(_on_npc_activity_changed):
			npc.activity_changed.connect(_on_npc_activity_changed)
		if not npc.rest_progress_changed.is_connected(_on_npc_activity_changed):
			npc.rest_progress_changed.connect(_on_npc_activity_changed)
		changed.emit()

func unregister_npc(npc: NPC) -> void:
	if npc != null and npc.activity_changed.is_connected(_on_npc_activity_changed):
		npc.activity_changed.disconnect(_on_npc_activity_changed)
	if npc != null and npc.rest_progress_changed.is_connected(_on_npc_activity_changed):
		npc.rest_progress_changed.disconnect(_on_npc_activity_changed)
	for faction: FactionState in factions.values():
		faction.remove_member(npc)
	changed.emit()

func _on_npc_activity_changed(_npc: NPC) -> void:
	faction_activity_changed.emit()

func record_activity(message: String) -> void:
	if message == "":
		return
	activity_log.push_front(message)
	if activity_log.size() > max_activity_entries:
		activity_log.resize(max_activity_entries)
	activity_log_changed.emit()

func get_activity_log() -> Array[String]:
	return activity_log.duplicate()

func get_faction_for_roles(roles: Array[String]) -> FactionState:
	for faction: FactionState in factions.values():
		for role in roles:
			if faction.roles.has(role):
				return faction
	return factions.get(&"adventurers") as FactionState

func get_faction_for_npc(npc: NPC) -> FactionState:
	if npc == null:
		return factions.get(&"adventurers") as FactionState
	if npc.npc_info != null and npc.npc_info.faction_id != &"":
		var configured_faction := factions.get(npc.npc_info.faction_id) as FactionState
		if configured_faction != null:
			return configured_faction
	return get_faction_for_roles(npc.get_operation_roles())

func get_faction_for_quest(quest: Quest) -> FactionState:
	if quest != null:
		for faction: FactionState in factions.values():
			if faction.definition != null and faction.definition.preferred_quest_types.has(quest.quest_key):
				return faction
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
	spot.mark_mapped()
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
		faction.last_activity = tr("HUB_ACTIVITY_COMPLETED")
	record_activity(tr("HUB_ACTIVITY_COMPLETED") % _get_operation_label(quest))
	changed.emit()

func _get_operation_label(quest: Quest) -> String:
	if quest == null:
		return tr("HUB_UNKNOWN_OPERATION")
	var operation_key := "QUEST_TYPE_%s" % quest.quest_key.to_upper()
	var operation_name := tr(operation_key)
	return quest.quest_key.capitalize() if operation_name == operation_key else operation_name

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
