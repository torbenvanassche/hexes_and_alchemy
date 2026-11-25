class_name QuestListUI extends Control

@onready var create_quest_button: Button = $Layout/Actions/CreateQuestButton
@onready var scout_quest_button: Button = $Layout/Actions/ScoutQuestButton
@onready var auto_resolve_button: Button = $Layout/Actions/AutoResolveButton
@onready var board_surface: Control = $Layout/Scroll/Content/BoardSurface
@onready var empty_label: Control = $Layout/Scroll/Content/EmptyState
@onready var scroll: ScrollContainer = $Layout/Scroll
@onready var request_table: VBoxContainer = $Layout/Scroll/Content/RequestTable
@onready var request_list: VBoxContainer = request_table.get_node("Requests")
@onready var completed_button: Button = $Layout/Scroll/Content/Completed
@onready var back_button: Button = $Layout/Back
@onready var repeat_button: Button = $Layout/Actions/RepeatLast
@onready var request_footer: VBoxContainer = $Layout/RequestFooter
@onready var request_details: CommunityProjectsUI = $Layout/Scroll/Content/RequestDetails
var active_tab := "guild"
var selected_request := ""
var _show_completed := false
var _refresh_gate: RefreshGate
var _board_gate: RefreshGate

@export var quest_item_ui: PackedScene
@export var board_margin: float = 20.0
@export var note_spacing: Vector2 = Vector2(16.0, 14.0)
var window_instance: SceneInstance;
var auto_resolve_enabled := false

func on_enter() -> void:
	_sync_auto_resolve_button()
	for c: QuestListItemUI in _get_quest_notes():
		if not Manager.instance.quests.get_commissions().has(c.questData):
			c.queue_free()
		else:
			c.set_auto_resolve_enabled(auto_resolve_enabled)
			c.refresh_scout_departure()

	for q: Quest in Manager.instance.quests.get_commissions():
		if _find_note_for_quest(q) == null:
			var instance: QuestListItemUI = quest_item_ui.instantiate();
			board_surface.add_child(instance);
			instance.set_auto_resolve_enabled(auto_resolve_enabled)
			instance.set_data(q);

	_refresh_requests()
	_allow_quest_creation_allowed()
	_layout_board()
	
	if not Manager.instance.quests.quest_availability_changed.is_connected(_allow_quest_creation_allowed):
		Manager.instance.quests.quest_availability_changed.connect(_allow_quest_creation_allowed)
	
func _allow_quest_creation_allowed() -> void:
	create_quest_button.disabled = not _has_available_quests_to_create()
	create_quest_button.tooltip_text = tr("QUEST_BOARD_FIND_TARGET") if create_quest_button.disabled else ""
	scout_quest_button.disabled = not _has_available_scouting_to_create()
	scout_quest_button.theme_type_variation = &"PrimaryButton" if create_quest_button.disabled else &"Button"
	
func _ready() -> void:
	_refresh_gate = RefreshGate.new(self, _refresh_requests)
	_board_gate = RefreshGate.new(self, on_enter)
	repeat_button.pressed.connect(_repeat_last_order)
	_mount_back_button.call_deferred()
	# Keep hand-in/delegation actions available while the notice body scrolls.
	request_details.status.reparent(request_footer)
	request_details.status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	request_details.actions.reparent(request_footer)
	request_details.actions.alignment = FlowContainer.ALIGNMENT_CENTER
	active_tab = "village"
	scroll.resized.connect(_layout_empty_state)
	$Layout/Tabs/Village.pressed.connect(show_tab.bind("village"))
	$Layout/Tabs/Guild.pressed.connect(show_tab.bind("guild"))
	back_button.pressed.connect(show_board)
	completed_button.toggled.connect(func(value: bool) -> void:
		_show_completed = value
		_refresh_requests()
	)
	Manager.instance.regional.changed.connect(_queue_request_refresh)
	Manager.instance.hub.changed.connect(_queue_request_refresh)
	create_quest_button.pressed.connect(_open_create_quest_menu)
	scout_quest_button.pressed.connect(_open_scout_quest_menu)
	auto_resolve_button.toggled.connect(_on_auto_resolve_toggled)
	Manager.instance.quests.quest_list_changed.connect(_queue_board_refresh)
	board_surface.resized.connect(_layout_board)
	on_enter()
	_layout_empty_state.call_deferred()

func _layout_empty_state() -> void:
	# Center a readable paragraph, rather than the label's narrow minimum width.
	empty_label.get_node("Content").custom_minimum_size.x = minf(440.0, maxf(1.0, scroll.size.x - 32.0))

func _mount_back_button() -> void:
	var parent_window: Node = get_parent()
	while parent_window != null and not parent_window is DraggableControl: parent_window = parent_window.get_parent()
	if parent_window is DraggableControl:
		back_button.reparent(parent_window.header_actions)
		parent_window.header_actions.move_child(back_button, 0)

func show_tab(id: String) -> void:
	active_tab = id
	selected_request = ""
	$Layout/Scroll.scroll_vertical = 0
	_refresh_requests()

func show_board() -> void:
	selected_request = ""
	$Layout/Scroll.scroll_vertical = 0
	_refresh_requests()

func show_request(id: String) -> void:
	var regional := Manager.instance.regional
	if id == CommunityProjectsUI.INCIDENT_REQUEST:
		if regional.active_incident == null: return
	elif regional.get_definition(id) == null: return
	active_tab = "village"
	selected_request = id
	request_details.select_request(id)
	$Layout/Scroll.scroll_vertical = 0
	_refresh_requests()

func _queue_request_refresh() -> void:
	_refresh_gate.request()

func _refresh_requests() -> void:
	if not is_node_ready() or SaveGames.is_loading: return
	var regional := Manager.instance.regional
	if selected_request == CommunityProjectsUI.INCIDENT_REQUEST and regional.active_incident == null:
		selected_request = ""
	for child: Node in request_list.get_children():
		request_list.remove_child(child)
		child.queue_free()
	var completed_count := 0
	var available_count := 0
	if regional.active_incident != null:
		available_count += 1
		var incident := regional.active_incident.definition
		var author := regional.get_incident_requester()
		_add_notice(CommunityProjectsUI.INCIDENT_REQUEST, incident.get_title(), author.resident_name, tr("QUEST_REQUEST_AVAILABLE"))
	for definition: CommunityProjectDefinition in regional.catalog.projects:
		var state := regional.projects[definition.id]
		if state.completed:
			completed_count += 1
			if not _show_completed: continue
		else: available_count += 1
		var state_text := tr("QUEST_REQUEST_COMPLETED") if state.completed else tr("QUEST_REQUEST_AVAILABLE")
		if not state.completed:
			if not regional.is_unlocked(): state_text = tr("QUEST_REQUEST_FORGE_REQUIRED")
			elif state.blueprint_issued: state_text = tr("COMMUNITY_PLACE_BLUEPRINT" if regional.get_project_buildable(definition.id) == null else "COMMUNITY_FIND_FOUNDATION")
			elif regional.completion_block_reason(definition.id).is_empty(): state_text = tr("QUEST_REQUEST_READY")
			elif state.fieldwork_done: state_text = tr("QUEST_REQUEST_DELIVER_MATERIALS")
		_add_notice(definition.id, definition.get_title(), definition.resident_name, state_text)
	var village := active_tab == "village"
	repeat_button.disabled = _last_order() == null
	var detail := village and not selected_request.is_empty()
	$Layout/Tabs/Village.text = tr("QUEST_BOARD_VILLAGE_COUNT") % available_count
	$Layout/Tabs/Guild.text = tr("QUEST_BOARD_GUILD_COUNT") % Manager.instance.quests.get_commissions().size()
	$Layout/Tabs/Village.set_pressed_no_signal(village)
	$Layout/Tabs/Guild.set_pressed_no_signal(not village)
	back_button.visible = detail
	$Layout/Tabs.visible = not detail
	$Layout/RuleTop.visible = not detail
	request_table.visible = village and not detail and request_list.get_child_count() > 0
	request_details.visible = detail
	request_footer.visible = detail
	completed_button.visible = village and not detail and completed_count > 0
	completed_button.text = tr("QUEST_REQUEST_COMPLETED_COUNT") % completed_count
	var guild_empty := Manager.instance.quests.get_commissions().is_empty()
	board_surface.visible = not village and not guild_empty
	empty_label.visible = not detail and (request_list.get_child_count() == 0 if village else guild_empty)
	empty_label.get_node("Content/Title").text = tr("QUEST_REQUEST_EMPTY" if village else "QUEST_LIST_EMPTY")
	empty_label.get_node("Content/Hint").text = tr("QUEST_REQUEST_EMPTY_HINT" if village else "QUEST_BOARD_EMPTY_HINT")
	$Layout/Actions.visible = not village
	$Layout/Rule.visible = not village
	if detail: request_details.refresh()

func _add_notice(id: String, title: String, author: String, state: String) -> void:
	var notice := preload("res://scenes/ui/components/village_request_notice.tscn").instantiate() as VillageRequestNotice
	request_list.add_child(notice)
	notice.setup(id, title, author, state, show_request)

func _on_auto_resolve_toggled(enabled: bool) -> void:
	auto_resolve_enabled = enabled
	for note in _get_quest_notes():
		note.set_auto_resolve_enabled(auto_resolve_enabled)

func _sync_auto_resolve_button() -> void:
	if auto_resolve_button == null:
		return
	auto_resolve_button.set_pressed_no_signal(auto_resolve_enabled)
	
func _open_create_quest_menu() -> void:
	if can_open_creation_menu() and _has_available_quests_to_create():
		DataManager.instance.get_scene_by_name("quest_creation_ui").queue(_on_create_quest_window_loaded)

func _open_scout_quest_menu() -> void:
	if can_open_creation_menu() and _has_available_scouting_to_create():
		DataManager.instance.get_scene_by_name("quest_creation_ui").queue(_on_scout_quest_window_loaded)
	
func can_open_creation_menu() -> bool:
	return not window_instance || not SceneManager.is_visible(window_instance)
	
func _on_create_quest_window_loaded(window_info: SceneInfo) -> void:
	window_instance = SceneManager.add(window_info, false);
	var quest_creation: QuestCreationUI = (window_instance.node as DraggableControl).content as QuestCreationUI;
	quest_creation.clear_forced_data()
	window_instance.on_enter.emit();

func _on_scout_quest_window_loaded(window_info: SceneInfo) -> void:
	window_instance = SceneManager.add(window_info, false);
	var quest_creation: QuestCreationUI = (window_instance.node as DraggableControl).content as QuestCreationUI;
	quest_creation.setup_scouting_request()
	window_instance.on_enter.emit();

func _get_quest_notes() -> Array[QuestListItemUI]:
	var notes: Array[QuestListItemUI]
	for child: Node in board_surface.get_children():
		if child is QuestListItemUI:
			notes.append(child)
	return notes

func _find_note_for_quest(quest: Quest) -> QuestListItemUI:
	for note: QuestListItemUI in _get_quest_notes():
		if note.questData == quest:
			return note
	return null

func _layout_board() -> void:
	if not is_node_ready() or board_surface.size.x <= 0.0:
		return

	var notes := _get_ordered_notes()
	if notes.is_empty():
		board_surface.custom_minimum_size.y = 0.0
		return
	var width := board_surface.size.x
	var note_size := notes[0].get_combined_minimum_size()
	var stride := note_size + note_spacing
	var columns := maxi(1, floori((width - board_margin * 2.0 + note_spacing.x) / stride.x))
	var rows := ceili(float(notes.size()) / columns)
	for row in rows:
		var first := row * columns
		var count := mini(columns, notes.size() - first)
		var row_width := count * stride.x - note_spacing.x
		var left := maxf(0.0, (width - row_width) * 0.5)
		for column in count:
			var note := notes[first + column]
			note.position = Vector2(left + column * stride.x, board_margin + row * stride.y).round()
	board_surface.custom_minimum_size.y = board_margin * 2.0 + rows * stride.y - note_spacing.y

func _get_ordered_notes() -> Array[QuestListItemUI]:
	var ordered_notes: Array[QuestListItemUI] = []
	for quest: Quest in Manager.instance.quests.get_commissions():
		var note := _find_note_for_quest(quest)
		if note != null:
			ordered_notes.append(note)
	return ordered_notes

func _has_available_quests_to_create() -> bool:
	var active_scene := SceneManager.get_active_scene()
	if active_scene == null:
		return false

	var grid := active_scene.node as HexGrid
	if grid == null:
		return false

	var player_hex := Manager.instance.player_instance.get_hex()
	if player_hex == null:
		return false

	for hex: HexBase in grid.get_structured_hexes():
		if hex == null or hex.structure == null:
			continue
		if not hex.is_explored or not hex.is_visible_in_tree():
			continue
		if not hex.structure.structure_info.is_quest_target:
			continue

		var objective := hex.structure.instance as QuestObjective
		if objective == null or not objective.is_visible_in_tree() or not objective.can_interact():
			continue

		var distance := GridUtils.cube_distance(hex.cube_id, player_hex.cube_id)
		if distance > Manager.instance.quests.max_quest_distance:
			continue
		if not Manager.instance.quests.is_quest_location_reachable(hex, grid):
			continue

		var postable_types := Manager.instance.quests.get_postable_quest_types(
			hex,
			objective.get_filtered_quest_types(objective.state_machine.get_current_state_index())
		)
		if not postable_types.is_empty():
			return true

	return false

func _has_available_scouting_to_create() -> bool:
	var active_scene := SceneManager.get_active_scene()
	if active_scene == null:
		return false

	var grid := active_scene.node as HexGrid
	if grid == null:
		return false

	return not Manager.instance.quests.get_available_scout_locations(grid).is_empty()

func _queue_board_refresh() -> void:
	_board_gate.request()

func _last_order() -> Quest:
	var operations := Manager.instance.operations.operations
	for index in range(operations.size() - 1, -1, -1):
		var operation := operations[index]
		var quest := operation.quest
		if quest != null and quest.uses_guild_roster() and quest.quest_key != "scout" and operation.reward_resolved:
			return quest
	return null

func _repeat_last_order() -> void:
	var quest := _last_order()
	if quest == null: return
	var result := Manager.instance.quests.repeat_order(quest)
	if not result.success: Manager.instance.toast.notify(tr(result.message_key), GameUI.WARNING)
