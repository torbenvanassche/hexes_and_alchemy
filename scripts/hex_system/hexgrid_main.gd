class_name MainGrid extends HexGrid

@export var player_settlement: StructureInfo;

func _ready() -> void:
	super()
	
func _on_map_ready() -> void:
	player_settlement.queue(settlement_created)
	super();
	
func settlement_created(sI: StructureInfo) -> void:
	chunks[Vector2i.ZERO].get_center().set_structure(sI);
