extends Market

const MARKER := preload("res://scenes/hud/location_marker.tscn")
var _marker: LocationMarker

func _ready() -> void:
	super()
	_create_marker.call_deferred()

func _create_marker() -> void:
	_marker = MARKER.instantiate() as LocationMarker
	# A sibling avoids measuring the marker as part of its own target bounds.
	get_parent().add_child(_marker)
	_marker.track(self)

func _process(_delta: float) -> void:
	if not is_instance_valid(_marker) or not is_instance_valid(settlement): return
	var origin := settlement.get_parent() as HexBase
	var show_marker := origin != null and origin.is_explored and is_visible_in_tree() and Manager.instance.transport.get_record(origin.cube_id).is_empty()
	show_marker = show_marker and Manager.instance.campaign.destination != self
	_marker.track(self if show_marker else null)

func _exit_tree() -> void:
	if is_instance_valid(_marker): _marker.queue_free()

func can_interact() -> bool:
	return is_instance_valid(settlement) and settlement.is_visible_in_tree() and not SaveGames.is_loading and super()

func interact() -> void:
	var origin := settlement.get_parent() as HexBase
	if origin == null: return
	Manager.instance.transport.meet_village(origin.cube_id)
	super()

func _open_window(window_info: SceneInfo) -> void:
	super(window_info)
	var origin := settlement.get_parent() as HexBase
	if origin != null and is_instance_valid(window_instance):
		(window_instance.node.content as MarketUI).set_shipment_destination(origin.cube_id)
