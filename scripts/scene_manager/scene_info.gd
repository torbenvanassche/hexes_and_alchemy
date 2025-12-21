class_name SceneInfo
extends Resource

enum Type {
	SCENE,
	TILE,
	UI,
	EVENT,
	STRUCTURE
}

var id:String;

@export var is_walkable: bool = true;
@export var has_collision: bool = false;

@export_group("Core")
@export var packed_scene: PackedScene;
@export var type: Type;

signal cached(scene_info: SceneInfo);

var is_cached: bool = false;
var is_queued: bool = false;
var instances: Array[Node];

func initialize() -> void:
	id = resource_path.get_file().trim_suffix(".tres");
	
func get_instance() -> Node:
	var ps := packed_scene.instantiate();
	instances.append(ps);
	if ps is HexBase:
		ps.scene_info = self;
	return ps;

func release() -> void:
	for i in instances:
		i.queue_free()
	SceneManager.instance.scene_cache.remove(self);
	is_cached = false;
	
func remove() -> void:
	for i in instances:
		i.get_parent().remove_child(i)
	
func queue(c: Callable) -> void:
	if is_cached:
		c.call(self);
	elif not cached.is_connected(c):
		cached.connect(c, CONNECT_ONE_SHOT);
			
	if not is_queued && not is_cached:
		SceneManager.instance.get_or_create_scene(id);
