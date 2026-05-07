extends Interaction

@export var adventurer: SceneInfo;
@export var adventurer_spawn: Node3D;
@onready var spawn_interval: Timer = $spawn_interval

func _ready() -> void:
	Config.gamestate.quest_list_changed.connect(spawn_interval.start)
	spawn_interval.timeout.connect(adventurer.queue.bind(_adventurer_ready))

func interact() -> void:
	pass

func can_interact() -> bool:
	return false;
	
func _adventurer_ready(s: SceneInfo) -> void:
	var instance := s.get_instance();
	instance.node.global_position = adventurer_spawn.global_position;
	SceneManager.get_active_scene().add_child(instance);
