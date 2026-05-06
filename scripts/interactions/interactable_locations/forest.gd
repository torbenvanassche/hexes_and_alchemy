extends Interaction

@onready var trees: Node3D = $trees
@onready var stumps: Node3D = $stumps

@export var regrow_time: float = 100
@export var item_info: ItemInfo

var _is_regrowing: bool = false

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
