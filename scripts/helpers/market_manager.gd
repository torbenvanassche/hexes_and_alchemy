class_name MarketManager extends Node

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
