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
	
	inventory.add(DataManager.instance.get_item_by_name("wood_log"), 5)
	inventory.add(DataManager.instance.get_item_by_name("ore_iron"), 3)

func _physics_process(delta: float) -> void:
	movement.physics_process(delta)

func _unhandled_input(_event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() != null:
		return
	
	if Input.is_action_just_pressed("primary_action"):
		if not interactor_component.interact():
			pick_hex_from_mouse()
	
	if Input.is_action_just_pressed("inventory"):
		toggle_inventory()

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
