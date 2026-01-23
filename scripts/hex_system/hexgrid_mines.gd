class_name HexMines extends HexGrid

@export var exit: StructureInfo;

func _ready() -> void:
	super()
	
func _on_map_ready() -> void:
	super();
	
func on_load() -> void:
	Manager.instance.player_instance.get_hex().set_structure(exit);
