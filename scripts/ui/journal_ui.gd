class_name JournalUI extends PanelContainer

@onready var entries_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/Entries
@onready var reputation_progress: ProgressBar = $MarginContainer/VBoxContainer/GuildStanding/ReputationProgress
@onready var notoriety_progress: ProgressBar = $MarginContainer/VBoxContainer/GuildStanding/NotorietyProgress

@export var entry_scene: PackedScene

var _refresh_queued := false

func on_enter() -> void:
	_request_refresh_entries()
	_refresh_guild_standing()

func _ready() -> void:
	if Manager.instance != null and Manager.instance.journal != null:
		Manager.instance.journal.journal_changed.connect(_request_refresh_entries)
	if Manager.instance != null and Manager.instance.reputation != null:
		Manager.instance.reputation.changed.connect(_refresh_guild_standing)
	_refresh_guild_standing()
	_request_refresh_entries()

func _exit_tree() -> void:
	if Manager.instance != null and Manager.instance.journal != null:
		if Manager.instance.journal.journal_changed.is_connected(_request_refresh_entries):
			Manager.instance.journal.journal_changed.disconnect(_request_refresh_entries)
	if Manager.instance != null and Manager.instance.reputation != null:
		if Manager.instance.reputation.changed.is_connected(_refresh_guild_standing):
			Manager.instance.reputation.changed.disconnect(_refresh_guild_standing)

func _refresh_guild_standing() -> void:
	if Manager.instance == null or Manager.instance.reputation == null:
		reputation_progress.value = 0
		notoriety_progress.value = 0
		return
	var standing := Manager.instance.reputation
	reputation_progress.value = clampi(standing.reputation, 0, int(reputation_progress.max_value))
	notoriety_progress.value = clampi(standing.notoriety, 0, int(notoriety_progress.max_value))

func _request_refresh_entries() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh_entries.call_deferred()

func _refresh_entries() -> void:
	_refresh_queued = false
	if entries_container == null or entry_scene == null:
		return

	for child: Node in entries_container.get_children():
		entries_container.remove_child(child)
		child.queue_free()

	for entry: JournalEntry in _get_visible_entries():
		var entry_ui := entry_scene.instantiate() as JournalEntryUI
		if entry_ui == null:
			continue
		entries_container.add_child(entry_ui)
		entry_ui.set_entry(entry)

func _get_visible_entries() -> Array[JournalEntry]:
	if Manager.instance != null and Manager.instance.journal != null:
		return Manager.instance.journal.get_entries()

	return []
