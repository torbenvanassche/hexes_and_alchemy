class_name MarketManager extends Node

@export var sale_check_interval: float = 5.0
@export var base_sale_chance: float = 0.35
@export var min_sale_chance: float = 0.05
@export var max_sale_chance: float = 0.95
@export var default_list_markup: float = 1.25
@export var quick_sale_threshold: float = 1.0
@export var slow_sale_threshold: float = 0.5
@onready var market_timer: Timer = Timer.new();

signal tick();
signal listings_changed();

class MarketListing:
	var content: Resource
	var quantity: int
	var unit_price: int
	var sale_chance: float
	var listed_at_msec: int

	func _init(_content: Resource, _quantity: int, _unit_price: int, _sale_chance: float) -> void:
		content = _content
		quantity = _quantity
		unit_price = _unit_price
		sale_chance = _sale_chance
		listed_at_msec = Time.get_ticks_msec()

var active_listings: Array[MarketListing] = []

func _ready() -> void:
	market_timer.wait_time = sale_check_interval
	market_timer.timeout.connect(_on_market_tick);
	market_timer.autostart = true;
	add_child(market_timer)
	
func calculate_sell_chance(base_price: float, item_price: float) -> float:
	var sale_chance := base_sale_chance * (base_price / float(item_price));
	return clampf(sale_chance, min_sale_chance, max_sale_chance);

func get_buy_value(content: Resource) -> int:
	if content == null:
		return 0
	if content is ItemInfo:
		return (content as ItemInfo).get_buy_value()
	if not ("buy_value" in content):
		return 2
	return maxi(2, content.buy_value)

func get_sell_value(content: Resource) -> int:
	if content == null:
		return 0
	if content is ItemInfo:
		return (content as ItemInfo).get_sell_value()
	if not ("sell_value" in content):
		return maxi(1, get_buy_value(content) - 1)
	return maxi(1, mini(content.sell_value, get_buy_value(content) - 1))

func get_sell_now_value(content: Resource) -> int:
	return get_sell_value(content)

func get_default_list_price(content: Resource) -> int:
	return maxi(1, roundi(get_sell_value(content) * default_list_markup))

func get_sale_chance_label(chance: float) -> String:
	if chance >= base_sale_chance * quick_sale_threshold:
		return "Likely"
	if chance <= base_sale_chance * slow_sale_threshold:
		return "Slow"
	return "Fair"

func list_item(inventory: ContentGroup, content: Resource, quantity: int, unit_price: int) -> bool:
	if inventory == null or content == null or quantity <= 0 or unit_price <= 0:
		return false
	if inventory.get_count(content) < quantity:
		_notify("Not enough items to list.", Color.RED)
		return false
	var remaining := inventory.remove(content, quantity)
	if remaining > 0:
		_notify("Could not remove items from inventory.", Color.RED)
		return false
	var chance := calculate_sell_chance(get_sell_value(content), unit_price)
	active_listings.append(MarketListing.new(content, quantity, unit_price, chance))
	listings_changed.emit()
	_notify("%s listed for %s coins each." % [_get_display_name(content), unit_price])
	return true

func sell_now(inventory: ContentGroup, content: Resource, quantity: int) -> bool:
	if inventory == null or content == null or quantity <= 0:
		return false
	if inventory.get_count(content) < quantity:
		_notify("Not enough items to sell.", Color.RED)
		return false
	var remaining := inventory.remove(content, quantity)
	if remaining > 0:
		_notify("Could not remove items from inventory.", Color.RED)
		return false
	var unit_value := get_sell_now_value(content)
	Manager.instance.player_instance.currency += unit_value * quantity
	_notify("Sold %sx %s for %s coins." % [quantity, _get_display_name(content), unit_value * quantity])
	return true

func buy_from_slot(source_slot: ContentSlotResource, destination_inventory: ContentGroup, quantity: int) -> bool:
	if source_slot == null or destination_inventory == null or quantity <= 0:
		return false
	var content := source_slot.get_content()
	if content == null or source_slot.count <= 0:
		return false
	var amount := mini(quantity, source_slot.count)
	var unit_price := get_buy_value(content)
	var total_price := unit_price * amount
	if Manager.instance.player_instance.currency < total_price:
		_notify("Not enough coins.", Color.RED)
		return false
	if _get_available_capacity(destination_inventory, content) < amount:
		_notify("Inventory full.", Color.RED)
		return false
	var remaining := destination_inventory.add(content, amount)
	if remaining > 0:
		_notify("Inventory full.", Color.RED)
		return false
	Manager.instance.player_instance.currency -= total_price
	source_slot.remove(amount)
	_notify("Bought %sx %s for %s coins." % [amount, _get_display_name(content), total_price])
	return true

func cancel_listing(listing: MarketListing, inventory: ContentGroup) -> bool:
	if listing == null or inventory == null:
		return false
	var remaining := inventory.add(listing.content, listing.quantity)
	if remaining > 0:
		listing.quantity = remaining
		listings_changed.emit()
		_notify("Inventory full. Returned what could fit.", Color.YELLOW)
		return false
	active_listings.erase(listing)
	listings_changed.emit()
	_notify("Listing cancelled: %s." % _get_display_name(listing.content))
	return true

func _on_market_tick() -> void:
	tick.emit()
	if Manager.instance == null or Manager.instance.player_instance == null:
		return
	var sold_listings: Array[MarketListing] = []
	for listing in active_listings:
		if randf() <= listing.sale_chance:
			sold_listings.append(listing)
	for listing in sold_listings:
		_resolve_listing_sale(listing)

func _resolve_listing_sale(listing: MarketListing) -> void:
	active_listings.erase(listing)
	var total_price := listing.unit_price * listing.quantity
	Manager.instance.player_instance.currency += total_price
	listings_changed.emit()
	_notify("Sold %sx %s for %s coins." % [listing.quantity, _get_display_name(listing.content), total_price])

func _get_display_name(content: Resource) -> String:
	if content == null:
		return ""
	if content.has_method("get_display_name"):
		return content.get_display_name()
	return str(content)

func _get_available_capacity(inventory: ContentGroup, content: Resource) -> int:
	if inventory == null:
		return 0
	var capacity := 0
	for slot in inventory.data:
		if slot == null or not slot.is_unlocked:
			continue
		if slot.has_content(content):
			capacity += maxi(0, slot.maxcount - slot.count)
		elif slot.has_content(null):
			capacity += maxi(0, slot.maxcount)
	return capacity

func _notify(message: String, color: Color = Color.WHITE) -> void:
	if Manager.instance and Manager.instance.toast:
		Manager.instance.toast.notify(message, color)
