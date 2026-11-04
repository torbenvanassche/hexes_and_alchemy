extends Obstacle

@export var is_gate := false

func register_with_grid(grid: HexGrid) -> void:
	if not is_gate: super(grid)

func _ready() -> void:
	super()
	# Match collision to the imported piece in local units, including import scales.
	var mesh := $Model.find_child("fence_wood_straight_gate" if is_gate else "fence_wood_straight", true, false) as MeshInstance3D
	if mesh == null: return
	var bounds: AABB = global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
	var body := StaticBody3D.new()
	add_child(body)
	if is_gate:
		var post_width := bounds.size.z * 0.16
		for side: float in [-1.0, 1.0]:
			var center := bounds.get_center()
			center.z += side * (bounds.size.z - post_width) * 0.5
			_add_box(body, center, Vector3(bounds.size.x, bounds.size.y, post_width))
	else:
		_add_box(body, bounds.get_center(), bounds.size)

func _add_box(body: StaticBody3D, center: Vector3, dimensions: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions.max(Vector3.ONE * 0.02)
	collision.shape = box
	collision.position = center
	body.add_child(collision)
