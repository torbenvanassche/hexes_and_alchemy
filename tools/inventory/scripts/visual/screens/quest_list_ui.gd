class_name QuestListUI extends Control

const REQUEST_ROW := preload("res://scenes/ui/components/village_request_notice.tscn")

@export var quest_item_ui: PackedScene

@onready var create_quest_button: Button = $Layout/Actions/CreateQuestButton
@onready var scout_quest_button: Button = $Layout/Actions/ScoutQuestButton
@onready var auto_resolve_button: CheckBox = $Layout/Actions/AutoResolveButton
@onready var repeat_button: Button = $Layout/Actions/RepeatLast
@onready var scroll: ScrollContainer = $Layout/Scroll
@onready var request_table: VBoxContainer = $Layout/Scroll/Content/RequestTable
@onready var request_list: VBoxContainer = request_table.get_node("Requests")
@onready var request_details: CommunityProjectsUI = $Layout/Scroll/Content/RequestDetails
@onready var commission_table: VBoxContainer = $Layout/Scroll/Content/CommissionTable
@onready var commission_list: VBoxContainer = commission_table.get_node("Rows")
@onready var empty_label: Control = $Layout/Scroll/Content/EmptyState
@onready var completed_button: Button = $Layout/Scroll/Content/Completed
@onready var back_button: Button = $Layout/Back
@onready var request_footer: VBoxContainer = $Layout/RequestFooter

var active_tab := "village"
var selected_request := ""
var window_instance: SceneInstance
var _expanded_commission: Quest
var _commission_rows: Dictionary[Quest, QuestListItemUI] = {}
var _show_completed := false
var _completed_request_count := 0
var _request_gate: RefreshGate
var _commission_gate: RefreshGate
var _availability_gate: RefreshGate

func _ready() -> void:
	_request_gate = RefreshGate.new(self, _refresh_requests)
	_commission_gate = RefreshGate.new(self, _refresh_commissions)
	_availability_gate = RefreshGate.new(self, _allow_quest_creation_allowed)
	_mount_back_button.call_deferred()
	request_details.status.reparent(request_footer)
	request_details.status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	request_details.actions.reparent(request_footer)
	request_details.actions.alignment = FlowContainer.ALIGNMENT_CENTER

	scroll.resized.connect(_layout_empty_state)
	$Layout/Tabs/Village.pressed.connect(show_tab.bind("village"))
	$Layout/Tabs/Guild.pressed.connect(show_tab.bind("guild"))
	back_button.pressed.connect(show_board)
	completed_button.toggled.connect(func(value: bool) -> void:
		_show_completed = value
		_refresh_requests()
	)
	repeat_button.pressed.connect(_repeat_last_order)
	create_quest_button.pressed.connect(_open_create_quest_menu)
	scout_quest_button.pressed.connect(_open_scout_quest_menu)
	auto_resolve_button.toggled.connect(Manager.instance.operations.set_auto_collect_commissions)

	Manager.instance.regional.changed.connect(_request_gate.request)
	Manager.instance.hub.changed.connect(_request_gate.request)
	Manager.instance.quests.quest_list_changed.connect(_commission_gate.request)
	Manager.instance.quests.quest_availability_changed.connect(_availability_gate.request)
	on_enter()
	_layout_empty_state.call_deferred()

func on_enter() -> void:
	auto_resolve_button.set_pressed_no_signal(Manager.instance.operations.auto_resolve_completed_quests)
	_refresh_commissions()
	_refresh_requests()
	_availability_gate.request()

func _allow_quest_creation_allowed() -> void:
	if active_tab != "guild" or SaveGames.is_loading:
		return
	create_quest_button.disabled = not _has_available_quests_to_create()
	create_quest_button.tooltip_text = tr("QUEST_BOARD_FIND_TARGET") if create_quest_button.disabled else ""
	scout_quest_button.disabled = not _has_available_scouting_to_create()
	scout_quest_button.theme_type_variation = &"PrimaryButton" if create_quest_button.disabled else &"Button"

func _layout_empty_state() -> void:
	empty_label.get_node("Content").custom_minimum_size.x = minf(440.0, maxf(1.0, scroll.size.x - 32.0))

func _mount_back_button() -> void:
	var parent_window: Node = get_parent()
	while parent_window != null and not parent_window is DraggableControl:
		parent_window = parent_window.get_parent()
	if parent_window is DraggableControl:
		back_button.reparent(parent_window.header_actions)
		parent_window.header_actions.move_child(back_button, 0)

func show_tab(id: String) -> void:
	active_tab = id
	selected_request = ""
	scroll.scroll_vertical = 0
	if active_tab == "village":
		_refresh_requests()
	else:
		_refresh_commissions()
		_availability_gate.request()

func show_board() -> void:
	show_tab(active_tab)

func show_request(id: String) -> void:
	var regional := Manager.instance.regional
	if id == CommunityProjectsUI.INCIDENT_REQUEST:
		if regional.active_incident == null: return
	elif regional.get_definition(id) == null: return
	active_tab = "village"
	selected_request = id
	request_details.select_request(id)
	scroll.scroll_vertical = 0
	_refresh_requests()

func _refresh_requests() -> void:
	if not is_node_ready() or SaveGames.is_loading: return
	var regional := Manager.instance.regional
	if selected_request == CommunityProjectsUI.INCIDENT_REQUEST and regional.active_incident == null:
		selected_request = ""
	var show_requests := active_tab == "village" and selected_request.is_empty()
	if show_requests:
		for child: Node in request_list.get_children():
			request_list.remove_child(child)
			child.queue_free()
	var available_count := 0
	_completed_request_count = 0
	if regional.active_incident != null:
		available_count += 1
		if show_requests:
			var incident := regional.active_incident.definition
			var author := regional.get_incident_requester()
			_add_notice(CommunityProjectsUI.INCIDENT_REQUEST, incident.get_title(), author.resident_name, tr("QUEST_REQUEST_AVAILABLE"))
	for definition: CommunityProjectDefinition in regional.catalog.projects:
		var state := regional.projects[definition.id]
		if state.completed: _completed_request_count += 1
		else: available_count += 1
		if not show_requests or (state.completed and not _show_completed): continue
		var state_text := tr("QUEST_REQUEST_COMPLETED") if state.completed else tr("QUEST_REQUEST_AVAILABLE")
		if not state.completed:
			if not regional.is_unlocked(): state_text = tr("QUEST_REQUEST_FORGE_REQUIRED")
			elif state.blueprint_issued: state_text = tr("COMMUNITY_PLACE_BLUEPRINT" if regional.get_project_buildable(definition.id) == null else "COMMUNITY_FIND_FOUNDATION")
			elif regional.completion_block_reason(definition.id).is_empty(): state_text = tr("QUEST_REQUEST_READY")
			elif state.fieldwork_done: state_text = tr("QUEST_REQUEST_DELIVER_MATERIALS")
		_add_notice(definition.id, definition.get_title(), definition.resident_name, state_text)
	$Layout/Tabs/Village.text = tr("QUEST_BOARD_VILLAGE_COUNT") % available_count
	completed_button.text = tr("QUEST_REQUEST_COMPLETED_COUNT") % _completed_request_count
	_update_page()
	if request_details.visible:
		request_details.refresh()

func _add_notice(id: String, title: String, author: String, state: String) -> void:
	var notice := REQUEST_ROW.instantiate() as VillageRequestNotice
	request_list.add_child(notice)
	notice.setup(id, title, author, state, show_request)

func _refresh_commissions() -> void:
	if not is_node_ready() or SaveGames.is_loading: return
	var commissions := Manager.instance.quests.get_commissions()
	for quest: Quest in _commission_rows.keys():
		if commissions.has(quest): continue
		var obsolete := _commission_rows[quest]
		_commission_rows.erase(quest)
		commission_list.remove_child(obsolete)
		obsolete.queue_free()
	for quest: Quest in commissions:
		var row: QuestListItemUI = _commission_rows.get(quest)
		if row == null:
			row = quest_item_ui.instantiate() as QuestListItemUI
			_commission_rows[quest] = row
			commission_list.add_child(row)
			row.details_requested.connect(_show_commission_details)
			row.setup(quest)
		else:
			row.refresh()
	$Layout/Tabs/Guild.text = tr("QUEST_BOARD_GUILD_COUNT") % commissions.size()
	repeat_button.disabled = _last_order() == null
	if _expanded_commission != null and not _commission_rows.has(_expanded_commission):
		_expanded_commission = null
	_update_page()

func _show_commission_details(quest: Quest, expanded: bool) -> void:
	if not _commission_rows.has(quest):
		return
	if _expanded_commission != null:
		_commission_rows[_expanded_commission].set_expanded(false)
	_expanded_commission = quest if expanded else null
	if not expanded:
		return
	var row := _commission_rows[quest]
	row.set_expanded(true)
	await get_tree().process_frame
	if _expanded_commission == quest and is_instance_valid(row) and row.is_visible_in_tree():
		scroll.ensure_control_visible(row)

func _update_page() -> void:
	var village := active_tab == "village"
	var detail := village and not selected_request.is_empty()
	$Layout/Tabs/Village.set_pressed_no_signal(village)
	$Layout/Tabs/Guild.set_pressed_no_signal(not village)
	$Layout/Tabs.visible = not detail
	$Layout/RuleTop.visible = not detail
	back_button.visible = detail
	request_table.visible = village and not detail and request_list.get_child_count() > 0
	request_details.visible = detail
	request_footer.visible = detail
	completed_button.visible = village and not detail and _completed_request_count > 0
	commission_table.visible = not village and not _commission_rows.is_empty()
	empty_label.visible = not detail and (request_list.get_child_count() == 0 if village else _commission_rows.is_empty())
	empty_label.get_node("Content/Title").text = tr("QUEST_REQUEST_EMPTY" if village else "QUEST_LIST_EMPTY")
	empty_label.get_node("Content/Hint").text = tr("QUEST_REQUEST_EMPTY_HINT" if village else "QUEST_BOARD_EMPTY_HINT")
	$Layout/Actions.visible = not village
	$Layout/Rule.visible = not village

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

func _has_available_quests_to_create() -> bool:
	var active_scene := SceneManager.get_active_scene()
	if active_scene == null:
		return false

	var grid := active_scene.node as HexGrid
	if grid == null:
		return false

	var player := Manager.instance.player_instance
	if player == null:
		return false
	var player_hex := player.get_hex()
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
