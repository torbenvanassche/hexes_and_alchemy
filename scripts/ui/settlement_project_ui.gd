extends MarginContainer

const REQUIREMENT_ROW := preload("res://scenes/ui/components/settlement_requirement_row.tscn")
var _primary_action := ""

@onready var step_label: Label = $Body/Scroll/Content/Step
@onready var guidance_label: Label = $Body/Scroll/Content/Guidance
@onready var materials_list: VBoxContainer = $Body/Scroll/Content/Materials
@onready var primary_button: Button = $Body/Scroll/Content/Primary
@onready var market_button: Button = $Body/Scroll/Content/Alternatives/Market
@onready var board_button: Button = $Body/Scroll/Content/Alternatives/Board
@onready var treasury_label: Label = $Body/Scroll/Content/Treasury

func _ready() -> void:
	primary_button.tooltip_text = tr("CAMPAIGN_CONTROLS")
	$Body/Scroll/Content/Alternatives.tooltip_text = tr("CAMPAIGN_FORGE_CHOICES")
	var campaign: SettlementCampaign = Manager.instance.campaign
	campaign.changed.connect(_refresh)
	primary_button.pressed.connect(func() -> void: campaign.perform_action(_primary_action))
	market_button.pressed.connect(campaign.perform_action.bind("market"))
	board_button.pressed.connect(campaign.perform_action.bind("board"))
	_refresh()

func on_enter() -> void:
	_refresh()

func _refresh() -> void:
	if not is_inside_tree() or SaveGames.is_loading: return
	var campaign: SettlementCampaign = Manager.instance.campaign
	if not is_instance_valid(campaign.settlement) or not campaign.settlement.is_inside_tree(): return
	var settlement := campaign.settlement
	$Body/Scroll/Content/SettlementStatus.text = tr("CAMPAIGN_SETTLEMENT_LEVEL") % settlement.level
	treasury_label.text = tr("CAMPAIGN_TREASURY") % Manager.instance.hub.currency
	for child in materials_list.get_children():
		materials_list.remove_child(child)
		child.queue_free()
	if campaign.is_forge_chapter():
		$Body/Scroll/Content/Title.text = campaign.get_title()
		$Body/Scroll/Content/Purpose.text = campaign.get_purpose()
		step_label.text = campaign.get_step_text()
		guidance_label.text = campaign.get_guidance()
		for item: ItemInfo in campaign.get_current_requirements():
			_add_material(item, campaign.get_requirement_count(item), campaign.get_current_requirements()[item])
		$Body/Scroll/Content/MaterialsHeader.text = tr("CAMPAIGN_MATERIALS_BUILD")
		_primary_action = campaign.get_primary_action()
	else:
		$Body/Scroll/Content/Title.text = campaign.get_title()
		$Body/Scroll/Content/Purpose.text = campaign.get_purpose()
		step_label.text = campaign.get_step_text()
		guidance_label.text = campaign.get_guidance()
		$Body/Scroll/Content/MaterialsHeader.text = tr("CAMPAIGN_OPENING_PROGRESS")
		_add_milestone(tr("CAMPAIGN_OPENING_FORGE"), settlement.has_service(&"Blacksmith"))
		var completed := Manager.instance.regional.completed_project_count()
		_add_milestone(tr("CAMPAIGN_OPENING_PROJECTS") % [completed, campaign.chapter.required_projects], completed >= campaign.chapter.required_projects)
		_add_milestone(tr("CAMPAIGN_OPENING_TRADE"), Manager.instance.transport.is_partner(campaign.get_trade_coord()))
		_primary_action = campaign.get_primary_action()
	materials_list.visible = materials_list.get_child_count() > 0
	$Body/Scroll/Content/MaterialsHeader.visible = materials_list.visible
	primary_button.visible = not _primary_action.is_empty()
	$Body/Scroll/Content/ActionRule.visible = primary_button.visible
	primary_button.text = tr("CAMPAIGN_ACTION_%s" % _primary_action.to_upper()) if primary_button.visible else ""
	primary_button.disabled = not campaign.can_perform_action(_primary_action)
	market_button.visible = _primary_action != "market"
	board_button.visible = _primary_action != "board"
	market_button.disabled = campaign.get_destination("market") == null
	board_button.disabled = campaign.get_destination("board") == null

func _add_milestone(text: String, complete: bool) -> void:
	var row := REQUIREMENT_ROW.instantiate() as SettlementRequirementRowUI
	materials_list.add_child(row)
	row.setup(text, complete)

func _add_material(item: ItemInfo, owned: int, needed: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var icon := TextureRect.new()
	icon.texture = item.texture
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	var header := HBoxContainer.new()
	detail.add_child(header)
	var label := Label.new()
	label.text = item.get_display_name()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var count := Label.new()
	count.text = "%d / %d" % [owned, needed]
	header.add_child(count)
	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 5)
	progress.max_value = maxi(1, needed)
	progress.value = owned if needed > 0 else 1
	progress.show_percentage = false
	detail.add_child(progress)
	materials_list.add_child(row)
