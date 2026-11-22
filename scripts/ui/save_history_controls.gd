class_name SaveHistoryControls
extends VBoxContainer

signal feedback(message: String)
var slot := ""
var versions: OptionButton
var restore: Button
var backup: Button
var autosave: CheckBox
var minutes: SpinBox
var _entries: Array[Dictionary] = []

func _ready() -> void:
	var row := HBoxContainer.new()
	versions = OptionButton.new()
	versions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	versions.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(versions)
	restore = Button.new()
	restore.text = tr("SAVE_RESTORE_VERSION")
	restore.pressed.connect(_restore_version)
	row.add_child(restore)
	add_child(row)
	backup = Button.new()
	backup.text = tr("SAVE_RECOVER_BACKUP")
	backup.pressed.connect(func() -> void:
		if not SaveGames.load_backup(slot): feedback.emit(SaveGames.last_error))
	add_child(backup)
	row = HBoxContainer.new()
	autosave = CheckBox.new()
	autosave.text = tr("SAVE_AUTOSAVE")
	autosave.button_pressed = SaveGames.autosave_enabled
	row.add_child(autosave)
	minutes = SpinBox.new()
	minutes.min_value = 1
	minutes.max_value = 30
	minutes.value = SaveGames.autosave_minutes
	minutes.suffix = tr("SAVE_MINUTES")
	row.add_child(minutes)
	autosave.toggled.connect(func(_enabled: bool) -> void: _preferences())
	minutes.value_changed.connect(func(_value: float) -> void: _preferences())
	add_child(row)
	var hint := Label.new()
	hint.text = tr("SAVE_HISTORY_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.theme_type_variation = &"MutedLabel"
	add_child(hint)

func select_slot(value: String, has_backup: bool) -> void:
	slot = value
	_entries = SaveGames.list_versions(slot)
	versions.clear()
	for entry: Dictionary in _entries:
		versions.add_item("%s · Day %d" % [str(entry.saved_at).replace("T", " "), int(entry.day)])
	if _entries.is_empty(): versions.add_item(tr("SAVE_NO_HISTORY"))
	restore.disabled = _entries.is_empty()
	backup.disabled = not has_backup

func _restore_version() -> void:
	var index := versions.selected
	if index >= 0 and index < _entries.size():
		if not SaveGames.load_version(_entries[index].id): feedback.emit(SaveGames.last_error)

func _preferences() -> void:
	SaveGames.set_autosave(autosave.button_pressed, int(minutes.value))
