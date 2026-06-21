extends Node

var scene_stack: Array[SceneInfo] = [];
var ui_stack: Array[SceneInfo] = [];
var scene_cache: SceneCache;
var _ui_z_counter := 0

@onready var root: Node3D = $"../game/scene_controller";
@onready var _ui_container: CanvasLayer = $"../game/game_ui";

signal scene_entered(scene: Node)
signal scene_exited(scene: Node)

var _active_scene: SceneInstance:
	set(new_scene):
		if _active_scene == new_scene:
			return;
		
		#tell the scene (internal) and the SceneManager that the scene is being left
		if _active_scene && _active_scene.node != null:
			scene_exited.emit(_active_scene.node);
			_active_scene.on_leave.emit();
			
		#set the newly provided scene to active
		_active_scene = new_scene;
			
		#trigger scene entered logic, again internal and scenemanager
		scene_entered.emit(_active_scene.node);
		
		#if its a hexgrid, wait for it to generate instead of calling directly
		if not _active_scene.node is HexGrid:
			_active_scene.on_enter.emit()
			return
		else:
			var grid := _active_scene.node as HexGrid
			if grid.initialized:
				_active_scene.on_enter.emit();
			else:
				grid.generated.connect(_active_scene.on_enter.emit)

func _init() -> void:
	scene_cache = SceneCache.new()
	process_mode = Node.PROCESS_MODE_ALWAYS;
	
func get_active_scene() -> SceneInstance:
	return _active_scene;
			
func get_or_create_scene(scene_name: String) -> SceneInfo:
	var previous_scene_info: SceneInfo = null;
	if _active_scene != null:
		previous_scene_info = DataManager.instance.node_to_info(_active_scene.node);
		if previous_scene_info != null and previous_scene_info.id == scene_name:
			return null; 
		_active_scene.set_processing(false)
	
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
	if info == null:
		return
	
	if info.is_unique:
		_active_scene = info.get_instance();
	else:
		Debug.message("Cannot set active scene to non-unique instanced SceneInfo.")
	
func _remove_from_stack(info: SceneInfo) -> void:
	if info.type == SceneInfo.Type.UI:
		_remove_from_ui_stack(info)
		return
	
	if scene_stack.is_empty():
		return
	
	if scene_stack[-1] == info:
		var popped_scene: SceneInfo = scene_stack.pop_back();
		if popped_scene.get_instance() == _active_scene and not scene_stack.is_empty():
			set_active_scene(scene_stack[-1])
			return
	
	if scene_stack.has(info):
		scene_stack.erase(info);

func _remove_from_ui_stack(info: SceneInfo) -> void:
	if ui_stack.is_empty():
		return
	
	if ui_stack[-1] == info:
		ui_stack.pop_back()
	elif ui_stack.has(info):
		ui_stack.erase(info)
		
func _pop_stack() -> SceneInfo:
	if scene_stack.size() != 0:
		var popped : SceneInfo = scene_stack[-1];
		_remove_from_stack(popped);
		return popped;
	return null;
	
func remove_scene(info: SceneInfo, permanent: bool = false) -> void:
	if info == null:
		return
	
	_remove_from_stack(info)
	if permanent:
		info.release();
	else:
		info.remove();
			
func remove_scene_by_name(scene_name: String, permanent: bool = false) -> void:
	remove_scene(DataManager.instance.get_scene_by_name(scene_name), permanent)

func remove_current_ui_scene(show_previous: bool = true) -> SceneInfo:
	var current_scene := get_current_ui_scene()
	if current_scene == null:
		return null
	
	remove_scene(current_scene)
	var previous_scene := get_current_ui_scene()
	if show_previous and previous_scene != null:
		set_visible(previous_scene)
	return previous_scene
	
func to_previous_scene() -> SceneInfo:
	if scene_stack.size() != 0:
		_pop_stack();
		if scene_stack.size() != 0:
			return scene_stack[-1]
	return null;
	
func get_current_scene() -> SceneInfo:
	if scene_stack.size() != 0:
		return scene_stack[-1];
	return null;

func get_current_ui_scene() -> SceneInfo:
	if ui_stack.size() != 0:
		return ui_stack[-1]
	return null

func set_visible_by_name(scene_name: String, state: bool = true) -> void:
	set_visible(DataManager.instance.get_scene_by_name(scene_name), state)
	
func set_visible(scene_info: SceneInfo, state: bool = true) -> void:
	if scene_info == null:
		return
	
	for instance in scene_info.get_live_instances():
		if "visible" in instance.node:
			instance.node.visible = state;
			if state and scene_info.type == SceneInfo.Type.UI and instance.node is Control:
				_promote_ui_control(instance.node as Control)
			
func is_in_tree(scene_instance: SceneInstance) -> bool:
	var node := scene_instance.node
	if not node.is_inside_tree():
		return false

	if scene_instance.scene_info.type == SceneInfo.Type.UI:
		return _ui_container.is_ancestor_of(node)
	return root.is_ancestor_of(node)

func is_visible(scene_instance: SceneInstance) -> bool:
	var node := scene_instance.node
	if not node.is_inside_tree():
		return false
		
	if "visible" in node:
		return node.is_visible_in_tree();
	return false;

func transition(scene_info: SceneInfo, activate_after_transition: bool = false) -> void:
	if scene_info == null:
		return
	
	if _active_scene != null and "visible" in _active_scene.node:
		_active_scene.set_processing(false)
		_active_scene.node.visible = false;
	add(scene_info);
	
	if activate_after_transition:
		set_active_scene(scene_info);
	
func add(n: SceneInfo, vis: bool = true) -> SceneInstance:
	if n == null:
		return null
	
	var stack := ui_stack if n.type == SceneInfo.Type.UI else scene_stack
	var instance_count := stack.count(n);
	if instance_count > 1 && n.is_unique:
		return null;
	
	var instance := n.get_instance();
	if "visible" in instance.node:
		instance.node.visible = vis;
		
	if n.is_unique && not n.transient:
		if stack.has(n):
			stack.erase(n)
		stack.append(n)
		
	if instance.node.is_inside_tree():
		if instance.node is Control:
			_promote_ui_control(instance.node as Control)
		return instance;
		
	if n.type == SceneInfo.Type.UI:
		_ui_container.add_child(instance.node);
		_promote_ui_control(instance.node as Control)
	elif not instance.node.get_parent() == root:
		root.add_child(instance.node);
	else:
		Debug.err(n.id + " cannot be directly added to a scene.")
	return instance;

func _promote_ui_control(control: Control) -> void:
	_ui_z_counter += 100
	control.z_as_relative = false
	control.z_index = _ui_z_counter
	control.move_to_front()
	
func is_on_stack(scene: SceneInfo) -> bool:
	if scene == null:
		return false
	if scene.type == SceneInfo.Type.UI:
		return ui_stack.has(scene)
	return scene_stack.has(scene);
	
func is_on_stack_by_name(scene_name: String) -> bool:
	return is_on_stack(DataManager.instance.get_scene_by_name(scene_name))
