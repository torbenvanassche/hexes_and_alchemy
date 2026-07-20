class_name QuestListUI extends Control

@onready var create_quest_button: Button = $Actions/CreateQuestButton
@onready var scout_quest_button: Button = $Actions/ScoutQuestButton
@onready var auto_resolve_button: TextureButton = $"../../topbar/MarginContainer2/HBoxContainer/AutoResolveButton"
@onready var board_surface: Control = $BoardSurface
@onready var empty_label: Label = $EmptyLabel

@export var quest_item_ui: PackedScene
@export var board_margin: float = 20.0
@export var note_spacing: Vector2 = Vector2(16.0, 14.0)
var window_instance: SceneInstance;
var auto_resolve_enabled := false

func on_enter() -> void:
	_sync_auto_resolve_button()
	for c: QuestListItemUI in _get_quest_notes():
		if not Manager.instance.quests.active_quests.has(c.questData):
			c.queue_free()
		else:
			c.set_auto_resolve_enabled(auto_resolve_enabled)

	for q: Quest in Manager.instance.quests.active_quests:
		if _find_note_for_quest(q) == null:
			var instance: QuestListItemUI = quest_item_ui.instantiate();
			board_surface.add_child(instance);
			instance.set_auto_resolve_enabled(auto_resolve_enabled)
			instance.set_data(q);

	empty_label.visible = Manager.instance.quests.active_quests.is_empty()
	_allow_quest_creation_allowed()
	_layout_board()
	
	if not Manager.instance.quests.quest_availability_changed.is_connected(_allow_quest_creation_allowed):
		Manager.instance.quests.quest_availability_changed.connect(_allow_quest_creation_allowed)
	
func _allow_quest_creation_allowed() -> void:
	create_quest_button.disabled = not _has_available_quests_to_create()
	scout_quest_button.disabled = not _has_available_scouting_to_create()
	_layout_board()
	
func _ready() -> void:
	create_quest_button.pressed.connect(_open_create_quest_menu)
	scout_quest_button.pressed.connect(_open_scout_quest_menu)
	auto_resolve_button.toggled.connect(_on_auto_resolve_toggled)
	Manager.instance.quests.quest_list_changed.connect(on_enter)
	resized.connect(_layout_board)
	board_surface.resized.connect(_layout_board)
	on_enter()

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
	if not quest_creation.quest_created.is_connected(Manager.instance.quests.add_quest):
		quest_creation.quest_created.connect(Manager.instance.quests.add_quest)
	window_instance.on_enter.emit();

func _on_scout_quest_window_loaded(window_info: SceneInfo) -> void:
	window_instance = SceneManager.add(window_info, false);
	var quest_creation: QuestCreationUI = (window_instance.node as DraggableControl).content as QuestCreationUI;
	quest_creation.setup_scouting_request()
	if not quest_creation.quest_created.is_connected(Manager.instance.quests.add_quest):
		quest_creation.quest_created.connect(Manager.instance.quests.add_quest)
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
	if not is_node_ready():
		return

	_layout_notes(Rect2(Vector2.ZERO, _get_board_size()))

func _layout_notes(board_rect: Rect2) -> void:
	var occupied_rects: Array[Rect2] = []
	var notes := _get_ordered_notes()

	for quest_index in range(notes.size()):
		var note := notes[quest_index]
		var note_size := _get_control_size(note)
		var note_position := _find_free_rect_position(board_rect, note_size, occupied_rects)
		note.position = note_position
		note.z_index = quest_index
		occupied_rects.append(_with_spacing(Rect2(note_position, note_size), note_spacing))

func _get_ordered_notes() -> Array[QuestListItemUI]:
	var ordered_notes: Array[QuestListItemUI] = []
	for quest: Quest in Manager.instance.quests.active_quests:
		var note := _find_note_for_quest(quest)
		if note != null:
			ordered_notes.append(note)
	return ordered_notes

func _find_free_rect_position(
	board_rect: Rect2,
	control_size: Vector2,
	occupied_rects: Array[Rect2],
	candidate_positions: Array[Vector2] = []
) -> Vector2:
	var max_position := (board_rect.size - control_size).max(Vector2.ZERO)
	for candidate: Vector2 in candidate_positions:
		var clamped_candidate := candidate.clamp(Vector2.ZERO, max_position)
		if _rect_is_free(Rect2(clamped_candidate, control_size), occupied_rects):
			return clamped_candidate

	var step := Vector2(
		maxf(48.0, control_size.x * 0.35),
		maxf(40.0, control_size.y * 0.35)
	)
	var y := board_margin
	while y <= max_position.y:
		var x := board_margin
		while x <= max_position.x:
			var candidate := Vector2(x, y).clamp(Vector2.ZERO, max_position)
			if _rect_is_free(Rect2(candidate, control_size), occupied_rects):
				return candidate
			x += step.x
		y += step.y

	return Vector2(board_margin, board_margin).clamp(Vector2.ZERO, max_position)

func _rect_is_free(candidate: Rect2, occupied_rects: Array[Rect2]) -> bool:
	for occupied_rect: Rect2 in occupied_rects:
		if candidate.intersects(occupied_rect):
			return false
	return true

func _with_spacing(rect: Rect2, spacing: Vector2) -> Rect2:
	return Rect2(
		rect.position - spacing * 0.5,
		rect.size + spacing
	)

func _get_board_size() -> Vector2:
	var board_size := board_surface.size
	if board_size == Vector2.ZERO:
		board_size = board_surface.custom_minimum_size
	return board_size

func _get_control_size(control: Control) -> Vector2:
	var control_size := control.size
	if control_size == Vector2.ZERO:
		control_size = control.get_combined_minimum_size()
	if control_size == Vector2.ZERO:
		control_size = control.custom_minimum_size
	return control_size

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
