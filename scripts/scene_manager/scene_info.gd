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
var instances: Array[Node] = [];

func initialize() -> void:
	id = resource_path.get_file().trim_suffix(".tres");
	if not is_unique:
		is_unique = type == Type.UI;
	
func get_instance() -> Node:
	instances = instances.filter(func(i): return is_instance_valid(i))
	if is_unique and instances.size() > 0:
		return instances[0]
	var instance := packed_scene.instantiate()
	instances.append(instance)
	return instance

func release() -> void:
	for i in instances:
		if is_instance_valid(i):
			i.queue_free()
	instances.clear()
	SceneManager.instance.scene_cache.remove(self)
	is_cached = false
	
func remove() -> void:
	for i in instances:
		if i.get_parent():
			i.get_parent().remove_child(i)
	
func queue(c: Callable) -> void:
	if id == "":
		initialize();
	
	if is_cached:
		c.call(self);
	elif not cached.is_connected(c):
		cached.connect(c, CONNECT_ONE_SHOT);
			
	if not is_queued && not is_cached:
		SceneManager.get_or_create_scene(id);
