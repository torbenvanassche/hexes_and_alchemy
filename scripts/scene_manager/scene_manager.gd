extends Node

var scene_stack: Array[SceneInfo] = [];
var scene_cache: SceneCache;

@onready var root: Node3D = $"../game/scene_controller";
@onready var _ui_container: CanvasLayer = $"../game/game_ui";

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
	scene_cache = SceneCache.new()
	process_mode = Node.PROCESS_MODE_ALWAYS;
			
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
	if scene_stack.has(info):
		scene_stack.erase(info);
	if permanent:
		info.release();
	else:
		info.remove();
			
func remove_scene_by_name(scene_name: String, permanent: bool = false) -> void:
	remove_scene(DataManager.instance.get_scene_by_name(scene_name), permanent)
	
func to_previous_scene() -> void:
	if scene_stack.size() != 0:
		scene_stack.pop_back();
		if scene_stack.size() != 0:
			get_or_create_scene(scene_stack[scene_stack.size() - 1].id, SceneConfig.new(false));
			
func transition(scene_info: SceneInfo, immediate: bool = true) -> void:
	pass
	
func add(n: SceneInfo, allow_multiple: bool = false, is_visible: bool = true) -> Node:
	var instance_count := scene_stack.count(n);
	if instance_count >= 1 && not allow_multiple:
		return
	
	var instance := n.get_instance();
	if "visible" in instance:
		instance.visible = is_visible;
		
	if n.type == SceneInfo.Type.UI && not instance.get_parent() == _ui_container:
		_ui_container.add_child(instance);
		scene_stack.append(n)
		return instance;
	elif not instance.get_parent() == root:
		root.add_child(instance);
		scene_stack.append(n)
		return instance;
	else:
		Debug.err(n.id + " cannot be directly added to a scene.")
	return null;
