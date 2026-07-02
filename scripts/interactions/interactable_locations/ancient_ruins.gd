class_name AncientRuins extends QuestObjective

const QUEST_TYPE_INVESTIGATE := "investigate"

@export var investigate_time: float = 8.0

var _quest_running: bool = false
var _pending_reward: Dictionary[ItemInfo, int] = {}
var _loot_claimed: bool = false

func _ready() -> void:
	super()
	if quest_types.is_empty():
		quest_types = [QUEST_TYPE_INVESTIGATE]
	state_machine = StateMachine.new(["available", "looted"])
	state_machine.set_state("available")

func _on_visibility_changed() -> void:
	super._on_visibility_changed()
	if hex.is_explored:
		Manager.instance.journal.complete_task(journal_quest.id)

func can_interact() -> bool:
	var lootable := hex.structure.structure_info as LootableStructureInfo
	if lootable != null and lootable.loot_once and _loot_claimed:
		return false
	return not _quest_running and not get_filtered_quest_types().is_empty()

func interact() -> void:
	pass

func execute_quest(q: Quest) -> void:
	if _quest_running:
		return

	_quest_running = true
	_pending_reward.clear()

	await get_tree().create_timer(investigate_time).timeout

	var lootable := hex.structure.structure_info as LootableStructureInfo
	if lootable != null:
		_pending_reward = lootable.roll_loot()

	q.return_from_quest()
	_quest_running = false

func complete_quest(_q: Quest) -> void:
	var lootable := hex.structure.structure_info as LootableStructureInfo
	if lootable == null:
		return

	for item: ItemInfo in _pending_reward.keys():
		Manager.instance.player_instance.inventory.add(item, _pending_reward[item])
	_pending_reward.clear()

	if lootable.loot_once:
		_loot_claimed = true
		state_machine.set_state("looted")
		Manager.instance.quests.quest_availability_changed.emit()
