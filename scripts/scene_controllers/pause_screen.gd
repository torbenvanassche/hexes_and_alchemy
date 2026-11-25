class_name PauseMenu extends Panel

@export var resume_button: Button;
@export var settings_button: Button;
@export var quit_button: Button;

@onready var checkpoint_name: LineEdit = %CheckpointName
@onready var checkpoints: OptionButton = %Checkpoints
@onready var save_button: Button = %SaveCheckpoint
@onready var load_button: Button = %LoadCheckpoint
@onready var feedback: Label = %SaveFeedback
var _history: SaveHistoryControls
var _checkpoint_scroll: ScrollContainer
var _slots: Array[Dictionary] = []
var _development_slots: Array[Dictionary] = []

func _ready() -> void:
	_build_save_controls()
	resume_button.pressed.connect(Manager.instance.pause_game.bind(false))
	
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)
	save_button.pressed.connect(_save_checkpoint)
	load_button.pressed.connect(_load_checkpoint)
	checkpoints.item_selected.connect(_select_checkpoint)
	%OpenCheckpoints.pressed.connect(show_checkpoints)
	%BackFromCheckpoints.pressed.connect(_show_main_page)
	%DevelopmentCheckpoints.item_selected.connect(_select_development_checkpoint)
	%LoadDevelopment.pressed.connect(_load_development_checkpoint)
	visibility_changed.connect(_on_visibility_changed)
	_show_main_page()
	_refresh_checkpoints()

func _on_visibility_changed() -> void:
	if visible: _show_main_page()

func _show_main_page() -> void:
	%Actions.show()
	_checkpoint_scroll.hide()
	%BackFromCheckpoints.hide()
	%Title.text = "SCENE_PAUSE_MENU_NAME"

func show_checkpoints() -> void:
	_refresh_checkpoints()
	%Actions.hide()
	_checkpoint_scroll.show()
	%BackFromCheckpoints.show()
	%Title.text = "PAUSE_CHECKPOINTS"
	%BackFromCheckpoints.grab_focus()

func _refresh_checkpoints() -> void:
	_slots = SaveGames.list_slots()
	checkpoints.clear()
	for slot in _slots:
		checkpoints.add_item("%s · %s · Day %d · %s" % [str(slot.kind).capitalize(), slot.label, int(slot.day), str(slot.saved_at).replace("T", " ")])
	load_button.disabled = _slots.is_empty()
	if _slots.is_empty(): checkpoints.add_item("No checkpoints yet")
	feedback.text = SaveGames.save_block_reason()
	save_button.disabled = not feedback.text.is_empty()
	_development_slots = SaveGames.list_development_checkpoints()
	%DevelopmentSection.visible = not _development_slots.is_empty()
	%DevelopmentCheckpoints.clear()
	for slot in _development_slots: %DevelopmentCheckpoints.add_item(slot.label)
	_select_development_checkpoint(0)
	_select_checkpoint(0)

func _select_development_checkpoint(index: int) -> void:
	if index >= 0 and index < _development_slots.size():
		%DevelopmentDescription.text = _development_slots[index].description

func _load_development_checkpoint() -> void:
	var index: int = %DevelopmentCheckpoints.selected
	if index < 0 or index >= _development_slots.size(): return
	if not SaveGames.load_development_checkpoint(_development_slots[index].id): feedback.text = SaveGames.last_error

func _select_checkpoint(index: int) -> void:
	if index >= 0 and index < _slots.size():
		checkpoint_name.text = _slots[index].label if _slots[index].kind == "manual" else ""
		_history.select_slot(_slots[index].slot, bool(_slots[index].backup))
	else:
		_history.select_slot("", false)

func _save_checkpoint() -> void:
	if SaveGames.save_slot(checkpoint_name.text):
		_refresh_checkpoints()
		feedback.text = "Checkpoint saved. Previous versions remain available in history."
	else:
		feedback.text = SaveGames.last_error

func _load_checkpoint() -> void:
	var index := checkpoints.selected
	if index < 0 or index >= _slots.size(): return
	if not SaveGames.load_slot(_slots[index].slot): feedback.text = SaveGames.last_error
	
func _on_settings() -> void:
	SceneManager.set_visible_by_name("pause_menu", false);
	SceneManager.add(DataManager.instance.get_scene_by_name("settings_menu"))
	
func _on_quit() -> void:
	get_tree().quit()

func _build_save_controls() -> void:
	_history = SaveHistoryControls.new()
	%CheckpointsPage.add_child(_history)
	%CheckpointsPage.move_child(_history, %LoadCheckpoint.get_index() + 1)
	_history.feedback.connect(func(message: String) -> void: feedback.text = message)
	# Keep all save controls reachable on smaller windows.
	var page: Control = %CheckpointsPage
	var layout := page.get_parent()
	_checkpoint_scroll = ScrollContainer.new()
	_checkpoint_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_checkpoint_scroll.custom_minimum_size.y = minf(450.0, get_viewport_rect().size.y - 180.0)
	layout.add_child(_checkpoint_scroll)
	page.reparent(_checkpoint_scroll)
	page.show()
	%BackFromCheckpoints.reparent(layout)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$CenterContainer/MenuPanel.custom_minimum_size.x = minf(620.0, get_viewport_rect().size.x - 40.0)
