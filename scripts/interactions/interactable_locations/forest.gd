extends QuestObjective

enum ForestState {
	HEALTHY,
	DEPLETED
}

@onready var trees: Node3D = $trees;
@onready var stumps: Node3D = $stumps;

@export var regrow_time: float = 100.0
@export var quest_time: float = 5.0

var _quest_running: bool = false;
var _pending_reward: Dictionary[ItemInfo, int] = {}
var _regrow_version: int = 0

func _ready() -> void:
	super();
	var states: Array[String] = []
	for state_name in ForestState.keys():
		states.append(state_name)
	state_machine = StateMachine.new(states)
	_set_forest_state(ForestState.HEALTHY)

func interact() -> void:
	pass;

func can_interact() -> bool:
	return not _quest_running and not get_filtered_quest_types().is_empty();

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

	var behaviour := get_quest_behaviour(q.quest_key, "harvest")
	await get_tree().create_timer(get_quest_duration(q.quest_key, quest_time)).timeout;

	var outcome := roll_quest_outcome(q.quest_key)
	if outcome != null:
		_pending_reward = outcome.roll_loot()
		if outcome.has_next_state():
			_set_forest_state(ForestState[outcome.next_state] as ForestState)
		outcome.complete_journal_task()
	else:
		var lootable := hex.structure.structure_info as LootableStructureInfo
		if lootable != null and behaviour in ["forage", "harvest"]:
			_pending_reward = lootable.roll_loot()
		match behaviour:
			"forage":
				_set_forest_state(ForestState.HEALTHY)
			"replant":
				_set_forest_state(ForestState.HEALTHY)
			_:
				_set_forest_state(ForestState.DEPLETED)

	if state_machine.get_current_state() == "DEPLETED":
		_start_regrow()
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
	grant_player_inventory_rewards(_pending_reward)
	_pending_reward.clear()
