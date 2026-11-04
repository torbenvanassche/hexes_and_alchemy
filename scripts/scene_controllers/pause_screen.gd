class_name PauseMenu extends Panel

@export var resume_button: Button;
@export var settings_button: Button;
@export var quit_button: Button;

@onready var checkpoint_name: LineEdit = %CheckpointName
@onready var checkpoints: OptionButton = %Checkpoints
@onready var save_button: Button = %SaveCheckpoint
@onready var load_button: Button = %LoadCheckpoint
@onready var feedback: Label = %SaveFeedback
var _slots: Array[Dictionary] = []
var _development_slots: Array[Dictionary] = []

func _ready() -> void:
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
	%CheckpointsPage.hide()
	%Title.text = tr("SCENE_PAUSE_MENU_NAME")

func show_checkpoints() -> void:
	_refresh_checkpoints()
	%Actions.hide()
	%CheckpointsPage.show()
	%Title.text = "Checkpoints"
	%BackFromCheckpoints.grab_focus()

func _refresh_checkpoints() -> void:
	_slots = SaveGames.list_slots()
	checkpoints.clear()
	for slot in _slots:
		checkpoints.add_item("%s · Day %d · %s" % [slot.label, int(slot.day), str(slot.saved_at).replace("T", " ")])
	load_button.disabled = _slots.is_empty()
	if _slots.is_empty(): checkpoints.add_item("No checkpoints yet")
	feedback.text = SaveGames.save_block_reason()
	save_button.disabled = not feedback.text.is_empty()
	_development_slots = SaveGames.list_development_checkpoints()
	%DevelopmentSection.visible = not _development_slots.is_empty()
	%DevelopmentCheckpoints.clear()
	for slot in _development_slots: %DevelopmentCheckpoints.add_item(slot.label)
	_select_development_checkpoint(0)

func _select_development_checkpoint(index: int) -> void:
	if index >= 0 and index < _development_slots.size():
		%DevelopmentDescription.text = _development_slots[index].description

func _load_development_checkpoint() -> void:
	var index: int = %DevelopmentCheckpoints.selected
	if index < 0 or index >= _development_slots.size(): return
	if not SaveGames.load_development_checkpoint(_development_slots[index].id): feedback.text = SaveGames.last_error

func _select_checkpoint(index: int) -> void:
	if index >= 0 and index < _slots.size(): checkpoint_name.text = _slots[index].label

func _save_checkpoint() -> void:
	if SaveGames.save_slot(checkpoint_name.text):
		_refresh_checkpoints()
		feedback.text = "Checkpoint saved. Use the same name to replace it."
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
