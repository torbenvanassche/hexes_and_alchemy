extends VBoxContainer

@onready var destinations: OptionButton = %Destinations
var selected := Vector3i.MAX
var _coords: Array[Vector3i] = []
var _refresh_pending := false

func _ready() -> void:
	destinations.item_selected.connect(func(index: int) -> void: selected = _coords[index]; _refresh())
	%Dispatch.pressed.connect(_dispatch)
	%Recall.pressed.connect(func() -> void:
		if not Manager.instance.transport.recall(): _show_error(Manager.instance.transport.last_error)
	)
	%Resume.pressed.connect(func() -> void:
		if not Manager.instance.transport.resume_route(): _show_error(Manager.instance.transport.last_error)
	)
	%NextRequest.pressed.connect(func() -> void: Manager.instance.transport.next_request(selected))
	%Locate.pressed.connect(_locate)
	Manager.instance.transport.changed.connect(_queue_refresh)
	Manager.instance.hub.changed.connect(_queue_refresh)
	Manager.instance.hub.mapped_changed.connect(_queue_refresh)
	_refresh()

func _queue_refresh() -> void:
	if _refresh_pending or not is_visible_in_tree(): return
	_refresh_pending = true
	_refresh_visible.call_deferred()

func _refresh_visible() -> void:
	_refresh_pending = false
	if is_visible_in_tree(): _refresh()

func select_destination(coord: Vector3i) -> void:
	selected = coord
	if is_node_ready(): _refresh()

func on_enter() -> void:
	%Feedback.text = ""
	_refresh()

func _refresh() -> void:
	if not is_node_ready() or not is_inside_tree() or SaveGames.is_loading: return
	var transport := Manager.instance.transport
	var grid := transport.get_grid()
	if grid == null or not grid.is_inside_tree(): return
	_coords.clear()
	destinations.clear()
	for village: Settlement in transport.destinations():
		var coord: Vector3i = village.get_parent().cube_id
		_coords.append(coord)
		destinations.add_item(tr("SHIPMENT_VILLAGE_NAME") + (" %d" % _coords.size() if _coords.size() > 1 else ""))
	if not _coords.has(selected):
		selected = transport.active_shipment.destination if not transport.active_shipment.is_empty() else Vector3i.MAX
		if not _coords.has(selected): selected = _coords[0] if not _coords.is_empty() else Vector3i.MAX
	var exists := selected != Vector3i.MAX
	%RequestBody.visible = exists
	%Scroll.visible = exists
	%Actions.visible = exists
	%FooterDivider.visible = exists
	%Empty.visible = not exists
	%Feedback.visible = not %Feedback.text.is_empty()
	destinations.visible = exists
	destinations.disabled = not exists
	if not exists: return
	destinations.select(_coords.find(selected))
	var request := transport.get_request(selected)
	var record := transport.get_record(selected)
	var shipment: ShipmentJourney = transport.active_shipment
	var this_shipment: bool = not shipment.is_empty() and shipment.destination == selected
	%Title.text = tr(request.title_key)
	%Description.text = tr(request.description_key)
	var delivered: bool = record.phase == "fulfilled" or (this_shipment and shipment.phase in ["unloading", "returning"])
	%RewardHeading.text = tr("SHIPMENT_REWARDS_RECEIVED" if delivered else "SHIPMENT_REWARDS_ON_DELIVERY")
	%CoinReward.set_amount(int(shipment.payment) if this_shipment else request.payment)
	%ReputationReward.set_amount(int(shipment.reputation) if this_shipment else request.reputation_reward, true)
	%InfluenceReward.set_amount(1, true)
	%PrestigeReward.set_amount(1, true)
	%Partnership.visible = request == TransportManager.PARTNERSHIP_REQUEST
	%Partnership.tooltip_text = tr("SHIPMENT_PARTNER_BENEFIT")
	var has_relationship := transport.has_first_delivery(selected)
	%Standing.visible = has_relationship
	%Standing.text = transport.get_relationship_text(selected) if has_relationship else ""
	%Standing.tooltip_text = tr("SHIPMENT_STANDING_RELATION") % [%Standing.text, record.completed, record.influence] if has_relationship else ""
	%Carrier.text = tr("SHIPMENT_CARRIER_LOAD") % [tr(transport.carrier.name_key), transport.cargo_size(request), transport.carrier.capacity]
	%Carrier.tooltip_text = tr("SHIPMENT_CAPACITY_HINT")
	for child in %Materials.get_children():
		%Materials.remove_child(child)
		child.queue_free()
	for item: ItemInfo in request.cargo:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = item.texture
		row.add_child(icon)
		var name_label := Label.new()
		name_label.text = item.get_display_name()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var quantity := int(shipment.cargo.get(item, 0)) if this_shipment else Manager.instance.hub.stockpile.get_count(item)
		for count: int in [quantity, int(request.cargo[item])]:
			var amount := Label.new()
			amount.custom_minimum_size.x = 64
			amount.text = str(count)
			amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			if quantity < int(request.cargo[item]): amount.add_theme_color_override("font_color", GameUI.WARNING)
			row.add_child(amount)
		%Materials.add_child(row)
	var blocked_reason := transport.dispatch_block_reason(selected)
	%Dispatch.disabled = not blocked_reason.is_empty()
	%Dispatch.tooltip_text = blocked_reason
	%Dispatch.visible = record.phase == "available"
	%NextRequest.visible = record.phase == "fulfilled"
	%NextRequest.text = tr("SHIPMENT_PREPARE_EQUIPMENT" if transport.has_first_delivery(selected) and not transport.is_partner(selected) else "SHIPMENT_NEXT_REQUEST")
	%NextRequest.disabled = not shipment.is_empty()
	%Recall.visible = this_shipment and shipment.phase == "outbound"
	%Resume.visible = this_shipment and shipment.blocked
	%Locate.visible = true
	%Materials.visible = record.phase != "fulfilled" and (not this_shipment or shipment.phase == "outbound")
	if this_shipment:
		%Status.text = tr("SHIPMENT_ROUTE_BLOCKED") if shipment.blocked else tr("SHIPMENT_PHASE_" + str(shipment.phase).to_upper()) % ceili(transport.remaining_seconds())
	elif record.phase == "fulfilled": %Status.text = tr("SHIPMENT_PARTNER_FULFILLED" if transport.is_partner(selected) else "SHIPMENT_FIRST_FULFILLED")
	else:
		var path := transport.route_to(selected)
		%Status.text = tr("SHIPMENT_ROUTE_PREVIEW") % maxi(0, path.size() - 1) if not path.is_empty() else tr("SHIPMENT_NO_ROUTE")
		if not blocked_reason.is_empty(): %Status.text = blocked_reason
	var state_key := "SHIPMENT_STATE_READY"
	var state_color := GameUI.SUCCESS
	if this_shipment:
		state_key = "SHIPMENT_STATE_" + ("BLOCKED" if shipment.blocked else str(shipment.phase).to_upper())
		state_color = GameUI.WARNING if shipment.blocked else (GameUI.ACCENT if shipment.phase == "unloading" else GameUI.TRAVEL)
	elif record.phase == "fulfilled": state_key = "SHIPMENT_STATE_DELIVERED"
	elif not blocked_reason.is_empty():
		state_key = "SHIPMENT_STATE_WAITING"
		state_color = GameUI.WARNING
	%State.text = tr(state_key)
	%State.add_theme_color_override("font_color", state_color)
	%Journey.visible = this_shipment
	if this_shipment:
		if shipment.phase == "unloading":
			%Journey.value = 100.0 * (1.0 - float(shipment.unload_remaining) / maxf(0.01, float(shipment.unload_duration)))
		else: %Journey.value = 100.0 * maxf(0, int(shipment.index) - 1) / maxi(1, shipment.route.size() - 1)
	%CargoHint.visible = %Materials.visible
	%Carrier.visible = %Materials.visible
	%Have.text = tr("SHIPMENT_COLUMN_LOADED" if this_shipment else "SHIPMENT_COLUMN_HAVE")
	%DemandDivider.visible = %Materials.visible
	%Feedback.visible = not %Feedback.text.is_empty()

func _dispatch() -> void:
	if not Manager.instance.transport.dispatch(selected): _show_error(Manager.instance.transport.last_error)

func _show_error(message: String) -> void:
	%Feedback.text = message
	%Feedback.visible = not message.is_empty()

func _locate() -> void:
	var village := Manager.instance.transport.village_at(selected)
	if village == null: return
	var campaign := Manager.instance.campaign
	campaign.destination = village.get_node("Buildings/Market")
	campaign.destination_name = tr("SHIPMENT_VILLAGE_NAME")
	campaign.destination_changed.emit()
	var ancestor := get_parent()
	while ancestor != null and not ancestor is DraggableControl: ancestor = ancestor.get_parent()
	if ancestor is DraggableControl: ancestor.close_window(true)
