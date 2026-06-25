class_name WaterSource extends QuestObjective

@export var fill_time: float = 4.0
@export var reward_item: ItemInfo
@export var reward_amount: int = 1

var _quest_running: bool = false

func interact() -> void:
	pass

func can_interact() -> bool:
	return not _quest_running and not get_filtered_quest_types().is_empty()

func execute_quest(q: Quest) -> void:
	if _quest_running:
		return

	_quest_running = true
	await get_tree().create_timer(fill_time).timeout
	q.return_from_quest()
	_quest_running = false

func complete_quest(_q: Quest) -> void:
	if reward_item == null or Manager.instance.player_instance == null:
		return

	Manager.instance.player_instance.inventory.add(reward_item, reward_amount)
