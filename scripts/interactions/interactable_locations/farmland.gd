class_name FarmTile extends QuestObjective

enum CropState {
	FALLOW,
	PLANTED,
	WATERED,
	READY,
	DEAD
}

@onready var mesh_fallow: Node3D = $mesh_fallow
@onready var mesh_planted: Node3D = $mesh_planted
@onready var mesh_watered: Node3D = $mesh_watered
@onready var mesh_ready: Node3D = $mesh_ready
@onready var mesh_dead: Node3D = $mesh_dead

@export var plant_quest_time: float = 5.0
@export var water_quest_time: float = 5.0
@export var harvest_quest_time: float = 8.0
@export var overgrow_time: float = 120.0
@export var water_window: float = 60.0

var _quest_running: bool = false
var _overgrow_timer: SceneTreeTimer = null
var _wither_timer: SceneTreeTimer = null
var _pending_reward: Dictionary[ItemInfo, int] = {}

func _ready() -> void:
	super()
	var states: Array[String] = []
	for s in CropState.keys():
		states.append(s)
	state_machine = StateMachine.new(states)
	state_machine.state_entered.connect(_on_crop_state_entered)
	_set_crop_state(CropState.FALLOW)

func _set_crop_state(state: CropState) -> void:
	state_machine.set_state(CropState.keys()[state])
	_update_mesh(state)
	Manager.instance.quests.quest_availability_changed.emit()

func _current_crop_state() -> CropState:
	var key := state_machine.get_current_state()
	return CropState[key] as CropState

func _update_mesh(state: CropState) -> void:
	mesh_planted.visible = state == CropState.PLANTED;
	mesh_watered.visible = state == CropState.WATERED;
	mesh_ready.visible = state == CropState.READY;
	mesh_dead.visible = state == CropState.DEAD;
	toggle_collision(state == CropState.READY);

func _on_crop_state_entered(state: String) -> void:
	_cancel_timers()
	match state:
		"PLANTED":
			_wither_timer = get_tree().create_timer(water_window)
			_wither_timer.timeout.connect(func() -> void:
				if _current_crop_state() == CropState.PLANTED:
					_set_crop_state(CropState.DEAD)
			)
		"READY":
			_overgrow_timer = get_tree().create_timer(overgrow_time)
			_overgrow_timer.timeout.connect(func() -> void:
				if _current_crop_state() == CropState.READY:
					_set_crop_state(CropState.DEAD)
			)

func _cancel_timers() -> void:
	_overgrow_timer = null
	_wither_timer = null

func can_interact() -> bool:
	return has_visible_quest_activity() or (not _quest_running and not get_filtered_quest_types().is_empty())

func interact() -> void:
	pass

func execute_quest(q: Quest) -> void:
	if _quest_running:
		return
	_quest_running = true
	_pending_reward.clear()
	var behaviour := get_quest_behaviour(q.quest_key)

	match behaviour:
		"plant":
			await get_tree().create_timer(get_quest_duration(q.quest_key, plant_quest_time)).timeout
			_set_crop_state(CropState.PLANTED)
		"water":
			await get_tree().create_timer(get_quest_duration(q.quest_key, water_quest_time)).timeout
			_set_crop_state(CropState.WATERED)
		"harvest":
			await get_tree().create_timer(get_quest_duration(q.quest_key, harvest_quest_time)).timeout
			_set_crop_state(CropState.READY)
			var watered_outcome := roll_quest_outcome(q.quest_key)
			if watered_outcome != null:
				_pending_reward = watered_outcome.roll_loot()
				watered_outcome.complete_journal_task()
			else:
				var watered_lootable := hex.structure.structure_info as LootableStructureInfo
				if watered_lootable != null:
					_pending_reward = watered_lootable.roll_loot()
		"collect":
			await get_tree().create_timer(get_quest_duration(q.quest_key, harvest_quest_time)).timeout
			var outcome := roll_quest_outcome(q.quest_key)
			if outcome != null:
				_pending_reward = outcome.roll_loot()
				outcome.complete_journal_task()
			else:
				var lootable := hex.structure.structure_info as LootableStructureInfo
				if lootable != null:
					_pending_reward = lootable.roll_loot()
		"clear":
			await get_tree().create_timer(get_quest_duration(q.quest_key, plant_quest_time)).timeout
			_set_crop_state(CropState.FALLOW)

	q.return_from_quest()
	_quest_running = false

func complete_quest(_q: Quest) -> void:
	if _pending_reward.is_empty():
		return
		
	grant_player_inventory_rewards(_pending_reward)
	_pending_reward.clear()
	_set_crop_state(CropState.FALLOW)
