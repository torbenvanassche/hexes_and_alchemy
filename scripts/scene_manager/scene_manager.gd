extends Node

var scene_stack: Array[SceneInfo] = [];
var scene_cache: SceneCache;

var grid_storage: Dictionary[String, HexGrid];
var hex_grid: HexGrid;

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
	
func add_hex_grid(hex_name: String, grid: HexGrid) -> void:
	grid_storage[hex_name] = grid;
	
func set_active_grid(hex_name: String) -> void:
	hex_grid = grid_storage[hex_name];
	
func remove_hex_grid(hex_name: String) -> void:
	grid_storage.erase(hex_name)
			
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
	
func set_active_scene(info: SceneInfo) -> void:
	if info.is_unique:
		_active_scene = info.get_instance();
		_active_scene.process_mode = Node.PROCESS_MODE_PAUSABLE;
	else:
		Debug.message("Cannot set active scene to non-unique instanced SceneInfo.")
	
func _remove_from_stack(info: SceneInfo) -> void:
	if scene_stack.has(info):
		scene_stack.erase(info);
		
func _pop_stack() -> SceneInfo:
	if scene_stack.size() != 0:
		var popped : SceneInfo = scene_stack[-1];
		_remove_from_stack(popped);
		return popped;
	return null;
	
func remove_scene(info: SceneInfo, permanent: bool = false) -> void:
	_remove_from_stack(info)
	if permanent:
		info.release();
	else:
		info.remove();
			
func remove_scene_by_name(scene_name: String, permanent: bool = false) -> void:
	remove_scene(DataManager.instance.get_scene_by_name(scene_name), permanent)
	
func to_previous_scene() -> SceneInfo:
	if scene_stack.size() != 0:
		_pop_stack();
		if scene_stack.size() != 0:
			return get_or_create_scene(scene_stack[scene_stack.size() - 1].id, SceneConfig.new(false));
	return null;
	
func get_current_scene() -> SceneInfo:
	if scene_stack.size() != 0:
		return scene_stack[-1];
	return null;

func set_visible_by_name(scene_name: String, state: bool = true) -> void:
	set_visible(DataManager.instance.get_scene_by_name(scene_name), state)
	
func set_visible(scene_info: SceneInfo, state: bool = true) -> void:
	for instance in scene_info.instances:
		if "visible" in instance:
			instance.visible = state;

func transition(scene_info: SceneInfo) -> void:
	if "visible" in _active_scene:
		_active_scene.process_mode = Node.PROCESS_MODE_DISABLED;
		_active_scene.visible = false;
	add(scene_info);
	set_active_scene(scene_info);
	
	if scene_info.is_unique && scene_info.get_instance() is HexGrid:
		set_active_grid((scene_info.get_instance() as HexGrid).grid_name)
	
func add(n: SceneInfo, allow_multiple: bool = false, is_visible: bool = true, add_to_stack: bool = true) -> Node:
	var instance_count := scene_stack.count(n);
	if instance_count >= 1 && not allow_multiple:
		return
	
	var instance := n.get_instance();
	if "visible" in instance:
		instance.visible = is_visible;
		
	if add_to_stack:
		scene_stack.append(n)
		
	if instance.is_inside_tree():
		return;
		
	if n.type == SceneInfo.Type.UI:
		_ui_container.add_child(instance);
		return instance;
	elif not instance.get_parent() == root:
		root.add_child(instance);
		return instance;
	else:
		Debug.err(n.id + " cannot be directly added to a scene.")
	return null;
