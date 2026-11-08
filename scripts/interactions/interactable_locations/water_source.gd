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
var protected_uses := 0

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
	return has_visible_quest_activity() or (not _quest_running and not get_filtered_quest_types().is_empty())

func get_filtered_quest_types(active_state: int = state_machine.get_current_state_index()) -> Array[String]:
	var options := super.get_filtered_quest_types(active_state)
	if protected_uses > 0: options.erase("protect_spring")
	return options

func get_quest_context_label(key: String) -> String:
	var context := super.get_quest_context_label(key)
	return context + ("\n" + tr("COMMUNITY_WATER_PROTECTED") % protected_uses if protected_uses > 0 else "")

func execute_quest(q: Quest) -> void:
	if _quest_running:
		return

	_quest_running = true
	_pending_reward.clear()
	var behaviour := get_quest_behaviour(q.quest_key, "fill")
	if not await q.wait_for_work(get_effective_quest_duration(q, fill_time), get_tree()):
		_quest_running = false
		return

	var outcome := roll_quest_outcome(q)
	if outcome != null:
		_pending_reward = outcome.roll_loot()
		if outcome.has_next_state():
			var next := WaterState[outcome.next_state] as WaterState
			if protected_uses > 0 and behaviour in ["fill", "draw"]:
				next = WaterState.FRESH
				outcome.next_state = "FRESH"
			_set_water_state(next)
		outcome.complete_journal_task()
	elif reward_item != null:
		_pending_reward[reward_item] = reward_amount
		match behaviour:
			"purify", "maintain":
				_set_water_state(WaterState.FRESH)

	if behaviour == "protect": protected_uses = 3
	elif behaviour in ["fill", "draw"]: protected_uses = maxi(0, protected_uses - 1)
	q.return_from_quest()
	_quest_running = false

func complete_quest(q: Quest) -> void:
	if Manager.instance.player_instance == null:
		return

	grant_player_inventory_rewards(_pending_reward, q)
	_pending_reward.clear()

func _set_water_state(state: WaterState) -> void:
	state_machine.set_state(WaterState.keys()[state])
	_update_markers(state)
	Manager.instance.quests.quest_availability_changed.emit()

func _update_markers(state: WaterState) -> void:
	if tainted_marker != null:
		tainted_marker.visible = state == WaterState.TAINTED
