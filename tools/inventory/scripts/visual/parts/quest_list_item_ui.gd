class_name QuestListItemUI extends Control

@onready var quest_type: Label = $Paper/MarginContainer/VBoxContainer/Header/QuestType
@onready var quest_number: Label = $Paper/MarginContainer/VBoxContainer/Header/QuestNumber
@onready var quest_location: Label = $Paper/MarginContainer/VBoxContainer/LocationRow/QuestLocation
@onready var party: Label = $Paper/MarginContainer/VBoxContainer/PartyRow/Party
@onready var progress_bar: ProgressBar = $Paper/MarginContainer/VBoxContainer/ProgressBar
@onready var label: Label = $Paper/MarginContainer/VBoxContainer/ProgressBar/Label
@onready var approve_quest: Button = $Paper/Actions/ApproveQuest
@onready var complete_quest: Button = $Paper/Actions/CompleteQuest

@export var supply_slot: PackedScene;

var questData: Quest;
var _dragging := false
var _drag_offset := Vector2.ZERO
static var _top_z_index := 10

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func set_data(quest: Quest) -> void:
	if questData:
		Debug.err("Quest already has data, create a new one instead!")
		return
	questData = quest;
	
	quest_number.text = "#%s" % [str(self.get_parent().get_child_count())];
	quest_type.text = _get_quest_type_name(quest.quest_key).to_upper();
	quest_location.text = _get_location_name();

	approve_quest.pressed.connect(_start_quest)
	complete_quest.pressed.connect(questData.parse_reward);
	_update_progress(questData.state_machine.get_current_state())
	
	quest.state_machine.state_entered.connect(_update_progress)
	quest.completed.connect(_on_quest_complete)
	
func _on_quest_complete() -> void:
	questData = null;
	queue_free();
	
func _start_quest() -> void:
	var taverns: Array[Tavern];
	taverns.assign(Manager.instance.active_settlement.interactions.filter(func(x: Interaction) -> bool: return x is Tavern));
	if taverns.size() != 0:
		var npcs: Array[SceneInstance] = taverns[0].get_available_npcs();
		if npcs.size() != 0:
			questData.add_to_party(npcs.pick_random().node)
			approve_quest.visible = false
			questData.start();
		else:
			Debug.err("No NPC available in tavern.")
	else:
		Debug.err("Cannot start quest, no tavern was found.")
	
func _update_progress(state: String) -> void:
	label.text = _get_state_name(state);
	party.text = _get_party_text()
	progress_bar.value = _get_state_progress(state)
	approve_quest.visible = questData.is_state(Quest.QuestState.WAITING);
	complete_quest.visible = questData.is_state(Quest.QuestState.COMPLETE);

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
