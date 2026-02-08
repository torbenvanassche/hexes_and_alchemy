extends Interaction

@onready var trees: Node3D = $trees
@onready var stumps: Node3D = $stumps

@export var regrow_time: float = 10
@export var item_info: ItemInfo

var _is_regrowing: bool = false


func _ready() -> void:
	super()
	_set_tree_state(true)


func interact() -> void:
	Manager.instance.player_instance.inventory.add(item_info, 1)
	_set_tree_state(false)
	_start_regrow()


func can_interact() -> bool:
	return trees.visible and not _is_regrowing

func _set_tree_state(tree_enabled: bool) -> void:
	trees.visible = tree_enabled
	stumps.visible = not tree_enabled

func _set_children_process(node: Node, enabled: bool) -> void:
	for child in node.get_children():
		if child is CollisionObject3D:
			child.disabled = not enabled
		if child is Node:
			child.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED


func _start_regrow() -> void:
	_is_regrowing = true

	var timer := get_tree().create_timer(regrow_time)
	await timer.timeout

	_set_tree_state(true)
	_is_regrowing = false
