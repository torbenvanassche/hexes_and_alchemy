class_name JournalTaskUI extends HBoxContainer

@onready var completed: Panel = $Completed
@onready var status: Label = $Completed/Mark
@onready var text_label: Label = $Content/Text
@onready var description: Label = $Content/Description

var _task: JournalTask

func _ready() -> void:
	_refresh()

func set_task(task: JournalTask) -> void:
	_task = task
	_refresh()

func _refresh() -> void:
	if not is_node_ready() or _task == null:
		return
	status.text = "✓" if _task.completed else ""
	status.theme_type_variation = &"StatusSuccessLabel"
	text_label.theme_type_variation = &"StatusSuccessLabel" if _task.completed else &"Label"
	text_label.text = tr(_task.text_key)
	description.text = tr(_task.description_key) if not _task.description_key.is_empty() else ""
	description.visible = not _task.description_key.is_empty()
