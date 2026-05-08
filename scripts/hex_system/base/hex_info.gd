class_name HexInfo extends SceneInfo

@export var is_walkable: bool = true;
@export var has_collision: bool = false;

enum TraversalTag {
	WALK,
	BOAT,
	FLY
}

@export var traversal_tags: Array[TraversalTag] = [TraversalTag.WALK]
