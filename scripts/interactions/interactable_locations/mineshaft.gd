class_name Mineshaft extends QuestObjective

enum MineState {
	UNSURVEYED,
	POOR_VEIN,
	RICH_VEIN,
	UNSTABLE,
	EXHAUSTED
}

enum QuestTypeIndex {
	PROSPECT,
	EXTRACT,
	REINFORCE
}

@export var prospect_time: float = 6.0
@export var extract_time: float = 8.0
@export var reinforce_time: float = 5.0
@export var vein_infos: Array[MineVeinInfo] = []

var _quest_running: bool = false
var _pending_reward: Dictionary[ItemInfo, int] = {}
var _last_stable_state: MineState = MineState.POOR_VEIN

func _ready() -> void:
	super()

	var states: Array[String] = []
	for state_name in MineState.keys():
		states.append(state_name)

	state_machine = StateMachine.new(states)
	_set_mine_state(MineState.UNSURVEYED)

func interact() -> void:
	pass

func can_interact() -> bool:
	return not _quest_running and not get_filtered_quest_types().is_empty()

func execute_quest(q: Quest) -> void:
	if _quest_running:
		return

	_quest_running = true
	_pending_reward.clear()

	if q.quest_key == _get_quest_type(QuestTypeIndex.PROSPECT):
		await get_tree().create_timer(prospect_time).timeout
		var discovered_state := _roll_discovered_state()
		_set_mine_state(discovered_state)
	elif q.quest_key == _get_quest_type(QuestTypeIndex.EXTRACT):
		var origin_state := _current_mine_state()
		await get_tree().create_timer(extract_time).timeout
		_pending_reward = _roll_extract_reward(origin_state)
		_set_mine_state(origin_state)
	elif q.quest_key == _get_quest_type(QuestTypeIndex.REINFORCE):
		await get_tree().create_timer(reinforce_time).timeout
		_set_mine_state(_last_stable_state)

	q.return_from_quest()
	_quest_running = false

func complete_quest(q: Quest) -> void:
	if q.quest_key != _get_quest_type(QuestTypeIndex.EXTRACT):
		return

	if _pending_reward.is_empty():
		Debug.message("The miners came back empty-handed.")
		return

	for item: ItemInfo in _pending_reward.keys():
		Manager.instance.player_instance.inventory.add(item, _pending_reward[item])
	_pending_reward.clear()

func _current_mine_state() -> MineState:
	var key := state_machine.get_current_state()
	return MineState[key] as MineState

func _get_quest_type(index: QuestTypeIndex) -> String:
	if index < 0 or index >= quest_types.size():
		return ""
	return quest_types[index]

func _set_mine_state(state: MineState) -> void:
	state_machine.set_state(MineState.keys()[state])
	if state in [MineState.POOR_VEIN, MineState.RICH_VEIN]:
		_last_stable_state = state
	Config.gamestate.quest_availability_changed.emit()

func _roll_discovered_state() -> MineState:
	var valid_infos: Array[MineVeinInfo] = []
	var cumulative: Array[float] = []
	var total_weight := 0.0

	for vein_info in vein_infos:
		if vein_info == null or vein_info.prospect_weight <= 0.0:
			continue
		if vein_info.mine_state == MineState.UNSURVEYED or vein_info.mine_state == MineState.EXHAUSTED:
			continue

		total_weight += vein_info.prospect_weight
		valid_infos.append(vein_info)
		cumulative.append(total_weight)

	if total_weight <= 0.0:
		Debug.warn("Mineshaft has no valid prospectable vein info configured.")
		return MineState.POOR_VEIN

	var roll := randf() * total_weight
	for i in cumulative.size():
		if roll <= cumulative[i]:
			return valid_infos[i].mine_state

	return valid_infos[-1].mine_state

func _roll_extract_reward(origin_state: MineState) -> Dictionary[ItemInfo, int]:
	var info := _get_vein_info_for_state(origin_state)
	if info == null:
		return {}
	return info.roll_loot()

func _get_vein_info_for_state(state: MineState) -> MineVeinInfo:
	for vein_info in vein_infos:
		if vein_info != null and vein_info.mine_state == state:
			return vein_info
	return null
