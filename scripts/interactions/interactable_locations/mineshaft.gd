extends QuestObjective

enum MineState {
	UNSURVEYED,
	POOR_VEIN,
	RICH_VEIN,
	UNSTABLE,
	EXHAUSTED
}

const QUEST_PROSPECT := "Prospect"
const QUEST_EXTRACT := "Extract"
const QUEST_REINFORCE := "Reinforce"
const QUEST_DEEPEN := "Deepen"

@export var prospect_time: float = 6.0
@export var extract_time: float = 8.0
@export var reinforce_time: float = 5.0
@export var deepen_time: float = 10.0
@export var rich_loot_table: LootTable

@onready var rich_marker: Node3D = $rich_marker
@onready var unstable_marker: Node3D = $unstable_marker

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
	return not _quest_running

func get_filtered_quest_types(_active_state: int = state_machine.get_current_state_index()) -> Array[String]:
	match _current_mine_state():
		MineState.UNSURVEYED:
			return [QUEST_PROSPECT]
		MineState.POOR_VEIN, MineState.RICH_VEIN:
			return [QUEST_EXTRACT]
		MineState.UNSTABLE:
			return [QUEST_REINFORCE]
		MineState.EXHAUSTED:
			return [QUEST_DEEPEN]
	return []

func execute_quest(q: Quest) -> void:
	if _quest_running:
		return

	_quest_running = true
	_pending_reward.clear()

	match q.quest_key:
		QUEST_PROSPECT:
			await get_tree().create_timer(prospect_time).timeout
			var discovered_state := _roll_prospect_state()
			_set_mine_state(discovered_state)
			_announce_state(discovered_state, "Prospecting")
		QUEST_EXTRACT:
			var origin_state := _current_mine_state()
			await get_tree().create_timer(extract_time).timeout
			_pending_reward = _roll_extract_reward(origin_state)
			var next_state := _roll_post_extract_state(origin_state)
			_set_mine_state(next_state)
			_announce_state(next_state, "Extraction")
		QUEST_REINFORCE:
			await get_tree().create_timer(reinforce_time).timeout
			_set_mine_state(_last_stable_state)
			Debug.message("Reinforcement stabilized the mineshaft.")
		QUEST_DEEPEN:
			await get_tree().create_timer(deepen_time).timeout
			var deeper_state := _roll_deeper_state()
			_set_mine_state(deeper_state)
			_announce_state(deeper_state, "Deepening")

	q.return_from_quest()
	_quest_running = false

func complete_quest(q: Quest) -> void:
	if q.quest_key != QUEST_EXTRACT:
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

func _set_mine_state(state: MineState) -> void:
	state_machine.set_state(MineState.keys()[state])
	if state in [MineState.POOR_VEIN, MineState.RICH_VEIN]:
		_last_stable_state = state
	_update_markers(state)
	Config.gamestate.quest_availability_changed.emit()

func _roll_prospect_state() -> MineState:
	var roll := randf()
	if roll <= 0.55:
		return MineState.POOR_VEIN
	if roll <= 0.85:
		return MineState.RICH_VEIN
	return MineState.UNSTABLE

func _roll_deeper_state() -> MineState:
	var roll := randf()
	if roll <= 0.25:
		return MineState.POOR_VEIN
	if roll <= 0.8:
		return MineState.RICH_VEIN
	return MineState.UNSTABLE

func _roll_post_extract_state(origin_state: MineState) -> MineState:
	var roll := randf()
	match origin_state:
		MineState.RICH_VEIN:
			if roll <= 0.4:
				return MineState.RICH_VEIN
			if roll <= 0.75:
				return MineState.UNSTABLE
			return MineState.EXHAUSTED
		MineState.POOR_VEIN:
			if roll <= 0.55:
				return MineState.POOR_VEIN
			if roll <= 0.85:
				return MineState.UNSTABLE
			return MineState.EXHAUSTED
	return MineState.EXHAUSTED

func _roll_extract_reward(origin_state: MineState) -> Dictionary[ItemInfo, int]:
	var table: LootTable = null
	if origin_state == MineState.RICH_VEIN and rich_loot_table != null:
		table = rich_loot_table
	else:
		var info := hex.structure.structure_info as LootableStructureInfo
		if info != null:
			table = info.loot_table

	if table == null:
		return {}
	return table.roll()

func _announce_state(state: MineState, action: String) -> void:
	match state:
		MineState.POOR_VEIN:
			Debug.message("%s revealed a poor vein." % action)
		MineState.RICH_VEIN:
			Debug.message("%s revealed a rich vein." % action)
		MineState.UNSTABLE:
			Debug.warn("%s left the mineshaft unstable." % action)
		MineState.EXHAUSTED:
			Debug.message("%s exhausted the current shaft." % action)
		MineState.UNSURVEYED:
			Debug.message("%s reset the shaft." % action)

func _update_markers(state: MineState) -> void:
	if rich_marker != null:
		rich_marker.visible = state == MineState.RICH_VEIN
	if unstable_marker != null:
		unstable_marker.visible = state == MineState.UNSTABLE
