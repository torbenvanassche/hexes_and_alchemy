class_name StructureInstance extends RefCounted

var structure_info: StructureInfo;
var instance: Node3D;

var enterable_triggers: Array[Area3D];
var colliders: Array[StaticBody3D];
var collision_shapes: Array[CollisionShape3D]

var script_handler: Node;

func _init(s: StructureInfo, node: Node) -> void:	
	structure_info = s;
	instance = node;
	
	if structure_info.interaction_script:
		script_handler = Node.new();
		script_handler.set_script(structure_info.interaction_script);
		instance.add_child(script_handler)
	
	enterable_triggers.assign(instance.find_children("*", "Area3D", true, false))
	colliders.assign(instance.find_children("*", "StaticBody3D", true, false))
	collision_shapes.assign(instance.find_children("*", "CollisionShape3D", true, false))
	
	instance.visibility_changed.connect(_on_visibility_changed)
	
	for trigger: Area3D in enterable_triggers:
		trigger.set_meta("target", self)
		trigger.area_entered.connect(_on_area_enter)
		trigger.area_exited.connect(_on_area_exit);
		
func _on_visibility_changed() -> void:
	for shape in collision_shapes:
		shape.disabled = not instance.is_visible_in_tree();

func _on_area_exit(other: Area3D) -> void:
	if other.get_parent() is PlayerController:
		Manager.instance.interaction_prompt.show_rect(null)
		
func _on_area_enter(other: Area3D) -> void:
	if other.get_parent() is PlayerController:
		Manager.instance.interaction_prompt.show_rect(instance);
		
func on_interact() -> void:
	if script_handler && script_handler.has_method("interact"):
		script_handler.interact();
	else:
		Debug.message("No interact method found on interaction handler.")
