class_name HexMines extends HexGrid

@export var exit: StructureInfo;

func _ready() -> void:
	super()
	
func _on_map_ready() -> void:
	super();
	
	#TODO: Figure out why the hex is in the main grid rather than the one that was just generated
	#Seems related to the right hexgrid not being set when this is called
	Manager.instance.player_instance.get_hex().set_structure(exit);
