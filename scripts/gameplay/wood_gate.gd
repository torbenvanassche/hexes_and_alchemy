extends "res://scripts/gameplay/rotator.gd"

func _ready() -> void:
	# Use the same rotating interaction as the stone gate, with a collider fitted
	# to the wooden door. Children inherit its imported scale and hinge rotation.
	var bounds: AABB = call("get_aabb")
	var body := StaticBody3D.new()
	body.name = "DoorBody"
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bounds.size.max(Vector3.ONE * 0.0002)
	collision.shape = box
	collision.position = bounds.get_center()
	body.add_child(collision)
	add_child(body)
	var trigger := Area3D.new()
	trigger.name = "InteractionArea"
	var trigger_shape := CollisionShape3D.new()
	var trigger_box := BoxShape3D.new()
	trigger_box.size = bounds.size + Vector3.ONE * 0.012
	trigger_shape.shape = trigger_box
	trigger_shape.position = bounds.get_center()
	trigger.add_child(trigger_shape)
	add_child(trigger)
	prompt_anchor = Marker3D.new()
	prompt_anchor.position = bounds.get_center()
	add_child(prompt_anchor)
	super()
	# The settlement stores this separately because it rebuilds boundary pieces.
	var village := _get_village()
	if village != null and village.gate_open:
		at_max = true
		_set_axis_rotation(deg_to_rad(max_angle))

func can_interact() -> bool:
	return is_visible_in_tree() and not SaveGames.is_loading

func interact() -> void:
	super()
	var village := _get_village()
	if village != null: village.gate_open = at_max

func open_for_traveller() -> bool:
	if not at_max:
		if not can_interact(): return false
		interact()
	return tween == null or not tween.is_running()

func _get_village() -> Settlement:
	var parent := get_parent()
	while parent != null:
		if parent.has_method("rebuild_boundary"): return parent as Settlement
		parent = parent.get_parent()
	return null
