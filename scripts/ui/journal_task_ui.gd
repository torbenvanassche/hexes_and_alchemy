class_name JournalTaskUI extends HBoxContainer

@onready var completed: CheckBox = $Completed
@onready var text_label: Label = $Text

var _task: JournalTask

func _ready() -> void:
	_refresh()

func set_task(task: JournalTask) -> void:
	_task = task
	_refresh()

func _refresh() -> void:
	if not is_node_ready() or _task == null:
		return
	completed.button_pressed = _task.completed
	text_label.text = tr(_task.text_key)
