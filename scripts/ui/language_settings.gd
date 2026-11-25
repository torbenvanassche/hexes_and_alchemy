extends Control

@onready var language_picker: OptionButton = %LanguagePicker

func _ready() -> void:
	for locale: String in Manager.SUPPORTED_LANGUAGES:
		language_picker.add_item(tr(Manager.SUPPORTED_LANGUAGES[locale]))
		language_picker.set_item_metadata(language_picker.item_count - 1, locale)
	language_picker.item_selected.connect(_on_language_selected)
	language_picker.disabled = language_picker.item_count <= 1
	_sync_selection()

func _sync_selection() -> void:
	var locale := TranslationServer.get_locale().substr(0, 2)
	for index in language_picker.item_count:
		if language_picker.get_item_metadata(index) == locale:
			language_picker.select(index)
			return
	language_picker.select(0)

func _on_language_selected(index: int) -> void:
	if not is_instance_valid(Manager.instance):
		return
	Manager.instance.set_language(str(language_picker.get_item_metadata(index)))
	for language_index in language_picker.item_count:
		var locale: String = language_picker.get_item_metadata(language_index)
		language_picker.set_item_text(language_index, tr(Manager.SUPPORTED_LANGUAGES[locale]))
