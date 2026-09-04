class_name AlchemistServiceRowUI extends PanelContainer

signal action_requested()

@onready var badge_label: Label = $Margin/Row/Badge/Label
@onready var title_label: Label = $Margin/Row/Details/Title
@onready var detail_label: Label = $Margin/Row/Details/Detail
@onready var cost_label: Label = $Margin/Row/Cost
@onready var action_button: Button = $Margin/Row/Action

func _ready() -> void:
	if not action_button.pressed.is_connected(action_requested.emit):
		action_button.pressed.connect(action_requested.emit)

func setup(
	title: String,
	detail: String,
	cost: int,
	action_text: String,
	badge: String,
	tooltip: String,
	is_available: bool,
	disabled_reason: String = ""
) -> void:
	if not is_node_ready():
		await ready
	badge_label.text = badge
	title_label.text = title
	detail_label.text = detail
	cost_label.text = tr("ALCHEMIST_COST") % cost
	action_button.text = action_text
	action_button.disabled = not is_available
	tooltip_text = tooltip
	title_label.tooltip_text = tooltip
	detail_label.tooltip_text = tooltip
	action_button.tooltip_text = disabled_reason if not is_available and not disabled_reason.is_empty() else tooltip
