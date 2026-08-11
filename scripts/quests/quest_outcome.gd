class_name QuestOutcome extends Resource

signal applied(outcome: QuestOutcome)

@export var weight: float = 1.0
@export var is_dangerous := false
@export var loot_table: LootTable
@export var next_state: String = ""
@export var message_key: String = ""
@export var completes_journal_task: JournalTask

var _is_applied := false
var _runtime_summary_suffix := ""

func apply(_quest: Quest) -> void:
	if _is_applied:
		return
	_is_applied = true
	applied.emit(self)

func is_applied() -> bool:
	return _is_applied

func create_runtime_copy() -> QuestOutcome:
	var runtime_copy := duplicate(true) as QuestOutcome
	if runtime_copy != null:
		runtime_copy._is_applied = false
		runtime_copy._runtime_summary_suffix = ""
	return runtime_copy

func append_summary(message: String) -> void:
	if message == "":
		return
	_runtime_summary_suffix = message if _runtime_summary_suffix == "" else "%s\n%s" % [_runtime_summary_suffix, message]

func get_summary() -> String:
	var summary := ""
	if message_key != "":
		var translated := tr(message_key)
		if translated != message_key:
			summary = translated
	if _runtime_summary_suffix == "":
		return summary
	return _runtime_summary_suffix if summary == "" else "%s\n%s" % [summary, _runtime_summary_suffix]

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
