class_name JournalEntryUI extends VBoxContainer

@onready var body: RichTextLabel = $Body
@onready var tasks: VBoxContainer = $Tasks

@export var task_scene: PackedScene

func set_entry(entry: JournalEntry) -> void:
	if entry == null:
		return
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
	if task_scene == null:
		return
	var task_ui := task_scene.instantiate() as JournalTaskUI
	if task_ui == null:
		return
	tasks.add_child(task_ui)
	task_ui.set_task(task)
