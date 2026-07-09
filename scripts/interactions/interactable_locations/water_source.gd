class_name WaterSource extends QuestObjective

enum WaterState {
	FRESH,
	TAINTED
}

@export var fill_time: float = 4.0
@export var reward_item: ItemInfo
@export var reward_amount: int = 1

@onready var tainted_marker: Node3D = get_node_or_null("tainted_marker") as Node3D

var _quest_running: bool = false
var _pending_reward: Dictionary[ItemInfo, int] = {}

func _ready() -> void:
	super()
	var states: Array[String] = []
	for state_name in WaterState.keys():
		states.append(state_name)
	state_machine = StateMachine.new(states)
	_set_water_state(WaterState.FRESH)

func interact() -> void:
	pass

func can_interact() -> bool:
	return not _quest_running and not get_filtered_quest_types().is_empty()

func execute_quest(q: Quest) -> void:
	if _quest_running:
		return

	_quest_running = true
	_pending_reward.clear()
	var behaviour := get_quest_behaviour(q.quest_key, "fill")
	await get_tree().create_timer(get_quest_duration(q.quest_key, fill_time)).timeout

	var outcome := roll_quest_outcome(q.quest_key)
	if outcome != null:
		_pending_reward = outcome.roll_loot()
		if outcome.has_next_state():
			_set_water_state(WaterState[outcome.next_state] as WaterState)
		outcome.complete_journal_task()
	elif reward_item != null:
		_pending_reward[reward_item] = reward_amount
		match behaviour:
			"purify", "maintain":
				_set_water_state(WaterState.FRESH)

	q.return_from_quest()
	_quest_running = false

func complete_quest(_q: Quest) -> void:
	if Manager.instance.player_instance == null:
		return

	for item: ItemInfo in _pending_reward.keys():
		Manager.instance.player_instance.inventory.add(item, _pending_reward[item])
	_pending_reward.clear()

func _set_water_state(state: WaterState) -> void:
	state_machine.set_state(WaterState.keys()[state])
	_update_markers(state)
	Manager.instance.quests.quest_availability_changed.emit()

func _update_markers(state: WaterState) -> void:
	if tainted_marker != null:
		tainted_marker.visible = state == WaterState.TAINTED
