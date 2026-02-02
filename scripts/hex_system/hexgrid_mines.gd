class_name HexMines extends HexGrid

@export var exit: StructureInfo;

func _ready() -> void:
	generated.connect(on_enter, CONNECT_ONE_SHOT)
	skip_spawn_chunk = false;
	super()
	
func _on_map_ready() -> void:
	super();
	
func on_enter() -> void:
	Manager.instance.player_instance.get_hex().set_structure(exit);
	super();
