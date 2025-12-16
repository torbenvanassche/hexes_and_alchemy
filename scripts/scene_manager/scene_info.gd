class_name SceneInfo
extends Resource

enum Type {
	SCENE,
	TILE,
	UI,
	EVENT
}

var id:String;

@export_group("Core")
@export var packed_scene: PackedScene;
@export var type: Type;
var node: Node;

@export_group("Spawner data")
@export var spawn_weight: float = 1;

signal cached(scene_info: SceneInfo);

var is_cached: bool = false;
var is_queued: bool = false;

func ready() -> void:
	id = resource_path.get_file().trim_suffix(".tres");

func release() -> void:
	SceneManager.instance.scene_cache.remove(self);
	is_cached = false;
	
func get_instance() -> Node:
	if not node:
		if is_cached:
			node = ResourceLoader.load_threaded_get(packed_scene.resource_path).instantiate();
		else:
			SceneManager.instance.get_or_create_scene(id)
	return node;
	
##Will execute the callable, this will cache the scene if it is unloaded.
func queue(c: Callable) -> void:
	if is_cached:
		c.call(self);
	elif not cached.is_connected(c):
		cached.connect(c, CONNECT_ONE_SHOT);
			
	if not is_queued && not is_cached:
		SceneManager.instance.get_or_create_scene(id);

func remove() -> void:
	node.get_parent().remove_child(node);
