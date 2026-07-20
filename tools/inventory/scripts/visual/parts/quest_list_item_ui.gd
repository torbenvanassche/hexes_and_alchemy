class_name QuestListItemUI extends Control

@onready var quest_type: Label = $Paper/MarginContainer/VBoxContainer/Header/QuestType
@onready var quest_number: Label = $Paper/MarginContainer/VBoxContainer/Header/QuestNumber
@onready var quest_location: Label = $Paper/MarginContainer/VBoxContainer/LocationRow/QuestLocation
@onready var party: Label = $Paper/MarginContainer/VBoxContainer/PartyRow/Party
@onready var progress_bar: ProgressBar = $Paper/MarginContainer/VBoxContainer/ProgressBar
@onready var label: Label = $Paper/MarginContainer/VBoxContainer/ProgressBar/Label
@onready var claim_reward_button: Button = $Paper/MarginContainer/VBoxContainer/ClaimRewardButton

@export var supply_slot: PackedScene;

var questData: Quest;
var auto_resolve_enabled := false
var _dragging := false
var _drag_offset := Vector2.ZERO
var _auto_claim_queued := false
static var _top_z_index := 10

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	claim_reward_button.pressed.connect(_claim_reward)

func set_data(quest: Quest) -> void:
	if questData:
		Debug.err("Quest already has data, create a new one instead!")
		return
	questData = quest;
	
	quest_number.text = "#%s" % [str(self.get_parent().get_child_count())];
	quest_type.text = _get_quest_type_name(quest.quest_key).to_upper();
	quest_location.text = _get_location_name();

	_update_progress(questData.state_machine.get_current_state())
	
	quest.state_machine.state_entered.connect(_update_progress)
	quest.completed.connect(_on_quest_complete)
	
func _on_quest_complete() -> void:
	questData = null;
	queue_free();
	
func _update_progress(state: String) -> void:
	label.text = _get_state_name(state);
	party.text = _get_party_text()
	progress_bar.value = _get_state_progress(state)
	var is_complete := questData != null and questData.is_state(Quest.QuestState.COMPLETE)
	progress_bar.visible = not is_complete
	claim_reward_button.visible = is_complete
	if is_complete and auto_resolve_enabled:
		_queue_auto_claim()

func _claim_reward() -> void:
	if questData == null:
		return
	questData.parse_reward()

func set_auto_resolve_enabled(enabled: bool) -> void:
	auto_resolve_enabled = enabled
	if enabled and questData != null and questData.is_state(Quest.QuestState.COMPLETE):
		_queue_auto_claim()

func _queue_auto_claim() -> void:
	if _auto_claim_queued:
		return
	_auto_claim_queued = true
	_claim_reward.call_deferred()

func _get_location_name() -> String:
	if questData == null or questData.location == null or questData.location.structure == null:
		return tr("UNKNOWN")
	return questData.location.structure.structure_info.get_display_name()

func _get_party_text() -> String:
	if questData == null or questData.party.is_empty():
		return tr("QUEST_PARTY_UNASSIGNED")
	if questData.party.size() == 1:
		return tr("QUEST_PARTY_ONE_ADVENTURER")
	return tr("QUEST_PARTY_ADVENTURERS") % [questData.party.size()]

func _get_quest_type_name(quest_type_key: String) -> String:
	var translation_key := "QUEST_TYPE_%s" % [quest_type_key.to_upper()]
	var translated := tr(translation_key)
	if translated == translation_key:
		return quest_type_key.capitalize()
	return translated

func _get_state_name(state: String) -> String:
	var translation_key := "QUEST_STATE_%s" % [state.to_upper()]
	var translated := tr(translation_key)
	if translated == translation_key:
		return state.capitalize()
	return translated

func _get_state_progress(state: String) -> float:
	var states := Quest.QuestState.keys()
	var state_index := states.find(state.to_upper())
	if state_index == -1:
		return 0.0
	return float(state_index) / float(max(1, states.size() - 1))

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_top_z_index += 1
			z_index = _top_z_index
			_drag_offset = get_global_mouse_position() - global_position
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		global_position = get_global_mouse_position() - _drag_offset
		_clamp_to_board()
		get_viewport().set_input_as_handled()

func _clamp_to_board() -> void:
	var board := get_parent() as Control
	if board == null:
		return
	var max_position := (board.size - size).max(Vector2.ZERO)
	position = position.clamp(Vector2.ZERO, max_position)
