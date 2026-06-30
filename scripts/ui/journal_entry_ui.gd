class_name JournalEntryUI extends VBoxContainer

@onready var title: Label = $Title
@onready var body: RichTextLabel = $Body
@onready var tasks: VBoxContainer = $Tasks

func set_entry(entry: JournalEntry) -> void:
	if entry == null:
		return
	title.text = tr(entry.title_key)
	body.text = tr(entry.body_key)
	body.visible = not entry.body_key.is_empty()
	_clear_tasks()
	for task in entry.get_tasks():
		_add_task(task)

func _clear_tasks() -> void:
	for child: Node in tasks.get_children():
		tasks.remove_child(child)
		child.queue_free()

func _add_task(task: JournalTask) -> void:
	var task_row := HBoxContainer.new()
	task_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var task_check := CheckBox.new()
	task_check.button_pressed = task.completed
	task_check.disabled = true
	task_check.focus_mode = Control.FOCUS_NONE
	task_row.add_child(task_check)

	var task_label := RichTextLabel.new()
	task_label.bbcode_enabled = true
	task_label.fit_content = true
	task_label.scroll_active = false
	task_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if task.completed:
		task_label.text = "[s][color=#8aa07e]%s[/color][/s]" % [tr(task.text_key)]
	else:
		task_label.text = tr(task.text_key)
	task_row.add_child(task_label)

	tasks.add_child(task_row)
