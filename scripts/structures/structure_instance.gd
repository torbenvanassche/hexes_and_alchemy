class_name StructureInstance extends SceneInstance

var structure_info: StructureInfo;
var instance: Interaction;

var enterable_triggers: Array[Area3D];
var colliders: Array[StaticBody3D];
var collision_shapes: Array[CollisionShape3D];
var meshes: Array[MeshInstance3D]

func _init(_n: Node, s: SceneInfo) -> void:
	if not _n is Interaction:
		Debug.err("%s is not of type interaction, please assign a handler!" % [s.id])
		return;
	
	structure_info = s;
	instance = _n;
	instance.structure_instance = self;
	
	enterable_triggers.assign(instance.find_children("*", "Area3D", true, false))
	colliders.assign(instance.find_children("*", "StaticBody3D", true, false))
	collision_shapes.assign(instance.find_children("*", "CollisionShape3D", true, false))
	meshes.assign(instance.find_children("*", "MeshInstance3D", true, false))
	
	instance.visibility_changed.connect(_on_visibility_changed)
	
	for trigger: Area3D in enterable_triggers:
		trigger.set_meta("target", self)
		trigger.area_entered.connect(_on_area_enter)
		trigger.area_exited.connect(_on_area_exit);
	instance.setup();
		
func _on_visibility_changed() -> void:
	for shape in collision_shapes:
		shape.disabled = not instance.is_visible_in_tree();

func _on_area_exit(other: Area3D) -> void:
	if other.get_parent() is PlayerController:
		Manager.instance.interaction_prompt.show_rect(null)
		
func _on_area_enter(other: Area3D) -> void:
	if other.get_parent() is PlayerController:
		Manager.instance.interaction_prompt.show_rect(instance);
		
func destroy() -> void:
	queue_free()
	super();
		
func on_interact() -> void:
	if instance.has_method("interact"):
		instance.interact();
	else:
		Debug.message("No interact method found on interaction handler.")
