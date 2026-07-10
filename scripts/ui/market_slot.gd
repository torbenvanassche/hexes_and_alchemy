class_name MarketSlotUI
extends Button

enum TileMode { BUY, SELL }

signal action_completed()

@onready var item_icon: TextureRect = $MarginContainer/Content/Icon
@onready var item_name_label: Label = $MarginContainer/Content/Name
@onready var price_label: RichTextLabel = $MarginContainer/Content/Price

var mode: TileMode = TileMode.BUY
var source_slot: ContentSlotResource
var destination_inventory: ContentGroup
var player_inventory: ContentGroup
var content: Resource
var unit_price: int = 0

func _ready() -> void:
	pressed.connect(_on_pressed)

func configure_buy(slot: ContentSlotResource, target_inventory: ContentGroup) -> void:
	mode = TileMode.BUY
	source_slot = slot
	destination_inventory = target_inventory
	content = source_slot.get_content() if source_slot else null
	unit_price = Manager.instance.market.get_buy_value(content)
	_set_item(content)
	disabled = content == null

func configure_sell(_content: Resource, _owned_count: int, inventory: ContentGroup) -> void:
	mode = TileMode.SELL
	content = _content
	player_inventory = inventory
	unit_price = Manager.instance.market.get_sell_now_value(content)
	_set_item(content)
	disabled = content == null

func _set_item(item: Resource) -> void:
	var item_info := item as ItemInfo
	var display_name := _get_display_name(item)
	item_icon.texture = item_info.texture if item_info else null
	item_icon.tooltip_text = display_name
	item_name_label.text = display_name
	item_name_label.tooltip_text = display_name
	tooltip_text = display_name
	price_label.text = "%s [img=18x18]res://sprites/items/coin_single.png[/img]" % unit_price

func _on_pressed() -> void:
	match mode:
		TileMode.BUY:
			if Manager.instance.market.buy_from_slot(source_slot, destination_inventory, 1):
				action_completed.emit()
		TileMode.SELL:
			if Manager.instance.market.sell_now(player_inventory, content, 1):
				action_completed.emit()

func _get_display_name(item: Resource) -> String:
	if item == null:
		return ""
	if item.has_method("get_display_name"):
		return item.get_display_name()
	return str(item)
