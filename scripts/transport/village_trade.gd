extends Market

@export var partnership_stock: Array[ContentSlotResource] = []

func _ready() -> void:
	super()
	_keep_stock_identity()
	_sync_partnership.call_deferred()

func _keep_stock_identity() -> void:
	# Keep sold-out products identifiable so reopening/loading cannot refill them.
	for index in mini(buy_menu.size(), buy_inventory.data.size()):
		var slot := buy_inventory.data[index]
		if slot.get_content() == null: slot.set_content(buy_menu[index].get_content())
		slot.clear_on_empty = false

func _sync_partnership() -> void:
	var origin := settlement.get_parent() as HexBase if is_instance_valid(settlement) else null
	if origin != null and Manager.instance.transport.is_partner(origin.cube_id): apply_partnership_stock(false)

func apply_partnership_stock(restock: bool = false) -> void:
	_keep_stock_identity()
	for template: ContentSlotResource in partnership_stock:
		var found := false
		for slot: ContentSlotResource in buy_inventory.data:
			if slot.get_content() == template.get_content(): found = true; break
		if not found:
			buy_inventory.add_slot(ContentSlotResource.new(0, template.get_content(), template.maxcount, true, false))
	if restock:
		for slot: ContentSlotResource in buy_inventory.data:
			slot.clear_on_empty = false
			slot.add(maxi(0, slot.maxcount - slot.count))
	buy_inventory.max_slots = buy_inventory.data.size()
	buy_inventory.unlocked_slots = buy_inventory.data.size()
	$PartnershipGoods.show()
	buy_inventory.changed.emit()

func can_interact() -> bool:
	return is_instance_valid(settlement) and settlement.is_visible_in_tree() and not SaveGames.is_loading and super()
