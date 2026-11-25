extends PanelContainer

@export var edge_hud_panels: Array[Control] = []

@onready var step_label: Label = $Margin/Content/Step
@onready var destination_label: Label = $Margin/Content/Destination
@onready var project_button: Button = $Margin/Content/Actions/Project
@onready var clear_button: Button = $Margin/Content/Actions/Clear
@onready var _edge_indicator: Control = $DestinationIndicator
@onready var _edge_arrow: Node2D = $DestinationIndicator/Arrow

const MARKER_SCENE := preload("res://scenes/hud/location_marker.tscn")
const EDGE_MARGIN := 16.0
const HUD_CLEARANCE := 8.0

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
	_update_destination_indicator()
	if not has_destination:
		clear_button.visible = false
		return
	var player := Manager.instance.player_instance
	if player != null:
		var distance := player.global_position.distance_to(campaign.destination.global_position)
		destination_label.text = tr("CAMPAIGN_DESTINATION_DISTANCE") % [campaign.destination_name, ceili(distance)]

func _update_destination_indicator() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not _marker.is_visible_in_tree():
		_edge_indicator.hide()
		return

	var viewport_rect := get_viewport_rect()
	if _marker.is_on_screen(camera, viewport_rect):
		_edge_indicator.hide()
		return

	var center := viewport_rect.get_center()
	var point := _marker.global_position
	var direction: Vector2
	if camera.is_position_behind(point):
		# Perspective projection reverses the direction for points behind the camera.
		var camera_point := camera.get_camera_transform().affine_inverse() * point
		direction = Vector2(camera_point.x, -camera_point.y)
		if direction.is_zero_approx():
			direction = Vector2.DOWN
	else:
		direction = camera.unproject_position(point) - center

	var indicator_half_size := _edge_indicator.size * 0.5
	var edge := viewport_rect.size * 0.5 - indicator_half_size - Vector2.ONE * EDGE_MARGIN
	if edge.x <= 0.0 or edge.y <= 0.0:
		_edge_indicator.hide()
		return

	var edge_scale := maxf(absf(direction.x) / edge.x, absf(direction.y) / edge.y)
	if is_zero_approx(edge_scale):
		_edge_indicator.hide()
		return
	var preferred := center + direction / edge_scale
	var safe_center := _find_edge_space(Rect2(center - edge, edge * 2.0), preferred, indicator_half_size)
	if not safe_center.is_finite():
		_edge_indicator.hide()
		return
	_edge_indicator.position = (safe_center - indicator_half_size).round()
	_edge_arrow.rotation = direction.angle()
	_edge_indicator.show()

func _find_edge_space(bounds: Rect2, preferred: Vector2, half_size: Vector2) -> Vector2:
	var panels := edge_hud_panels.duplicate()
	panels.append(self)
	var blocked: Array[Rect2] = []
	var padding := half_size + Vector2.ONE * HUD_CLEARANCE
	for panel: Control in panels:
		if not is_instance_valid(panel) or not panel.is_visible_in_tree():
			continue
		var rect := panel.get_global_rect()
		if rect.has_area():
			blocked.append(Rect2(rect.position - padding, rect.size + padding * 2.0))
	if not _is_blocked(preferred, blocked):
		return preferred

	# The nearest open point on an edge is either opposite the preferred point
	# or where a HUD panel's clearance ends.
	var candidates: Array[Vector2] = []
	for x: float in [bounds.position.x, bounds.end.x]:
		candidates.append(Vector2(x, preferred.y))
		for rect: Rect2 in blocked:
			candidates.append(Vector2(x, rect.position.y))
			candidates.append(Vector2(x, rect.end.y))
	for y: float in [bounds.position.y, bounds.end.y]:
		candidates.append(Vector2(preferred.x, y))
		for rect: Rect2 in blocked:
			candidates.append(Vector2(rect.position.x, y))
			candidates.append(Vector2(rect.end.x, y))

	var closest := Vector2(INF, INF)
	var closest_distance := INF
	for candidate: Vector2 in candidates:
		candidate = candidate.clamp(bounds.position, bounds.end)
		var distance := preferred.distance_squared_to(candidate)
		if distance < closest_distance and not _is_blocked(candidate, blocked):
			closest = candidate
			closest_distance = distance
	return closest

func _is_blocked(point: Vector2, blocked: Array[Rect2]) -> bool:
	for rect: Rect2 in blocked:
		# A point at the outer limit already has the requested clearance.
		if rect.grow(-0.01).has_point(point):
			return true
	return false

func _exit_tree() -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()
