class_name NPC extends CharacterBody3D

@export var material: Material
@export var move_speed := 5.0
@export var arrive_distance := 0.1

enum NPCState { IDLE, READY_TO_MOVE, MOVING_TO_QUEST, AT_QUEST, RETURNING, DONE }

var current_path: Array[HexBase] = []
var current_target_index := 0
var state_machine: StateMachine
var current_quest: Quest
var npc_info: NpcInfo

signal arrived()

func _ready() -> void:
	$mesh/RootNode/unit.material_override = material
	npc_info = DataManager.instance.npcs.pick_random()
	visible = false

	var states: Array[String]
	for s in NPCState.keys():
		states.append(get_state_as_string(NPCState[s]))
	state_machine = StateMachine.new(states)
	add_child(state_machine)

	state_machine.bind_update(get_state_as_string(NPCState.MOVING_TO_QUEST), _update_moving_to_quest)
	state_machine.bind_update(get_state_as_string(NPCState.RETURNING), _update_returning)
	state_machine.state_entered.connect(_on_state_entered)
	set_state(NPCState.IDLE)

func _on_state_entered(state: String) -> void:
	if state == get_state_as_string(NPCState.MOVING_TO_QUEST):
		_begin_move_to_quest()
	elif state == get_state_as_string(NPCState.AT_QUEST):
		arrived.emit()
	elif state == get_state_as_string(NPCState.RETURNING):
		_begin_return_home()
	elif state == get_state_as_string(NPCState.DONE):
		_complete_quest()

func get_state_as_string(state: NPCState) -> String:
	return NPCState.keys()[state].to_lower()

func is_state(state: NPCState) -> bool:
	return get_state_as_string(state) == state_machine.get_current_state()

func set_state(state: NPCState) -> void:
	state_machine.set_state(get_state_as_string(state))

func assign_quest(q: Quest) -> void:
	current_quest = q
	set_state(NPCState.READY_TO_MOVE)

func _begin_move_to_quest() -> void:
	visible = true
	var active_scene := SceneManager.get_active_scene().node as HexGrid
	var start_hex := active_scene.get_hex_at_world_position(global_position)
	current_path = active_scene.pathfinder.get_hex_path(
		start_hex.cube_id, current_quest.location.cube_id
	)
	current_target_index = 1

func _begin_return_home() -> void:
	current_path.reverse()
	current_target_index = 0

func _complete_quest() -> void:
	current_quest = null
	current_path.clear()
	arrived.emit()
	queue_free()

func _update_moving_to_quest() -> void:
	_follow_path(func(): set_state(NPCState.AT_QUEST))

func _update_returning() -> void:
	_follow_path(func(): set_state(NPCState.DONE))

func _follow_path(on_arrived: Callable) -> void:
	if current_path.is_empty():
		return
	if current_target_index >= current_path.size():
		velocity = Vector3.ZERO
		move_and_slide()
		on_arrived.call()
		return
	var direction := current_path[current_target_index].global_position - global_position
	direction.y = 0
	if direction.length() < arrive_distance:
		current_target_index += 1
		return
	velocity = Vector3(direction.normalized().x, 0, direction.normalized().z) * move_speed
	move_and_slide()

func _physics_process(_delta: float) -> void:
	state_machine.update()
