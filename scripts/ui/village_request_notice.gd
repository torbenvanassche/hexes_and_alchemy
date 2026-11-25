class_name VillageRequestNotice
extends VBoxContainer

@export var column_header := false

@onready var title_label: Label = $Columns/Title
@onready var author_label: Label = $Columns/Author
@onready var state_label: Label = $Columns/Status
@onready var view_button: Button = $Columns/Action/View

func _ready() -> void:
	if not column_header:
		return
	$Columns.custom_minimum_size.y = 28
	view_button.hide()
	title_label.text = "QUEST_REQUEST_TABLE_TITLE"
	author_label.text = "QUEST_REQUEST_TABLE_AUTHOR"
	state_label.text = "QUEST_REQUEST_TABLE_STATUS"
	for label in [title_label, author_label, state_label]:
		label.theme_type_variation = &"SectionHeading"
		label.uppercase = true

func setup(id: String, title: String, author: String, state: String, open_request: Callable) -> void:
	title_label.text = title
	author_label.text = author
	state_label.text = state
	for label in [title_label, author_label, state_label]:
		label.tooltip_text = label.text
	view_button.pressed.connect(open_request.bind(id))
