class_name ScoutRoutePreview extends Control

var _route := PackedVector2Array()

func _ready() -> void:
	resized.connect(queue_redraw)

func set_route(points: PackedVector2Array) -> void:
	_route = points
	queue_redraw()

func _draw() -> void:
	if _route.is_empty():
		return
	var bounds := Rect2(_route[0], Vector2.ZERO)
	for point: Vector2 in _route:
		bounds = bounds.expand(point)
	var available := (size - Vector2(36.0, 36.0)).max(Vector2.ONE)
	var extent := bounds.size.max(Vector2.ONE)
	var scale_factor := minf(available.x / extent.x, available.y / extent.y)
	var screen_points := PackedVector2Array()
	for point: Vector2 in _route:
		screen_points.append(size * 0.5 + (point - bounds.get_center()) * scale_factor)
	if screen_points.size() > 1:
		draw_polyline(screen_points, GameUI.ACCENT, 2.0, true)
		draw_circle(screen_points[0], 5.0, GameUI.MUTED, true, -1.0, true)
		for index in range(1, screen_points.size() - 1):
			draw_circle(screen_points[index], 3.0, GameUI.MUTED, true, -1.0, true)
	var target := screen_points[-1]
	var border := PackedVector2Array()
	for step in 7:
		border.append(target + Vector2.from_angle(TAU * float(step) / 6.0) * 12.0)
	draw_colored_polygon(border.slice(0, 6), Color(0.12, 0.14, 0.13))
	draw_polyline(border, GameUI.ACCENT, 2.0, true)
	draw_circle(target, 3.0, GameUI.ACCENT, true, -1.0, true)
