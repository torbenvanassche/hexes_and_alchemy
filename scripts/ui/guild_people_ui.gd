extends VBoxContainer

const FACTION_CARD := preload("res://scenes/ui/components/faction_overview_card.tscn")
const NPC_DETAILS_WINDOW := preload("res://resources/scene_info/ui/npc_details_ui.tres")

@onready var faction_tabs: HBoxContainer = $FactionTabs
@onready var faction_details: VBoxContainer = $FactionDetails

var active_faction_id: StringName = &"hunters"
var _refresh_pending := false
var detail_windows: Dictionary[int, SceneInstance] = {}

func show_faction(faction_id: StringName) -> void:
	if Manager.instance.hub.factions.has(faction_id):
		active_faction_id = faction_id
	_refresh()

func _ready() -> void:
	if Manager.instance != null and Manager.instance.hub != null:
		Manager.instance.hub.changed.connect(_queue_refresh)
		Manager.instance.hub.faction_activity_changed.connect(_queue_refresh)
	_refresh()

func _queue_refresh() -> void:
	if _refresh_pending or not is_inside_tree():
		return
	_refresh_pending = true
	_refresh.call_deferred()

func _refresh() -> void:
	_refresh_pending = false
	if not is_inside_tree() or Manager.instance == null or Manager.instance.hub == null:
		return
	var factions: Dictionary = Manager.instance.hub.factions
	if not factions.has(active_faction_id) and not factions.is_empty():
		active_faction_id = factions.keys()[0]
	for child in faction_tabs.get_children():
		faction_tabs.remove_child(child)
		child.queue_free()
	for faction: FactionState in factions.values():
		var tab := Button.new()
		tab.text = "%s · %d" % [faction.get_display_name(), faction.members.filter(func(member: NPC) -> bool: return is_instance_valid(member)).size()]
		tab.theme_type_variation = &"TabButton"
		tab.toggle_mode = true
		tab.set_pressed_no_signal(faction.id == active_faction_id)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size.y = 40
		tab.pressed.connect(_select_faction.bind(faction.id))
		faction_tabs.add_child(tab)
	_refresh_details()

func _select_faction(faction_id: StringName) -> void:
	active_faction_id = faction_id
	var factions: Array = Manager.instance.hub.factions.values()
	for index in faction_tabs.get_child_count():
		(faction_tabs.get_child(index) as Button).set_pressed_no_signal(factions[index].id == active_faction_id)
	_refresh_details()

func _refresh_details() -> void:
	var faction := Manager.instance.hub.factions.get(active_faction_id) as FactionState
	if faction == null:
		return
	var card := faction_details.get_child(0) as FactionOverviewCardUI if faction_details.get_child_count() > 0 else null
	if card == null:
		card = FACTION_CARD.instantiate() as FactionOverviewCardUI
		faction_details.add_child(card)
		card.details_requested.connect(_open_npc_details)
	card.setup(faction)

func _open_npc_details(npc: NPC) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	var npc_id := npc.get_instance_id()
	var existing := detail_windows.get(npc_id) as SceneInstance
	if existing != null and is_instance_valid(existing.node):
		if "visible" in existing.node:
			existing.node.visible = true
		SceneManager.promote_scene_instance(existing)
		var existing_ui := (existing.node as DraggableControl).content as NpcDetailsUI
		if existing_ui != null:
			existing_ui.setup_npc(npc)
			existing.on_enter.emit()
		return

	var window_instance := SceneManager.add(NPC_DETAILS_WINDOW, false)
	if window_instance == null:
		return
	var details_ui := (window_instance.node as DraggableControl).content as NpcDetailsUI
	if details_ui == null:
		return
	details_ui.setup_npc(npc)
	window_instance.on_enter.emit()
	detail_windows[npc_id] = window_instance
	if not npc.tree_exiting.is_connected(_close_npc_details.bind(npc_id)):
		npc.tree_exiting.connect(_close_npc_details.bind(npc_id), CONNECT_ONE_SHOT)

func _close_npc_details(npc_id: int) -> void:
	var window_instance := detail_windows.get(npc_id) as SceneInstance
	detail_windows.erase(npc_id)
	if window_instance != null and is_instance_valid(window_instance):
		window_instance.destroy()
