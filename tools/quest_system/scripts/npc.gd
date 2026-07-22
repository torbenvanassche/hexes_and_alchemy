class_name NPC extends CharacterBody3D

@export var material: Material
@export var move_speed := 5.0
@export var arrive_distance := 0.1
@export var stuck_repath_seconds := 1.5
@export var stuck_distance_epsilon := 0.05

@export_group("Rank")
@export var rank: AdventurerRank.Rank = AdventurerRank.Rank.F
@export var rank_experience: int = 0

@export_group("Scouting")
@export_range(0, 8, 1) var scouting_exploration_radius := 2

@export_group("Equipment")
@export var equipment: NpcEquipmentSlots

@onready var interaction_trigger: Area3D = get_node_or_null("InteractionTrigger") as Area3D

enum NPCState { IDLE, READY_TO_MOVE, MOVING_TO_QUEST, AT_QUEST, RETURNING, DONE }

var current_path: Array[HexBase] = []
var current_target_index := 0
var state_machine: StateMachine
var current_quest: Quest
var npc_info: NpcInfo
var home_position := Vector3.ZERO
var _last_progress_position := Vector3.ZERO
var _stuck_time := 0.0

signal arrived()
signal movement_failed(npc: NPC)
signal rank_progress_changed()

func _ready() -> void:
	$mesh/RootNode/unit.material_override = material
	if interaction_trigger != null and not interaction_trigger.area_entered.is_connected(_on_interaction_trigger_area_entered):
		interaction_trigger.area_entered.connect(_on_interaction_trigger_area_entered)
	if npc_info == null:
		npc_info = DataManager.instance.npcs.pick_random()
	if npc_info != null:
		rank = npc_info.starting_rank
	_initialize_equipment()
	_rank_up_from_experience()
	home_position = global_position
	visible = false

	var states: Array[String] = []
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

func _on_interaction_trigger_area_entered(other: Area3D) -> void:
	if current_quest == null or not (is_state(NPCState.MOVING_TO_QUEST) or is_state(NPCState.RETURNING)):
		return

	var target: Interaction = null
	if other.has_meta("target"):
		target = other.get_meta("target") as Interaction
	if target == null or not target.can_be_triggered_by_npc:
		return

	target.on_npc_triggered(self)

func assign_quest(q: Quest) -> void:
	home_position = global_position
	current_quest = q
	set_state(NPCState.READY_TO_MOVE)

func cancel_assigned_quest(quest: Quest) -> void:
	if current_quest != quest:
		return
	current_quest = null
	current_path.clear()
	velocity = Vector3.ZERO
	visible = false
	set_state(NPCState.IDLE)

func get_rank() -> AdventurerRank.Rank:
	return rank

func get_rank_label() -> String:
	return AdventurerRank.get_display_name(rank)

func set_rank(value: AdventurerRank.Rank) -> void:
	var new_rank := AdventurerRank.clamp_rank(value)
	if rank == new_rank:
		return
	rank = new_rank
	rank_progress_changed.emit()

func promote_rank() -> void:
	set_rank(AdventurerRank.get_next(rank))

func is_rank_at_least(minimum: AdventurerRank.Rank) -> bool:
	return AdventurerRank.is_at_least(rank, minimum)

func get_effective_move_speed() -> float:
	return move_speed * AdventurerRank.get_speed_multiplier(rank, _get_rank_move_speed_bonus_per_tier())

func get_equipped_items() -> Array[EquipmentInfo]:
	if equipment == null:
		return []
	return equipment.get_equipped_items()

func evaluate_quest(quest: Quest) -> float:
	if not can_consider_quest(quest):
		return 0.0

	var minimum_rank := quest.get_minimum_rank()
	var score := _get_base_eligible_quest_score()
	score += float(quest.get_rank_experience_reward()) * _get_rank_experience_reward_weight()
	score += float(quest.get_offered_currency_reward()) * _get_offered_currency_reward_weight()
	score += maxf(0.0, float(int(rank) - int(minimum_rank))) * _get_rank_surplus_weight()
	score -= _get_distance_to_quest(quest) * _get_distance_penalty_per_tile()
	return maxf(0.0, score)

func can_consider_quest(quest: Quest) -> bool:
	if quest == null:
		return false
	if current_quest != null:
		return false
	if not quest.is_state(Quest.QuestState.WAITING) or not quest.party.is_empty():
		return false
	return is_rank_at_least(quest.get_minimum_rank())

func wants_quest(quest: Quest) -> bool:
	return evaluate_quest(quest) >= _get_minimum_quest_score()

func add_rank_experience(amount: int) -> void:
	if amount <= 0:
		return
	rank_experience += amount
	if _rank_up_from_experience():
		return
	rank_progress_changed.emit()

func complete_assigned_quest(quest: Quest, rank_experience_reward: int) -> void:
	if current_quest != quest:
		return
	add_rank_experience(rank_experience_reward)
	current_quest = null
	current_path.clear()
	set_state(NPCState.IDLE)

func get_rank_progress_label() -> String:
	if int(rank) >= int(AdventurerRank.get_max_rank()):
		return tr("ADVENTURER_RANK_PROGRESS_MAX") % [get_rank_label()]
	return tr("ADVENTURER_RANK_PROGRESS") % [
		get_rank_label(),
		rank_experience,
		_get_rank_threshold(AdventurerRank.get_next(rank)),
	]

func _begin_move_to_quest() -> void:
	visible = true
	var active_scene := SceneManager.get_active_scene()
	var grid: HexGrid = null
	if active_scene != null:
		grid = active_scene.node as HexGrid
	var start_hex := grid.get_hex_at_world_position(global_position) if grid != null else null
	current_path = _get_path_to_quest(grid, start_hex)
	current_target_index = 1
	_reset_stuck_tracking()
	if current_path.is_empty():
		_fail_current_movement()

func _begin_return_home() -> void:
	var active_scene := SceneManager.get_active_scene()
	var grid: HexGrid = null
	if active_scene != null:
		grid = active_scene.node as HexGrid
	var start_hex := grid.get_hex_at_world_position(global_position) if grid != null else null
	var home_hex := grid.get_hex_at_world_position(home_position) if grid != null else null
	current_path = _get_path_to_home(grid, start_hex, home_hex)
	current_target_index = 1
	_reset_stuck_tracking()
	if current_path.is_empty():
		_finish_return_at_home()

func _complete_quest() -> void:
	visible = false
	current_path.clear()
	arrived.emit()

func _update_moving_to_quest() -> void:
	_follow_path(func(): set_state(NPCState.AT_QUEST))

func _update_returning() -> void:
	_follow_path(func(): set_state(NPCState.DONE))

func _follow_path(on_arrived: Callable) -> void:
	if current_path.is_empty():
		_handle_empty_path()
		return
	_explore_for_scouting_quest()
	if current_target_index >= current_path.size():
		velocity = Vector3.ZERO
		move_and_slide()
		on_arrived.call()
		return
	var direction := current_path[current_target_index].global_position - global_position
	direction.y = 0
	if direction.length() < arrive_distance:
		current_target_index += 1
		_reset_stuck_tracking()
		return
	velocity = Vector3(direction.normalized().x, 0, direction.normalized().z) * get_effective_move_speed()
	move_and_slide()
	_update_stuck_tracking()

func _physics_process(_delta: float) -> void:
	state_machine.update()

func _rank_up_from_experience() -> bool:
	var promoted := false
	while int(rank) < int(AdventurerRank.get_max_rank()):
		var next_rank := AdventurerRank.get_next(rank)
		var required_experience := _get_rank_threshold(next_rank)
		if required_experience <= 0 or rank_experience < required_experience:
			break
		rank = next_rank
		promoted = true
	if promoted:
		rank_progress_changed.emit()
	return promoted

func _initialize_equipment() -> void:
	if equipment != null:
		equipment = equipment.duplicate(true) as NpcEquipmentSlots
		return
	if npc_info != null and npc_info.default_equipment != null:
		equipment = npc_info.default_equipment.duplicate(true) as NpcEquipmentSlots
		return
	equipment = NpcEquipmentSlots.new()

func _get_rank_threshold(target_rank: AdventurerRank.Rank) -> int:
	if npc_info == null or npc_info.rank_experience_thresholds == null:
		return _get_fallback_rank_threshold(target_rank)
	return maxi(0, roundi(npc_info.rank_experience_thresholds.sample(float(int(target_rank)))))

func _get_rank_move_speed_bonus_per_tier() -> float:
	if npc_info == null:
		return 0.0
	return npc_info.rank_move_speed_bonus_per_tier

func _get_fallback_rank_threshold(target_rank: AdventurerRank.Rank) -> int:
	var rank_index := int(target_rank)
	return rank_index * rank_index

func _get_minimum_quest_score() -> float:
	if npc_info == null:
		return 1.0
	return npc_info.minimum_quest_score

func _get_base_eligible_quest_score() -> float:
	if npc_info == null:
		return 10.0
	return npc_info.base_eligible_quest_score

func _get_rank_experience_reward_weight() -> float:
	if npc_info == null:
		return 2.0
	return npc_info.rank_experience_reward_weight

func _get_offered_currency_reward_weight() -> float:
	if npc_info == null:
		return 0.1
	return npc_info.offered_currency_reward_weight

func _get_rank_surplus_weight() -> float:
	if npc_info == null:
		return 0.5
	return npc_info.rank_surplus_weight

func _get_distance_penalty_per_tile() -> float:
	if npc_info == null:
		return 0.05
	return npc_info.distance_penalty_per_tile

func _get_distance_to_quest(quest: Quest) -> float:
	if quest == null or quest.location == null:
		return 0.0
	var active_scene := SceneManager.get_active_scene()
	if active_scene == null:
		return 0.0
	var grid := active_scene.node as HexGrid
	if grid == null:
		return 0.0
	var start_hex := grid.get_hex_at_world_position(global_position)
	if start_hex == null:
		return 0.0
	return float(GridUtils.cube_distance(start_hex.cube_id, quest.location.cube_id))

func _get_path_to_quest(grid: HexGrid, start_hex: HexBase) -> Array[HexBase]:
	if grid == null or start_hex == null or current_quest == null or current_quest.location == null:
		return []
	if _can_use_boats_from_active_settlement():
		return grid.pathfinder.get_hex_path_for_methods(
			start_hex.cube_id,
			current_quest.location.cube_id,
			[HexInfo.TraversalTag.WALK, HexInfo.TraversalTag.BOAT]
		)
	return grid.pathfinder.get_hex_path(start_hex.cube_id, current_quest.location.cube_id)

func _get_path_to_home(grid: HexGrid, start_hex: HexBase, home_hex: HexBase) -> Array[HexBase]:
	if grid == null or start_hex == null or home_hex == null:
		return []
	if _can_use_boats_from_active_settlement():
		return grid.pathfinder.get_hex_path_for_methods(
			start_hex.cube_id,
			home_hex.cube_id,
			[HexInfo.TraversalTag.WALK, HexInfo.TraversalTag.BOAT]
		)
	return grid.pathfinder.get_hex_path(start_hex.cube_id, home_hex.cube_id)

func _handle_empty_path() -> void:
	if is_state(NPCState.RETURNING):
		_finish_return_at_home()
		return
	_fail_current_movement()

func _fail_current_movement() -> void:
	velocity = Vector3.ZERO
	current_path.clear()
	movement_failed.emit(self)

func _finish_return_at_home() -> void:
	global_position = home_position
	current_path.clear()
	velocity = Vector3.ZERO
	set_state(NPCState.DONE)

func _reset_stuck_tracking() -> void:
	_last_progress_position = global_position
	_stuck_time = 0.0

func _update_stuck_tracking() -> void:
	var flat_position := Vector2(global_position.x, global_position.z)
	var flat_last_position := Vector2(_last_progress_position.x, _last_progress_position.z)
	if flat_position.distance_to(flat_last_position) > stuck_distance_epsilon:
		_reset_stuck_tracking()
		return

	_stuck_time += get_physics_process_delta_time()
	if _stuck_time < stuck_repath_seconds:
		return

	if not _try_repath_current_movement():
		_handle_empty_path()
		return
	_reset_stuck_tracking()

func _try_repath_current_movement() -> bool:
	var active_scene := SceneManager.get_active_scene()
	if active_scene == null:
		return false
	var grid := active_scene.node as HexGrid
	if grid == null:
		return false

	var start_hex := grid.get_hex_at_world_position(global_position)
	if is_state(NPCState.RETURNING):
		var home_hex := grid.get_hex_at_world_position(home_position)
		current_path = _get_path_to_home(grid, start_hex, home_hex)
	else:
		current_path = _get_path_to_quest(grid, start_hex)
	current_target_index = 1
	return not current_path.is_empty()

func _can_use_boats_from_active_settlement() -> bool:
	return (
		Manager.instance != null
		and Manager.instance.active_settlement != null
		and Manager.instance.active_settlement.has_service(&"Shipyard")
	)

func _explore_for_scouting_quest() -> void:
	if current_quest == null or current_quest.quest_key != "scout":
		return
	var active_scene := SceneManager.get_active_scene()
	if active_scene == null:
		return
	var grid := active_scene.node as HexGrid
	if grid == null:
		return
	var current_hex := grid.get_hex_at_world_position(global_position)
	if current_hex == null:
		return
	grid.generate_chunks_around_grid_id(current_hex.grid_id)
	for nearby_tile: SceneInstance in grid.get_tiles_in_radius(current_hex.cube_id, scouting_exploration_radius):
		var tile := nearby_tile.node as HexBase
		if tile != null and not tile.is_explored:
			tile.is_explored = true
			current_quest.record_scouted_hex(tile)
