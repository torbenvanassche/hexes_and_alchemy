class_name JournalManager extends Node

@export var entries: Array[Resource] = []

signal journal_changed()

func complete_task(task_id: String) -> bool:
	return set_task_completed(task_id, true)

func reopen_task(task_id: String) -> bool:
	return set_task_completed(task_id, false)

func set_task_completed(task_id: String, completed: bool = true) -> bool:
	var task := get_task(task_id)
	if task == null:
		return false
	if task.completed == completed:
		return true
	task.completed = completed
	journal_changed.emit()
	return true

func is_task_completed(task_id: String) -> bool:
	var task := get_task(task_id)
	return task != null and task.completed

func get_task(task_id: String) -> JournalTask:
	for entry in get_entries():
		for task in entry.get_tasks():
			if task.id == task_id:
				return task
	return null

func get_entries() -> Array[JournalEntry]:
	var journal_entries: Array[JournalEntry] = []
	for resource: Resource in entries:
		var entry := resource as JournalEntry
		if entry != null and entry.unlocked:
			journal_entries.append(entry)
	return journal_entries
