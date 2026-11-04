extends VBoxContainer

@onready var destinations: OptionButton = %Destinations
var selected := Vector3i.MAX
var _coords: Array[Vector3i] = []

func _ready() -> void:
	destinations.item_selected.connect(func(index: int) -> void: selected = _coords[index]; _refresh())
	%Dispatch.pressed.connect(_dispatch)
	%Recall.pressed.connect(func() -> void:
		if not Manager.instance.transport.recall(): %Feedback.text = Manager.instance.transport.last_error
	)
	%Resume.pressed.connect(func() -> void:
		if not Manager.instance.transport.resume_route(): %Feedback.text = Manager.instance.transport.last_error
	)
	%NextRequest.pressed.connect(func() -> void: Manager.instance.transport.next_request(selected))
	%Locate.pressed.connect(_locate)
	Manager.instance.transport.changed.connect(_refresh)
	Manager.instance.hub.changed.connect(_refresh)
	_refresh()

func select_destination(coord: Vector3i) -> void:
	selected = coord
	if is_node_ready(): _refresh()

func on_enter() -> void:
	%Feedback.text = ""
	_refresh()

func _refresh() -> void:
	if not is_node_ready(): return
	var transport := Manager.instance.transport
	_coords.clear()
	destinations.clear()
	for village: Settlement in transport.destinations():
		var coord: Vector3i = village.get_parent().cube_id
		_coords.append(coord)
		destinations.add_item(tr("SHIPMENT_VILLAGE_NAME") + (" %d" % _coords.size() if _coords.size() > 1 else ""))
	if not _coords.has(selected): selected = _coords[0] if not _coords.is_empty() else Vector3i.MAX
	var exists := selected != Vector3i.MAX
	%RequestBody.visible = exists
	%Empty.visible = not exists
	destinations.disabled = not exists
	if not exists: return
	destinations.select(_coords.find(selected))
	var request := transport.get_request(selected)
	var record := transport.get_record(selected)
	%Title.text = tr(request.title_key)
	%Description.text = tr(request.description_key)
	%Reward.text = tr("SHIPMENT_REWARD") % [request.payment, request.reputation_reward]
	%Standing.text = tr("SHIPMENT_STANDING") % [int(record.get("completed", 0)), int(record.get("influence", 0))]
	%Carrier.text = tr("SHIPMENT_CARRIER_LOAD") % [tr(transport.carrier.name_key), transport.cargo_size(request), transport.carrier.capacity]
	%Carrier.tooltip_text = tr("SHIPMENT_CAPACITY_HINT")
	for child in %Materials.get_children():
		%Materials.remove_child(child)
		child.queue_free()
	var shipment: Dictionary = transport.active_shipment
	var this_shipment: bool = not shipment.is_empty() and shipment.destination == selected
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
		var amount := Label.new()
		var quantity := int(request.cargo[item]) if this_shipment else Manager.instance.hub.stockpile.get_count(item)
		amount.text = "%d / %d" % [quantity, request.cargo[item]]
		amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(amount)
		%Materials.add_child(row)
	%Dispatch.disabled = not transport.dispatch_block_reason(selected).is_empty()
	%Dispatch.tooltip_text = transport.dispatch_block_reason(selected)
	%Dispatch.visible = record.get("phase", "available") == "available"
	%NextRequest.visible = record.get("phase") == "fulfilled"
	%NextRequest.disabled = not shipment.is_empty()
	%Recall.visible = this_shipment and shipment.phase == "outbound"
	%Resume.visible = this_shipment and shipment.blocked
	%Locate.visible = not this_shipment
	%Materials.visible = record.get("phase") != "fulfilled" and (not this_shipment or shipment.phase == "outbound")
	if this_shipment:
		%Status.text = tr("SHIPMENT_ROUTE_BLOCKED") if shipment.blocked else tr("SHIPMENT_PHASE_" + str(shipment.phase).to_upper()) % ceili(transport.remaining_seconds())
	elif record.get("phase") == "fulfilled": %Status.text = tr("SHIPMENT_FULFILLED")
	else:
		var path := transport.route_to(selected)
		%Status.text = tr("SHIPMENT_ROUTE_PREVIEW") % maxi(0, path.size() - 1) if not path.is_empty() else tr("SHIPMENT_NO_ROUTE")
		if record.is_empty(): %Status.text = tr("SHIPMENT_VISIT_FIRST")
	%CargoHint.visible = %Materials.visible
	%CargoHint.text = tr("SHIPMENT_CARGO_LOADED") if this_shipment else tr("SHIPMENT_CARGO_HINT")
	$RequestBody/DemandDivider.visible = %Materials.visible

func _dispatch() -> void:
	if not Manager.instance.transport.dispatch(selected): %Feedback.text = Manager.instance.transport.last_error

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
