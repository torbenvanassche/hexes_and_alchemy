class_name Settlement extends Node3D

@export var spawn_position: Node3D;
@export var is_active_settlement: bool = false;

var collision_shapes: Array[CollisionShape3D];

@onready var settlement_outline: CSGPolygon3D = $settlement_outline

func _ready() -> void:
	collision_shapes.assign(find_children("*", "CollisionShape3D", true, false))
	
	if is_active_settlement:
		Manager.instance.set_active_settlement(self);
	Manager.instance.spawn_in_settlement();
	visibility_changed.connect(_toggle_collision)
	_ready_deferred.call_deferred();
	
func _ready_deferred() -> void:
	var candidates := (SceneManager.get_active_scene().node as HexGrid).tiles;
	for hex in candidates:
		var pos := Vector2(candidates[hex].node.global_position.x, candidates[hex].node.global_position.z);
		if Geometry2D.is_point_in_polygon(pos, GridUtils.get_world_polygon(settlement_outline)):
			candidates[hex].node.is_explored = true;
	
func _toggle_collision() -> void:
	for collision in collision_shapes:
		collision.disabled = not self.is_visible_in_tree();
