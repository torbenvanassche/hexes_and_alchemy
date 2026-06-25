class_name PlayerController
extends CharacterBody3D

@onready var inventory: Inventory = $Inventory
@onready var interactor: Area3D = $interactor
@onready var movement: PlayerMovement = $Movement
@onready var interactor_component: PlayerInteractor = $Interactor

var return_position: Vector3
var currency: int

var selected_hex: HexBase:
	get:
		return interactor_component.selected_hex if interactor_component != null else null
	set(value):
		if interactor_component != null:
			interactor_component.selected_hex = value

var current_triggers: Array[Interaction]:
	get:
		if interactor_component != null:
			return interactor_component.current_triggers
		
		var empty: Array[Interaction] = []
		return empty

signal hex_picked(hex: HexBase)

func _ready() -> void:
	interactor_component.hex_picked.connect(_on_hex_picked)

func _physics_process(delta: float) -> void:
	movement.physics_process(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("primary_action"):
		if not interactor_component.interact():
			pick_hex_from_mouse()

func pick_hex_from_mouse() -> HexBase:
	return interactor_component.pick_hex_from_mouse()

func add_trigger(other: Area3D) -> void:
	interactor_component.add_trigger(other)

func remove_trigger(other: Area3D) -> void:
	interactor_component.remove_trigger(other)

func get_hex() -> HexBase:
	return movement.get_hex()

func toggle_inventory() -> void:
	var inventory_window := DataManager.instance.get_scene_by_name("inventory_ui")
	for instance in inventory_window.get_live_instances():
		if SceneManager.is_visible(instance):
			(instance.node as DraggableControl).close_requested.emit()
			return
	inventory_window.queue(_open_inventory)

func _open_inventory(window_info: SceneInfo) -> void:
	var window_instance := SceneManager.add(window_info, false)
	var inventory_ui: InventoryUI = (window_instance.node as DraggableControl).content as InventoryUI
	inventory_ui.inventory = inventory
	window_instance.on_enter.emit()

func set_return_position() -> void:
	return_position = global_position

func return_to_cached_position() -> void:
	global_position = return_position
	Manager.instance.spring_arm_camera.snap_to_target()

func _on_hex_picked(hex: HexBase) -> void:
	hex_picked.emit(hex)
