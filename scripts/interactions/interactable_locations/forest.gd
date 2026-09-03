extends QuestObjective

enum ForestState {
	HEALTHY,
	DEPLETED
}

@onready var trees: Node3D = $trees;
@onready var stumps: Node3D = $stumps;
@onready var danger_marker: Node3D = get_node_or_null("danger_marker") as Node3D

@export var regrow_time: float = 100.0
@export var quest_time: float = 5.0

var _quest_running: bool = false;
var _pending_reward: Dictionary[ItemInfo, int] = {}
var _pending_behaviour := ""
var _pending_outcome: QuestOutcome
var _pending_reveal_occupation := false
var _regrow_version: int = 0

func _ready() -> void:
	super();
	var states: Array[String] = []
	for state_name in ForestState.keys():
		states.append(state_name)
	state_machine = StateMachine.new(states)
	_set_forest_state(ForestState.HEALTHY)
	_initialize_occupation.call_deferred()

func interact() -> void:
	pass;

func can_interact() -> bool:
	return has_visible_quest_activity() or (not _quest_running and not get_filtered_quest_types().is_empty());

func _set_tree_state(tree_enabled: bool) -> void:
	trees.visible = tree_enabled;
	stumps.visible = not tree_enabled;
	toggle_collision(not tree_enabled);

func _set_forest_state(state: ForestState) -> void:
	state_machine.set_state(ForestState.keys()[state])
	_set_tree_state(state == ForestState.HEALTHY)
	Manager.instance.quests.quest_availability_changed.emit()

func execute_quest(q: Quest) -> void:
	if _quest_running:
		return;
	_quest_running = true;
	_pending_reward.clear()
	_pending_behaviour = ""
	_pending_outcome = null
	_pending_reveal_occupation = false

	var behaviour := get_quest_behaviour(q.quest_key, "harvest")
	var duration := get_effective_quest_duration(q, quest_time)
	var occupation := get_occupation()
	if behaviour == "secure" and occupation != null:
		duration = occupation.get_security_duration(duration)
	await get_tree().create_timer(duration).timeout;

	_pending_behaviour = behaviour
	_pending_reveal_occupation = not is_occupation_revealed()
	var danger_multiplier := 1.0 if has_occupation() else 0.0
	var outcome := roll_quest_outcome(q, danger_multiplier)
	_pending_outcome = outcome
	if outcome != null:
		_pending_reward = outcome.roll_loot()
		_append_monster_report(outcome)
	else:
		var lootable := hex.structure.structure_info as LootableStructureInfo
		if lootable != null and behaviour in ["forage", "harvest"]:
			_pending_reward = lootable.roll_loot()
	q.return_from_quest();
	_quest_running = false;

func _start_regrow() -> void:
	_regrow_version += 1
	var current_regrow_version := _regrow_version
	var timer := get_tree().create_timer(regrow_time);
	timer.timeout.connect(func() -> void:
		if current_regrow_version == _regrow_version and state_machine.get_current_state() == "DEPLETED":
			_set_forest_state(ForestState.HEALTHY)
	)
	
func complete_quest(_q: Quest) -> void:
	if _pending_reveal_occupation:
		reveal_occupation()
	if _pending_outcome != null:
		if _pending_behaviour == "secure":
			if not _pending_outcome.is_dangerous:
				clear_occupation()
		elif _pending_outcome.has_next_state():
			_set_forest_state(ForestState[_pending_outcome.next_state] as ForestState)
		_pending_outcome.complete_journal_task()
	else:
		match _pending_behaviour:
			"forage", "replant":
				_set_forest_state(ForestState.HEALTHY)
			"secure":
				clear_occupation()
			_:
				_set_forest_state(ForestState.DEPLETED)
	if state_machine.get_current_state() == "DEPLETED":
		_start_regrow()
	_update_danger_marker()
	grant_player_inventory_rewards(_pending_reward, _q)
	_pending_reward.clear()
	_pending_behaviour = ""
	_pending_outcome = null
	_pending_reveal_occupation = false

func _initialize_occupation() -> void:
	if hex == null:
		return
	var grid := hex.region_instance.hex_grid if hex.region_instance != null else null
	var rng := grid.create_rng("forest_occupation:%s" % hex.cube_id) if grid != null else null
	ensure_occupation_selected(rng, false)
	_update_danger_marker()

func _update_danger_marker() -> void:
	if danger_marker != null:
		danger_marker.visible = has_occupation() and is_occupation_revealed()

func _append_monster_report(outcome: QuestOutcome) -> void:
	if outcome == null or not _pending_reveal_occupation or not has_occupation():
		return
	var occupation := get_occupation()
	if occupation == null:
		return
	outcome.append_summary(tr("QUEST_REPORT_MONSTER_SPOTTED") % [
		occupation.get_display_name(),
		AdventurerRank.get_display_name(occupation.get_difficulty()),
	])
