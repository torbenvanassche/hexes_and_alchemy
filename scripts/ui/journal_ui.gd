class_name JournalUI extends Control

@onready var reputation_progress: ProgressBar = $MarginContainer/VBoxContainer/GuildStanding/ReputationProgress
@onready var notoriety_progress: ProgressBar = $MarginContainer/VBoxContainer/GuildStanding/NotorietyProgress
@onready var reputation_value: Label = $MarginContainer/VBoxContainer/GuildStanding/ReputationRow/ReputationValue
@onready var notoriety_value: Label = $MarginContainer/VBoxContainer/GuildStanding/NotorietyRow/NotorietyValue
@onready var prestige_value: Label = $MarginContainer/VBoxContainer/GuildStanding/PrestigeRow/PrestigeValue
@onready var page_host: Control = $MarginContainer/VBoxContainer/PageHost
@onready var previous_page_button: Button = $MarginContainer/VBoxContainer/ChapterNavigation/PreviousPageButton
@onready var chapter_selector: OptionButton = $MarginContainer/VBoxContainer/ChapterNavigation/ChapterSelector
@onready var next_page_button: Button = $MarginContainer/VBoxContainer/ChapterNavigation/NextPageButton

@export var page_scene: PackedScene

var _refresh_queued := false
var _visible_entries: Array[JournalEntry] = []
var _current_page := 0

func on_enter() -> void:
	_request_refresh_pages()
	_refresh_guild_standing()

func _ready() -> void:
	previous_page_button.pressed.connect(_show_previous_page)
	next_page_button.pressed.connect(_show_next_page)
	chapter_selector.item_selected.connect(_show_selected_page)
	if Manager.instance != null and Manager.instance.journal != null:
		Manager.instance.journal.journal_changed.connect(_request_refresh_pages)
	if Manager.instance != null and Manager.instance.reputation != null:
		Manager.instance.reputation.changed.connect(_refresh_guild_standing)
	if Manager.instance != null and Manager.instance.hub != null:
		Manager.instance.hub.changed.connect(_refresh_guild_standing)
	_refresh_guild_standing()
	_request_refresh_pages()

func _exit_tree() -> void:
	if Manager.instance != null and Manager.instance.journal != null:
		if Manager.instance.journal.journal_changed.is_connected(_request_refresh_pages):
			Manager.instance.journal.journal_changed.disconnect(_request_refresh_pages)
	if Manager.instance != null and Manager.instance.reputation != null:
		if Manager.instance.reputation.changed.is_connected(_refresh_guild_standing):
			Manager.instance.reputation.changed.disconnect(_refresh_guild_standing)
	if Manager.instance != null and Manager.instance.hub != null:
		if Manager.instance.hub.changed.is_connected(_refresh_guild_standing):
			Manager.instance.hub.changed.disconnect(_refresh_guild_standing)

func _refresh_guild_standing() -> void:
	if Manager.instance == null or Manager.instance.reputation == null:
		reputation_progress.value = 0
		notoriety_progress.value = 0
		reputation_value.text = "0 / %d" % int(reputation_progress.max_value)
		notoriety_value.text = "0 / %d" % int(notoriety_progress.max_value)
		prestige_value.text = "0"
		return
	var standing := Manager.instance.reputation
	reputation_progress.value = clampi(standing.reputation, 0, int(reputation_progress.max_value))
	notoriety_progress.value = clampi(standing.notoriety, 0, int(notoriety_progress.max_value))
	reputation_value.text = "%d / %d" % [int(reputation_progress.value), int(reputation_progress.max_value)]
	notoriety_value.text = "%d / %d" % [int(notoriety_progress.value), int(notoriety_progress.max_value)]
	prestige_value.text = str(Manager.instance.hub.prestige if Manager.instance.hub != null else 0)

func _request_refresh_pages() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh_pages.call_deferred()

func _refresh_pages() -> void:
	_refresh_queued = false
	if page_host == null or page_scene == null:
		return

	var current_entry_id := _get_current_entry_id()
	_visible_entries = _get_visible_entries()
	_current_page = _get_entry_index(current_entry_id)
	if _current_page == -1:
		_current_page = clampi(_current_page, 0, maxi(_visible_entries.size() - 1, 0))
	_show_current_page()

func _show_previous_page() -> void:
	if _current_page <= 0:
		return
	_current_page -= 1
	_show_current_page()

func _show_next_page() -> void:
	if _current_page >= _visible_entries.size() - 1:
		return
	_current_page += 1
	_show_current_page()

func _show_selected_page(page_index: int) -> void:
	if page_index < 0 or page_index >= _visible_entries.size() or page_index == _current_page:
		return
	_current_page = page_index
	_show_current_page()

func _show_current_page() -> void:
	for child: Node in page_host.get_children():
		page_host.remove_child(child)
		child.queue_free()

	chapter_selector.clear()
	for entry: JournalEntry in _visible_entries:
		chapter_selector.add_item(tr(entry.title_key))

	var has_pages := not _visible_entries.is_empty()
	chapter_selector.disabled = not has_pages
	previous_page_button.disabled = not has_pages or _current_page == 0
	next_page_button.disabled = not has_pages or _current_page == _visible_entries.size() - 1
	if not has_pages:
		return

	chapter_selector.select(_current_page)
	var page := page_scene.instantiate() as JournalPageUI
	if page == null:
		return
	page_host.add_child(page)
	page.set_entry(_visible_entries[_current_page])

func _get_current_entry_id() -> String:
	if _current_page < 0 or _current_page >= _visible_entries.size():
		return ""
	return _visible_entries[_current_page].id

func _get_entry_index(entry_id: String) -> int:
	if entry_id.is_empty():
		return -1
	for index in _visible_entries.size():
		if _visible_entries[index].id == entry_id:
			return index
	return -1

func _get_visible_entries() -> Array[JournalEntry]:
	if Manager.instance != null and Manager.instance.journal != null:
		return Manager.instance.journal.get_entries()

	return []
