class_name NPC extends CharacterBody3D

@export var material: Material
@export var move_speed := 5.0
@export var arrive_distance := 0.1

@export_group("Rank")
@export var rank: AdventurerRank.Rank = AdventurerRank.Rank.F
@export var rank_experience: int = 0

enum NPCState { IDLE, READY_TO_MOVE, MOVING_TO_QUEST, AT_QUEST, RETURNING, DONE }

var current_path: Array[HexBase] = []
var current_target_index := 0
var state_machine: StateMachine
var current_quest: Quest
var npc_info: NpcInfo

signal arrived()
signal rank_progress_changed()

func _ready() -> void:
	$mesh/RootNode/unit.material_override = material
	if npc_info == null:
		npc_info = DataManager.instance.npcs.pick_random()
	if npc_info != null:
		rank = npc_info.starting_rank
	_rank_up_from_experience()
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

func assign_quest(q: Quest) -> void:
	current_quest = q
	set_state(NPCState.READY_TO_MOVE)

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
	visible = false
	current_path.clear()
	arrived.emit()

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
	velocity = Vector3(direction.normalized().x, 0, direction.normalized().z) * get_effective_move_speed()
	move_and_slide()

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
