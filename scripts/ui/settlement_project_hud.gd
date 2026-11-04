extends PanelContainer

@onready var step_label: Label = $Margin/Content/Step
@onready var destination_label: Label = $Margin/Content/Destination
@onready var project_button: Button = $Margin/Content/Actions/Project
@onready var clear_button: Button = $Margin/Content/Actions/Clear

const MARKER_SCENE := preload("res://scenes/hud/location_marker.tscn")

var _marker: LocationMarker

func _ready() -> void:
	project_button.pressed.connect(_open_project)
	clear_button.pressed.connect(func() -> void: Manager.instance.campaign.clear_destination())
	_connect_campaign.call_deferred()

func _connect_campaign() -> void:
	Manager.instance.campaign.changed.connect(_refresh)
	Manager.instance.campaign.destination_changed.connect(_refresh)
	_marker = MARKER_SCENE.instantiate() as LocationMarker
	Manager.instance.add_child(_marker)
	_refresh()

func _open_project() -> void:
	if Manager.instance.player_instance != null:
		Manager.instance.player_instance.toggle_hub_tab("projects")

func _refresh() -> void:
	var campaign := Manager.instance.campaign
	step_label.text = campaign.get_step_text()
	clear_button.visible = is_instance_valid(campaign.destination)

func _process(_delta: float) -> void:
	if Manager.instance == null or Manager.instance.campaign == null or _marker == null:
		return
	var campaign := Manager.instance.campaign
	var has_destination := is_instance_valid(campaign.destination)
	_marker.track(campaign.destination if has_destination else null)
	destination_label.visible = has_destination
	visible = has_destination
	if not has_destination:
		clear_button.visible = false
		return
	var player := Manager.instance.player_instance
	if player != null:
		var distance := player.global_position.distance_to(campaign.destination.global_position)
		destination_label.text = tr("CAMPAIGN_DESTINATION_DISTANCE") % [campaign.destination_name, ceili(distance)]

func _exit_tree() -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()
