class_name TavernRosterUI
extends PanelContainer

const NPC_DETAILS_WINDOW := preload("res://resources/scene_info/ui/npc_details_ui.tres")
const ROSTER_ROW_SCENE := preload("res://scenes/ui/components/tavern_roster_row.tscn")

@onready var roster_rows: VBoxContainer = $MarginContainer/VBoxContainer/RosterRows
@onready var empty_label: Label = $MarginContainer/VBoxContainer/EmptyRosterLabel

var tavern: Tavern
var detail_windows: Dictionary[int, SceneInstance] = {}

func setup_interaction(interaction: Interaction) -> void:
	var new_tavern := interaction as Tavern
	if tavern != null and tavern.npc_roster_changed.is_connected(_refresh_roster):
		tavern.npc_roster_changed.disconnect(_refresh_roster)
	tavern = new_tavern
	if tavern != null and not tavern.npc_roster_changed.is_connected(_refresh_roster):
		tavern.npc_roster_changed.connect(_refresh_roster)

func _ready() -> void:
	if Manager.instance != null and Manager.instance.quests != null and not Manager.instance.quests.quest_list_changed.is_connected(_refresh_roster):
		Manager.instance.quests.quest_list_changed.connect(_refresh_roster)

func on_enter() -> void:
	_refresh_roster()

func _refresh_roster() -> void:
	if roster_rows == null:
		return
	for child in roster_rows.get_children():
		roster_rows.remove_child(child)
		child.queue_free()

	var roster: Array[SceneInstance] = tavern.get_roster_npcs() if tavern != null else []
	empty_label.visible = roster.is_empty()

	for npc_scene_instance in roster:
		var npc := npc_scene_instance.node as NPC
		if npc != null:
			var row := _create_roster_row(npc) as TavernRosterRowUI
			roster_rows.add_child(row)
			row.setup(npc)

func _create_roster_row(npc: NPC) -> Control:
	var row := ROSTER_ROW_SCENE.instantiate() as TavernRosterRowUI
	row.details_requested.connect(_open_npc_details.bind(npc))
	return row

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
