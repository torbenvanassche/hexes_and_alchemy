class_name HexMines extends HexGrid

@export var exit: StructureInfo;

func _ready() -> void:
	super()
	
func _on_map_ready() -> void:
	super();
	
	SceneManager.set_active_grid(grid_name)
	Manager.instance.player_instance.get_hex().set_structure(exit);
