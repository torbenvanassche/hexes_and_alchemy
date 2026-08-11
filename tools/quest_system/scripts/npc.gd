class_name NPC extends CharacterBody3D

const SLOPE_SURFACE_COLLISION_MASK := 1 << 3
const TRAVEL_RATIONS: ItemInfo = preload("res://resources/item_info/travel_rations.tres")

@export var material: Material
@export var move_speed := 5.0
@export var arrive_distance := 0.1
@export var stuck_repath_seconds := 1.5
@export var stuck_distance_epsilon := 0.05

@export_group("Recovery")
@export_range(0.0, 60.0, 0.5) var base_rest_seconds := 3.0
@export_range(0.0, 10.0, 0.05) var quest_duration_rest_multiplier := 0.35
@export_range(1.0, 4.0, 0.05) var dangerous_quest_rest_multiplier := 2.0
@export_range(1.0, 3.0, 0.05) var uncertain_quest_rest_multiplier_min := 1.15
@export_range(1.0, 3.0, 0.05) var uncertain_quest_rest_multiplier_max := 1.55
@export_range(0.0, 120.0, 1.0) var maximum_rest_seconds := 30.0
@export_range(0.25, 1.0, 0.05) var injury_ration_recovery_multiplier := 0.75

@export_group("Rank")
@export var rank: AdventurerRank.Rank = AdventurerRank.Rank.F
@export var rank_experience: int = 0

@export_group("Scouting")
@export_range(0, 8, 1) var scouting_exploration_radius := 2

@export_group("Equipment")
@export var equipment: NpcEquipmentSlots

@onready var interaction_trigger: Area3D = get_node_or_null("InteractionTrigger") as Area3D

enum NPCState { IDLE, READY_TO_MOVE, MOVING_TO_QUEST, AT_QUEST, RETURNING, DONE, RESTING }

var current_path: Array[HexBase] = []
var current_target_index := 0
var state_machine: StateMachine
var current_quest: Quest
var npc_info: NpcInfo
var home_position := Vector3.ZERO
var operation_home_anchor: Node3D
var earned_currency: int = 0
var rest_remaining_seconds := 0.0
var rest_duration_seconds := 0.0
var last_completed_quest_key := ""
var recovering_from_injury := false
var _last_rest_display_second := -1
var _last_progress_position := Vector3.ZERO
var _stuck_time := 0.0

signal arrived()
signal movement_failed(npc: NPC)
signal rank_progress_changed()
signal activity_changed(npc: NPC)
signal rest_progress_changed(npc: NPC)

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
	state_machine.bind_update(get_state_as_string(NPCState.RESTING), _update_resting)
	state_machine.state_entered.connect(_on_state_entered)
	set_state(NPCState.IDLE)

func _on_state_entered(state: String) -> void:
	_set_world_presence(state in [
		get_state_as_string(NPCState.MOVING_TO_QUEST),
		get_state_as_string(NPCState.AT_QUEST),
		get_state_as_string(NPCState.RETURNING),
	])
	if state == get_state_as_string(NPCState.MOVING_TO_QUEST):
		_begin_move_to_quest()
	elif state == get_state_as_string(NPCState.AT_QUEST):
		arrived.emit()
	elif state == get_state_as_string(NPCState.RETURNING):
		_begin_return_home()
	elif state == get_state_as_string(NPCState.DONE):
		_complete_quest()
	elif state == get_state_as_string(NPCState.RESTING):
		_begin_resting()
	activity_changed.emit(self)

func get_state_as_string(state: NPCState) -> String:
	return NPCState.keys()[state].to_lower()

func is_state(state: NPCState) -> bool:
	return state_machine != null and get_state_as_string(state) == state_machine.get_current_state()

func set_state(state: NPCState) -> void:
	if state_machine == null:
		return
	state_machine.set_state(get_state_as_string(state))

func _set_world_presence(is_present: bool) -> void:
	visible = is_present
	if interaction_trigger != null:
		interaction_trigger.monitoring = is_present
		interaction_trigger.monitorable = is_present

func set_operation_home(anchor: Node3D) -> void:
	operation_home_anchor = anchor
	if operation_home_anchor != null and is_instance_valid(operation_home_anchor):
		home_position = operation_home_anchor.global_position

func get_operation_home_position() -> Vector3:
	if operation_home_anchor != null and is_instance_valid(operation_home_anchor):
		return operation_home_anchor.global_position
	return home_position

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
	if operation_home_anchor == null or not is_instance_valid(operation_home_anchor):
		home_position = global_position
	else:
		home_position = operation_home_anchor.global_position
	current_quest = q
	rest_remaining_seconds = 0.0
	rest_duration_seconds = 0.0
	recovering_from_injury = false
	set_state(NPCState.READY_TO_MOVE)

func cancel_assigned_quest(quest: Quest) -> void:
	if current_quest != quest:
		return
	current_quest = null
	current_path.clear()
	velocity = Vector3.ZERO
	home_position = get_operation_home_position()
	global_position = home_position
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

func get_profession_label() -> String:
	if npc_info == null:
		return tr("NPC_PROFESSION_GENERALIST")
	return npc_info.profession

func get_role_label() -> String:
	if npc_info == null:
		return tr("NPC_ROLE_ADVENTURER")
	return npc_info.role

func get_operation_roles() -> Array[String]:
	if npc_info == null or npc_info.operation_roles.is_empty():
		return ["adventurer"]
	return npc_info.operation_roles

func can_perform_role(required_role: String) -> bool:
	if required_role == "":
		return true
	return get_operation_roles().has(required_role)

func get_traits_label() -> String:
	if npc_info == null or npc_info.traits.is_empty():
		return tr("NPC_TRAITS_NONE")
	var trait_labels: Array[String] = []
	for trait_name in npc_info.traits:
		trait_labels.append(trait_name.capitalize())
	return ", ".join(trait_labels)

func evaluate_quest(quest: Quest) -> float:
	var required_role := ""
	if Manager.instance != null and Manager.instance.hub != null:
		required_role = Manager.instance.hub.get_required_role_for_quest(quest)
	return evaluate_quest_for_role(quest, required_role)

func evaluate_quest_for_role(quest: Quest, required_role: String) -> float:
	if not can_consider_quest_for_role(quest, required_role):
		return 0.0

	var minimum_rank := quest.get_minimum_rank()
	var score := _get_base_eligible_quest_score()
	score += float(quest.get_rank_experience_reward()) * _get_rank_experience_reward_weight()
	score += float(quest.get_offered_currency_reward()) * _get_offered_currency_reward_weight()
	score += maxf(0.0, float(int(rank) - int(minimum_rank))) * _get_rank_surplus_weight()
	score -= _get_distance_to_quest(quest) * _get_distance_penalty_per_tile()
	score += _get_job_interest_score(quest)
	score += _get_trait_interest_score(quest)
	return maxf(0.0, score)

func can_consider_quest(quest: Quest) -> bool:
	var required_role := ""
	if Manager.instance != null and Manager.instance.hub != null:
		required_role = Manager.instance.hub.get_required_role_for_quest(quest)
	return can_consider_quest_for_role(quest, required_role)

func can_consider_quest_for_role(quest: Quest, required_role: String) -> bool:
	if quest == null:
		return false
	if current_quest != null:
		return false
	if not quest.is_state(Quest.QuestState.WAITING) or not quest.party.is_empty():
		return false
	if not can_perform_role(required_role):
		return false
	if Manager.instance != null and Manager.instance.hub != null:
		var objective := quest.get_objective()
		if objective != null:
			if quest.context.get("supplies_reserved", false):
				if not objective.quest_has_required_supplies(quest):
					return false
			elif not objective.has_required_supplies(quest.quest_key, Manager.instance.hub.stockpile):
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

func complete_assigned_quest(quest: Quest, rank_experience_reward: int, payment: int = 0) -> void:
	if current_quest != quest:
		return
	add_rank_experience(rank_experience_reward)
	earned_currency += maxi(0, payment)
	last_completed_quest_key = quest.quest_key if quest != null else ""
	_start_recovery_after_quest(quest)
	current_quest = null
	current_path.clear()
	if rest_remaining_seconds > 0.0:
		set_state(NPCState.RESTING)
	else:
		set_state(NPCState.IDLE)

func is_available_for_quest() -> bool:
	return current_quest == null and state_machine != null and is_state(NPCState.IDLE) and rest_remaining_seconds <= 0.0

func get_activity_state_key() -> String:
	if state_machine == null:
		return get_state_as_string(NPCState.IDLE)
	return state_machine.get_current_state()

func get_activity_status_label() -> String:
	if is_state(NPCState.RESTING):
		if recovering_from_injury:
			return tr("NPC_STATUS_RECOVERING_INJURY") % int(ceil(rest_remaining_seconds))
		return tr("NPC_STATUS_RESTING") % int(ceil(rest_remaining_seconds))
	if current_quest != null:
		var status_key := "NPC_STATUS_%s" % get_activity_state_key().to_upper()
		var translated := tr(status_key)
		return translated if translated != status_key else get_activity_state_key().capitalize().replace("_", " ")
	return tr("NPC_STATUS_AVAILABLE")

func get_rest_progress_ratio() -> float:
	if rest_duration_seconds <= 0.0:
		return 0.0
	return clampf(1.0 - rest_remaining_seconds / rest_duration_seconds, 0.0, 1.0)

func get_rank_progress_label() -> String:
	if int(rank) >= int(AdventurerRank.get_max_rank()):
		return tr("ADVENTURER_RANK_PROGRESS_MAX") % [get_rank_label()]
	return tr("ADVENTURER_RANK_PROGRESS") % [
		get_rank_label(),
		rank_experience,
		_get_rank_threshold(AdventurerRank.get_next(rank)),
	]

func _begin_move_to_quest() -> void:
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
	home_position = get_operation_home_position()
	var home_hex := grid.get_hex_at_world_position(home_position) if grid != null else null
	current_path = _get_path_to_home(grid, start_hex, home_hex)
	current_target_index = 1
	_reset_stuck_tracking()
	if current_path.is_empty():
		_finish_return_at_home()

func _complete_quest() -> void:
	current_path.clear()
	arrived.emit()

func _begin_resting() -> void:
	velocity = Vector3.ZERO
	current_path.clear()
	home_position = get_operation_home_position()
	global_position = home_position
	_last_rest_display_second = int(ceil(rest_remaining_seconds))

func _update_resting() -> void:
	if rest_remaining_seconds <= 0.0:
		set_state(NPCState.IDLE)
		return
	rest_remaining_seconds = maxf(0.0, rest_remaining_seconds - get_physics_process_delta_time())
	var rest_display_second := int(ceil(rest_remaining_seconds))
	if rest_display_second != _last_rest_display_second:
		_last_rest_display_second = rest_display_second
		rest_progress_changed.emit(self)
	if rest_remaining_seconds <= 0.0:
		recovering_from_injury = false
		set_state(NPCState.IDLE)
		if Manager.instance != null and Manager.instance.quests != null:
			Manager.instance.quests.call_deferred("try_assign_waiting_quests")

func _start_recovery_after_quest(quest: Quest) -> void:
	var rest_time := base_rest_seconds
	recovering_from_injury = quest != null and quest.outcome != null and quest.outcome.is_dangerous
	var profile := quest.get_profile() if quest != null else null
	if profile != null:
		rest_time += maxf(0.0, profile.duration_seconds) * quest_duration_rest_multiplier
		var risk_key := quest.get_effective_risk_key() if quest.has_method("get_effective_risk_key") else profile.risk_key
		match risk_key:
			"QUEST_RISK_DANGEROUS":
				rest_time *= dangerous_quest_rest_multiplier
			"QUEST_RISK_UNCERTAIN":
				var lower_multiplier := minf(uncertain_quest_rest_multiplier_min, uncertain_quest_rest_multiplier_max)
				var upper_multiplier := maxf(uncertain_quest_rest_multiplier_min, uncertain_quest_rest_multiplier_max)
				rest_time *= randf_range(lower_multiplier, upper_multiplier)
	var ration_used := false
	if recovering_from_injury and Manager.instance != null and Manager.instance.hub != null:
		var ration_cost: Dictionary[ItemInfo, int] = {TRAVEL_RATIONS: 1}
		ration_used = Manager.instance.hub.withdraw_items(ration_cost)
		if ration_used:
			rest_time *= injury_ration_recovery_multiplier
	rest_duration_seconds = clampf(rest_time, 0.0, maximum_rest_seconds)
	rest_remaining_seconds = rest_duration_seconds
	if recovering_from_injury:
		_notify_injury_recovery(ration_used)

func _notify_injury_recovery(ration_used: bool) -> void:
	if Manager.instance == null or Manager.instance.toast == null:
		return
	var npc_name := npc_info.get_display_name() if npc_info != null else tr("SCENE_ADVENTURER_NAME")
	var recovery_seconds := int(ceil(rest_duration_seconds))
	var message_key := "NPC_INJURY_RATION_NOTICE" if ration_used else "NPC_INJURY_RECOVERY_NOTICE"
	Manager.instance.toast.notify(tr(message_key) % [npc_name, recovery_seconds], Color(0.72, 0.28, 0.12, 1.0))

func _update_moving_to_quest() -> void:
	_follow_path(func(): set_state(NPCState.AT_QUEST))

func _update_returning() -> void:
	_follow_path(func(): set_state(NPCState.DONE))

func _follow_path(on_arrived: Callable) -> void:
	if current_path.is_empty():
		_handle_empty_path()
		return
	var grid := _get_active_grid()
	_follow_terrain(grid)
	_explore_for_scouting_quest()
	if current_target_index >= current_path.size():
		velocity = Vector3.ZERO
		move_and_slide()
		_follow_terrain(grid)
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
	_follow_terrain(grid)
	_update_stuck_tracking()

func _follow_terrain(grid: HexGrid) -> void:
	if grid == null:
		return
	var current_hex := grid.get_hex_at_world_position(global_position, 0.0)
	if current_hex == null:
		return
	var traversal_method := _get_current_traversal_method(grid, current_hex)
	if current_hex is HexSlope:
		var ray_start := global_position + Vector3.UP * 3.0
		var ray_end := global_position - Vector3.UP * 3.0
		var query := PhysicsRayQueryParameters3D.create(
			ray_start,
			ray_end,
			SLOPE_SURFACE_COLLISION_MASK,
			[get_rid()]
		)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			global_position.y = (hit["position"] as Vector3).y
			velocity.y = 0.0
			return
	global_position.y = current_hex.get_surface_height_at_for_method(global_position, traversal_method)
	velocity.y = 0.0

func _get_current_traversal_method(
	grid: HexGrid,
	current_hex: HexBase
) -> HexInfo.TraversalTag:
	if current_target_index > 0 and current_target_index < current_path.size():
		var from_hex := current_path[current_target_index - 1]
		var to_hex := current_path[current_target_index]
		if grid.can_traverse_between(from_hex, to_hex, HexInfo.TraversalTag.WALK):
			return HexInfo.TraversalTag.WALK
		if grid.can_traverse_between(from_hex, to_hex, HexInfo.TraversalTag.BOAT):
			return HexInfo.TraversalTag.BOAT
	if current_hex.is_traversable(HexInfo.TraversalTag.WALK):
		return HexInfo.TraversalTag.WALK
	return HexInfo.TraversalTag.BOAT

func _get_active_grid() -> HexGrid:
	var active_scene := SceneManager.get_active_scene()
	return active_scene.node as HexGrid if active_scene != null else null

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
	if npc_info == null or npc_info.rank_experience_thresholds == null or npc_info.rank_experience_thresholds.get_point_count() == 0:
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
		return 3.0
	return npc_info.minimum_quest_score

func _get_base_eligible_quest_score() -> float:
	if npc_info == null:
		return 0.0
	return npc_info.base_eligible_quest_score

func _get_rank_experience_reward_weight() -> float:
	if npc_info == null:
		return 1.0
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

func _get_job_interest_score(quest: Quest) -> float:
	if npc_info == null:
		return 0.0
	var job_keys := _get_quest_job_keys(quest)
	var score := 0.0
	for job_key in job_keys:
		if npc_info.preferred_jobs.has(job_key):
			score += 5.0
		if npc_info.disliked_jobs.has(job_key):
			score -= 4.0
	return score

func _get_trait_interest_score(quest: Quest) -> float:
	if npc_info == null:
		return 0.0
	var profile := quest.get_profile()
	var risk_key := profile.risk_key if profile != null else ""
	var job_keys := _get_quest_job_keys(quest)
	var score := 0.0
	for trait_name in npc_info.traits:
		match trait_name.to_lower():
			"brave":
				if risk_key == "QUEST_RISK_DANGEROUS":
					score += 4.0
			"cautious":
				if risk_key == "QUEST_RISK_DANGEROUS":
					score -= 3.0
			"curious":
				if _has_any_job(job_keys, ["scout", "survey", "prospect", "delve"]):
					score += 3.0
			"greedy":
				score += float(quest.get_offered_currency_reward()) * 0.25
			"stout":
				if _has_any_job(job_keys, ["extract", "reinforce", "deepen"]):
					score += 2.0
			"green_thumb":
				if _has_any_job(job_keys, ["plant", "water", "harvest", "replant", "forage"]):
					score += 2.0
	return score

func _has_any_job(job_keys: Array[String], matching_jobs: Array[String]) -> bool:
	for job_name in job_keys:
		if matching_jobs.has(job_name):
			return true
	return false

func _get_quest_job_keys(quest: Quest) -> Array[String]:
	var keys: Array[String] = [quest.quest_key]
	var profile := quest.get_profile()
	if profile != null and profile.get_behaviour() != quest.quest_key:
		keys.append(profile.get_behaviour())
	return keys

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
	home_position = get_operation_home_position()
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
		home_position = get_operation_home_position()
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
			current_quest.record_scouted_hex(tile)
