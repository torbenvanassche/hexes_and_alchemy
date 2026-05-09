class_name NPC extends CharacterBody3D

@export var material: Material
@export var move_speed := 5.0
@export var arrive_distance := 0.1

var current_path: Array[HexBase] = []
var current_target_index := 0

var current_quest: Quest;
var npc_info: NpcInfo;
var on_location: bool = false;

signal arrived_at_quest();

func _ready() -> void:
	$mesh/RootNode/unit.material_override = material
	npc_info = DataManager.instance.npcs.pick_random();
	visible = false;
	
func assign_quest() -> void:
	current_quest = Config.gamestate.assign_quest(self);
	on_location = false;

func move_to_quest() -> void:
	visible = true;
	var active_scene := SceneManager.get_active_scene().node as HexGrid
	var start_hex := active_scene.get_hex_at_world_position(global_position)
	current_path = active_scene.pathfinder.get_hex_path(start_hex.cube_id, current_quest.location.cube_id)
	current_path.remove_at(0);
	current_target_index = 0

func _physics_process(_delta: float) -> void:
	if current_path.is_empty():
		return

	if current_target_index >= current_path.size():
		velocity = Vector3.ZERO
		on_location = true;
		arrived_at_quest.emit();
		current_path.clear();
		move_and_slide()
		return

	var target_hex := current_path[current_target_index]
	var target_position: Vector3 = target_hex.global_position
	var direction := target_position - global_position
	direction.y = 0

	if direction.length() < arrive_distance:
		current_target_index += 1
		return

	direction = direction.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	move_and_slide()
