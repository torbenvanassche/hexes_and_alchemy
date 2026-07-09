class_name QuestOutcome extends Resource

@export var weight: float = 1.0
@export var loot_table: LootTable
@export var next_state: String = ""
@export var message_key: String = ""
@export var completes_journal_task: JournalTask

func roll_loot() -> Dictionary[ItemInfo, int]:
	if loot_table == null:
		return {}
	return loot_table.roll()

func get_preview_ranges() -> Dictionary[ItemInfo, Vector2i]:
	if loot_table == null:
		return {}
	return loot_table.get_preview_ranges()

func has_next_state() -> bool:
	return next_state != ""

func complete_journal_task() -> void:
	if completes_journal_task == null:
		return
	if Manager.instance != null and Manager.instance.journal != null:
		Manager.instance.journal.complete_task(completes_journal_task.id)
