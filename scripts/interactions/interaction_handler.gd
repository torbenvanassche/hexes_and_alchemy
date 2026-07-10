@abstract class_name Interaction extends Node3D

var hex: HexBase;
var settlement: Settlement;

var enterable_triggers: Array[Area3D] = []
var colliders: Array[StaticBody3D] = []
var collision_shapes: Array[CollisionShape3D] = []
var window_instance: SceneInstance;

@export var show_interaction_prompt: bool = true;
@export var close_window_on_area_exit: bool = true
@export var journal_quest: JournalTask;

@abstract func interact() -> void;
@abstract func can_interact() -> bool;

func _ready() -> void:
	enterable_triggers.assign(find_children("*", "Area3D", true, false))
	colliders.assign(find_children("*", "StaticBody3D", true, false))
	collision_shapes.assign(find_children("*", "CollisionShape3D", true, false))
	
	for trigger: Area3D in enterable_triggers:
		trigger.set_meta("target", self)
		trigger.area_entered.connect(_on_area_enter)
		trigger.area_exited.connect(_on_area_exit);
		
	visibility_changed.connect(_on_visibility_changed)
	
func toggle_collision(b: bool) -> void:
	for col in collision_shapes:
		if col.get_parent() is StaticBody3D:
			col.disabled = b;
	
func on_interact() -> void:
	if can_interact():
		interact();

func _on_visibility_changed() -> void:
	for shape in collision_shapes:
		shape.disabled = not is_visible_in_tree();

func _on_area_exit(other: Area3D) -> void:
	var player := other.get_parent() as PlayerController
	if player != null and player.interactor_component != null:
		_close_window_on_area_exit()
		player.interactor_component._refresh_interaction_prompt()

func _close_window_on_area_exit() -> void:
	if close_window_on_area_exit and window_instance != null:
		window_instance.hide()
		
func _on_area_enter(other: Area3D) -> void:
	var player := other.get_parent() as PlayerController
	if player != null and player.interactor_component != null:
		player.interactor_component._refresh_interaction_prompt()
