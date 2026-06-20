extends QuestObjective

@onready var trees: Node3D = $trees
@onready var stumps: Node3D = $stumps

@export var regrow_time: float = 100.0
@export var quest_time: float = 5.0

var _is_regrowing: bool = false
var _quest_running: bool = false

func _ready() -> void:
	super()
	_set_tree_state(true)

func interact() -> void:
	pass

func can_interact() -> bool:
	return trees.visible and not _is_regrowing

func _set_tree_state(tree_enabled: bool) -> void:
	trees.visible = tree_enabled
	stumps.visible = not tree_enabled
	toggle_collision(not tree_enabled)

func _start_regrow() -> void:
	_is_regrowing = true

	var timer := get_tree().create_timer(regrow_time)
	await timer.timeout

	_set_tree_state(true)
	_is_regrowing = false

func execute_quest(q: Quest) -> void:
	if _quest_running:
		return
	_quest_running = true

	await get_tree().create_timer(quest_time).timeout
	_set_tree_state(false)

	_start_regrow();
	q.return_from_quest()
	_quest_running = false
	
func complete_quest(_q: Quest) -> void:
	var l := hex.structure.structure_info as LootableStructureInfo
	if l == null:
		return

	var loot := l.roll_loot()
	for item: ItemInfo in loot.keys():
		Manager.instance.player_instance.inventory.add(item, loot[item])
