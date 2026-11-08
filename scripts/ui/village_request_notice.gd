class_name VillageRequestNotice
extends VBoxContainer

const AUTHOR_WIDTH := 112
const STATUS_WIDTH := 132
const ACTION_WIDTH := 116
var request_id := ""
var view_button: Button
var title_label: Label
var author_label: Label
var state_label: Label

static func add_columns(row: HBoxContainer) -> Array[Label]:
	row.add_theme_constant_override("separation", 12)
	var labels: Array[Label] = []
	for width: int in [0, AUTHOR_WIDTH, STATUS_WIDTH]:
		var label := Label.new()
		label.custom_minimum_size.x = width
		label.size_flags_vertical = Control.SIZE_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Labels ignore mouse events by default, which lets the row's tooltip win.
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if width == 0 else Control.SIZE_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = true
		row.add_child(label)
		labels.append(label)
	return labels

static func create_header() -> HBoxContainer:
	var row := HBoxContainer.new()
	var labels := add_columns(row)
	for index in 3:
		labels[index].text = ["QUEST_REQUEST_TABLE_TITLE", "QUEST_REQUEST_TABLE_AUTHOR", "QUEST_REQUEST_TABLE_STATUS"][index]
		labels[index].theme_type_variation = &"MutedLabel"
		labels[index].add_theme_font_size_override("font_size", 13)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = ACTION_WIDTH
	row.add_child(spacer)
	return row

func setup(id: String, title: String, author: String, state: String, _reward: String, open_request: Callable, _progress := 0.08) -> void:
	request_id = id
	add_theme_constant_override("separation", 0)
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 52
	add_child(row)
	var labels := add_columns(row)
	title_label = labels[0]
	author_label = labels[1]
	state_label = labels[2]
	title_label.text = title
	author_label.text = author
	state_label.text = state
	for label: Label in labels: label.tooltip_text = label.text
	state_label.theme_type_variation = &"MutedLabel"
	view_button = Button.new()
	view_button.custom_minimum_size.x = ACTION_WIDTH
	view_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	view_button.text = "QUEST_REQUEST_VIEW"
	view_button.pressed.connect(open_request.bind(id))
	row.add_child(view_button)
	add_child(HSeparator.new())
	# Each cell owns its tooltip; reward details belong to the request page.
	tooltip_text = ""
