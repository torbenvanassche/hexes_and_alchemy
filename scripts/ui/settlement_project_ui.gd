extends MarginContainer

@onready var step_label: Label = $Body/Scroll/Content/Step
@onready var guidance_label: Label = $Body/Scroll/Content/Guidance
@onready var materials_list: VBoxContainer = $Body/Scroll/Content/Materials
@onready var primary_button: Button = $Body/Scroll/Content/Primary
@onready var market_button: Button = $Body/Scroll/Content/Alternatives/Market
@onready var board_button: Button = $Body/Scroll/Content/Alternatives/Board
@onready var treasury_label: Label = $Body/Scroll/Content/Treasury

func _ready() -> void:
	$Body/Scroll/Content/Trade.pressed.connect(func() -> void: Manager.instance.transport.open_window())
	$Body/Scroll/Content/Title.tooltip_text = tr("CAMPAIGN_FORGE_PURPOSE")
	primary_button.tooltip_text = tr("CAMPAIGN_CONTROLS")
	$Body/Scroll/Content/Alternatives.tooltip_text = tr("CAMPAIGN_FORGE_CHOICES")
	var campaign: SettlementCampaign = Manager.instance.campaign
	campaign.changed.connect(_refresh)
	primary_button.pressed.connect(func() -> void: campaign.perform_action(campaign.get_primary_action()))
	market_button.pressed.connect(campaign.perform_action.bind("market"))
	board_button.pressed.connect(campaign.perform_action.bind("board"))
	_refresh()

func _refresh() -> void:
	var campaign: SettlementCampaign = Manager.instance.campaign
	step_label.text = campaign.get_step_text()
	guidance_label.text = campaign.get_guidance()
	treasury_label.text = tr("CAMPAIGN_TREASURY") % Manager.instance.hub.currency
	for child in materials_list.get_children():
		materials_list.remove_child(child)
		child.queue_free()
	if campaign.stage != SettlementCampaign.Stage.COMPLETE:
		var materials := campaign.get_materials()
		for item: ItemInfo in materials:
			var needed: int = materials[item]
			_add_material(item, Manager.instance.hub.stockpile.get_count(item), needed)
	materials_list.visible = materials_list.get_child_count() > 0
	var action := campaign.get_primary_action()
	market_button.visible = action != "market"
	board_button.visible = action != "board"
	primary_button.text = tr("CAMPAIGN_ACTION_%s" % action.to_upper())
	primary_button.disabled = action != "stockpile" and campaign.get_destination(action) == null
	market_button.disabled = campaign.get_destination("market") == null
	board_button.disabled = campaign.get_destination("board") == null

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
