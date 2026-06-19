class_name QuestListUI extends Control

@onready var create_quest_button: Button = $CreateQuestButton
@onready var board_surface: Control = $BoardSurface
@onready var empty_label: Label = $EmptyLabel

@export var quest_item_ui: PackedScene
var window_instance: SceneInstance;

func on_enter() -> void:
	for c: QuestListItemUI in _get_quest_notes():
		if not Config.gamestate.active_quests.has(c.questData):
			c.queue_free()

	var quest_index := 0
	for q: Quest in Config.gamestate.active_quests:
		if _get_quest_notes().all(func(child: QuestListItemUI) -> bool: return child.questData != q):
			var instance: QuestListItemUI = quest_item_ui.instantiate();
			board_surface.add_child(instance);
			instance.set_data(q);
			_post_note(instance, quest_index)
		quest_index += 1

	empty_label.visible = Config.gamestate.active_quests.is_empty()
	_allow_quest_creation_allowed()
	
	if not Config.gamestate.quest_availability_changed.is_connected(_allow_quest_creation_allowed):
		Config.gamestate.quest_availability_changed.connect(_allow_quest_creation_allowed)
	
func _allow_quest_creation_allowed() -> void:
	create_quest_button.disabled = not _has_available_quests_to_create()
	
func _ready() -> void:
	create_quest_button.pressed.connect(_open_create_quest_menu)
	Config.gamestate.quest_list_changed.connect(on_enter)
	on_enter()
	
func _open_create_quest_menu() -> void:
	if can_open_creation_menu():
		DataManager.instance.get_scene_by_name("quest_creation_ui").queue(_on_create_quest_window_loaded)
	
func can_open_creation_menu() -> bool:
	return not window_instance || not SceneManager.is_visible(window_instance)
	
func _on_create_quest_window_loaded(window_info: SceneInfo) -> void:
	window_instance = SceneManager.add(window_info);
	var quest_creation: QuestCreationUI = (window_instance.node as DraggableControl).content as QuestCreationUI;
	quest_creation.clear_forced_data()
	if not quest_creation.quest_created.is_connected(Config.gamestate.add_quest):
		quest_creation.quest_created.connect(Config.gamestate.add_quest)
	window_instance.on_enter.emit();

func _get_quest_notes() -> Array[QuestListItemUI]:
	var notes: Array[QuestListItemUI]
	for child: Node in board_surface.get_children():
		if child is QuestListItemUI:
			notes.append(child)
	return notes

func _post_note(note: QuestListItemUI, quest_index: int) -> void:
	var board_size := board_surface.size
	if board_size == Vector2.ZERO:
		board_size = board_surface.custom_minimum_size
	var note_size := note.custom_minimum_size
	var column_count: int = max(1, int((board_size.x - 36.0) / max(1.0, note_size.x * 0.72)))
	var column := quest_index % column_count
	var row := int(quest_index / column_count)
	var overlap_step := Vector2(note_size.x * 0.62, note_size.y * 0.55)
	var offset := Vector2(18.0, 18.0) + Vector2(column, row) * overlap_step
	offset += Vector2(float((quest_index % 3) * 10), float((quest_index % 2) * 12))
	var max_position := (board_size - note_size).max(Vector2.ZERO)
	note.position = offset.clamp(Vector2.ZERO, max_position)
	note.z_index = quest_index

func _has_available_quests_to_create() -> bool:
	var grid := SceneManager.get_active_scene().node as HexGrid
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
		if distance > Config.gamestate.max_quest_distance:
			continue

		var available_types := Config.gamestate.get_available_quest_types(
			hex,
			objective.get_filtered_quest_types(objective.state_machine.get_current_state_index())
		)
		if not available_types.is_empty():
			return true

	return false
