class_name SceneInfo
extends Resource

enum Type {
	SCENE,
	TILE,
	UI,
	EVENT,
	STRUCTURE
}

@export var id: String;
@export var packed_scene: PackedScene;
@export var type: Type;

@export var is_unique: bool = false;
signal cached(scene_info: SceneInfo);

var is_cached: bool = false;
var is_queued: bool = false;
var instances: Array[SceneInstance] = [];

@export var destroy_on_player_leave: bool = false;

func initialize() -> void:
	id = resource_path.get_file().trim_suffix(".tres");
	if not is_unique:
		is_unique = type == Type.UI;
	
func get_instance() -> SceneInstance:
	instances = instances.filter(func(i: SceneInstance): return is_instance_valid(i.node))
	if is_unique and instances.size() > 0:
		return instances[0]
	var instance := SceneInstance.new(packed_scene.instantiate(), self);
	if destroy_on_player_leave:
		instance.on_player_leave.connect(destroy_instance.bind(instance))
	instances.append(instance)
	return instance
	
func destroy_instance(instance: SceneInstance) -> void:
	instance.node.queue_free();
	instances.erase(instance);
	
func has_instance(node: Node) -> bool:
	for instance in instances:
		if instance.node == node:
			return true;
	return false;

func release() -> void:
	for i in instances:
		if is_instance_valid(i.node):
			i.node.queue_free();
		if is_instance_valid(i):
			i.queue_free();
	instances.clear()
	SceneManager.instance.scene_cache.remove(self)
	is_cached = false
	
func remove() -> void:
	for i in instances:
		if i.node.get_parent():
			i.node.get_parent().remove_child(i.node)
	
func queue(c: Callable) -> void:
	if id == "":
		initialize();
	
	if is_cached:
		c.call(self);
	elif not cached.is_connected(c):
		cached.connect(c, CONNECT_ONE_SHOT);
			
	if not is_queued && not is_cached:
		SceneManager.get_or_create_scene(id);
