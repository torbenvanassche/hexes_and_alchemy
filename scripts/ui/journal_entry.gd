class_name JournalEntry extends Resource

@export var id: String = ""
@export var title_key: String = ""
@export_multiline var body_key: String = ""
@export var unlocked: bool = true
@export var tasks: Array[Resource] = []

func get_tasks() -> Array[JournalTask]:
	var journal_tasks: Array[JournalTask] = []
	for resource: Resource in tasks:
		var task := resource as JournalTask
		if task != null:
			journal_tasks.append(task)
	return journal_tasks
