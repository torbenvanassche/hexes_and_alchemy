@abstract class_name SettlementService extends Interaction

@export var additional_ui: Array[SceneInfo] = []

var additional_window_instances: Array[SceneInstance] = []

func get_settlement() -> Settlement:
	if settlement != null:
		return settlement
	if Manager.instance == null:
		return null
	return Manager.instance.get_settlement(self)

func has_settlement_service(type_name: StringName) -> bool:
	var owner_settlement: Settlement = get_settlement()
	return owner_settlement != null and owner_settlement.has_service(type_name)

func get_settlement_service(type_name: StringName) -> Interaction:
	var owner_settlement: Settlement = get_settlement()
	if owner_settlement == null:
		return null
	return owner_settlement.get_service(type_name)

func open_additional_ui_windows() -> void:
	for scene_info in additional_ui:
		if scene_info == null:
			continue
		scene_info.queue(_open_additional_ui_window)

func open_ui_window(window_info: SceneInfo, vis: bool = false) -> SceneInstance:
	var window_instance := SceneManager.add(window_info, vis)
	if window_instance == null:
		return null
	_setup_ui_window(window_instance)
	window_instance.on_enter.emit()
	return window_instance

func close_additional_ui_windows() -> void:
	for window_instance in additional_window_instances:
		if is_instance_valid(window_instance):
			window_instance.hide()

func _on_area_exit(other: Area3D) -> void:
	super(other)
	if close_window_on_area_exit:
		close_additional_ui_windows()

func _open_additional_ui_window(window_info: SceneInfo) -> void:
	var window_instance := open_ui_window(window_info, false)
	if window_instance != null and not additional_window_instances.has(window_instance):
		additional_window_instances.append(window_instance)

func _setup_ui_window(window_instance: SceneInstance) -> void:
	if window_instance == null:
		return
	var draggable_window := window_instance.node as DraggableControl
	if draggable_window == null:
		return
	var content := draggable_window.content
	if content != null and content.has_method("setup_interaction"):
		content.setup_interaction(self)
