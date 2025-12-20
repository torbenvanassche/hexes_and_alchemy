class_name SceneManager
extends Node

@export_group("Data Setup") 
static var instance: SceneManager;

var scene_stack: Array[SceneInfo] = [];
var scene_cache: SceneCache;

@export var root: Node;
@export var _ui_container: Node;

signal scene_entered(scene: Node)
signal scene_exited(scene: Node)

var _active_scene: Node:
	set(new_scene):
		if _active_scene != null:
			scene_exited.emit(_active_scene);
			if _active_scene.has_method("on_disable"):
				_active_scene.on_disable();
		_active_scene = new_scene;
		_active_scene.visible = true;
		scene_entered.emit(_active_scene);

func _init() -> void:
	SceneManager.instance = self;
	scene_cache = SceneCache.new()
			
func get_or_create_scene(scene_name: String, scene_config: SceneConfig = SceneConfig.new()) -> SceneInfo:
	var previous_scene_info: SceneInfo = null;
	if _active_scene != null:
		previous_scene_info = DataManager.instance.node_to_info(_active_scene);
		if previous_scene_info.id == scene_name:
			return null; 
		if scene_config.disable_processing:
			_active_scene.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	
	var scene_info: SceneInfo = DataManager.instance.get_scene_by_name(scene_name);
	if scene_info.is_cached:
		scene_info.cached.emit(scene_info);
		return scene_info;
	else:
		scene_cache.queue(scene_info);
	return scene_info;
		
func _check_loaded(to_load: Array[SceneInfo]) -> bool:
	return to_load.all(func(scene: SceneInfo) -> bool: return scene.is_cached)
	
func remove_scene(info: SceneInfo, permanent: bool = false) -> void:
	if info.instances.size() != 0:
		for i in info.instances:
			if scene_stack.has(i):
				scene_stack.erase(i);
		if permanent:
			info.release();
		else:
			info.remove();
	
func to_previous_scene() -> void:
	if scene_stack.size() != 0:
		scene_stack.pop_back();
		if scene_stack.size() != 0:
			get_or_create_scene(scene_stack[scene_stack.size() - 1].id, SceneConfig.new(false));
	
func add(n: SceneInfo) -> bool:
	if n.type == SceneInfo.Type.UI && not n.get_instance().get_parent() == _ui_container:
		_ui_container.add_child(n.get_instance());
		return true;
	elif n.type != SceneInfo.Type.SCENE && not n.get_instance().get_parent() == root:
		root.add_child(n.get_instance());
		return true;
	else:
		Debug.err(n.id + " cannot be directly added to a scene.")
	return false;
