class_name Settlement extends Node3D

@export var spawn_position: Node3D;
@export var is_active_settlement: bool = false;

var collision_shapes: Array[CollisionShape3D];
var interactions: Array[Interaction];
var interactions_by_type: Dictionary[StringName, Array] = {};

@onready var settlement_outline: CSGPolygon3D = $settlement_outline

func _ready() -> void:
	collision_shapes.assign(find_children("*", "CollisionShape3D", true, false))
	Manager.instance.settlements.append(self)
	
	interactions.assign(find_children("*", "Interaction", true, false))
	_register_interactions()
	
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

func _register_interactions() -> void:
	interactions_by_type.clear()
	for interaction: Interaction in interactions:
		register_interaction(interaction)

func register_interaction(interaction: Interaction) -> void:
	if interaction == null:
		return
	interaction.settlement = self
	var type_name: StringName = _get_interaction_type(interaction)
	if not interactions_by_type.has(type_name):
		interactions_by_type[type_name] = []
	var services: Array = interactions_by_type[type_name]
	services.append(interaction)

func contains_interaction(interaction: Interaction) -> bool:
	return interaction != null and interactions.has(interaction)

func get_service(type_name: StringName) -> Interaction:
	var services: Array[Interaction] = get_services(type_name)
	return services[0] if not services.is_empty() else null

func get_services(type_name: StringName) -> Array[Interaction]:
	var services: Array[Interaction] = []
	if not interactions_by_type.has(type_name):
		return services
	var stored_services: Array = interactions_by_type[type_name]
	for service: Variant in stored_services:
		var interaction: Interaction = service as Interaction
		if interaction != null:
			services.append(interaction)
	return services

func has_service(type_name: StringName) -> bool:
	return not get_services(type_name).is_empty()

func _get_interaction_type(interaction: Interaction) -> StringName:
	var script: Script = interaction.get_script() as Script
	if script != null:
		var global_name: String = String(script.get_global_name())
		if not global_name.is_empty():
			return StringName(global_name)
	return StringName(interaction.name)
