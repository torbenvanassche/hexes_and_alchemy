class_name JournalPageUI extends ScrollContainer

@onready var entry_ui: JournalEntryUI = $MarginContainer/JournalEntry

var _entry: JournalEntry

func _ready() -> void:
	_refresh()

func set_entry(entry: JournalEntry) -> void:
	_entry = entry
	_refresh()

func _refresh() -> void:
	if not is_node_ready() or _entry == null:
		return
	entry_ui.set_entry(_entry)
