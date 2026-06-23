extends RefCounted

func can_place(_structure_info: PlaceableStructureInfo, hex: HexBase, _inventory: ContentGroup) -> bool:
	if hex == null:
		print("no hex")
		return false

	if not hex.is_traversable(HexInfo.TraversalTag.WALK):
		print("not traversable")
		return false

	var grid := SceneManager.get_active_scene().node as HexGrid
	if grid == null:
		return false

	for direction: Vector3i in DataManager.instance.CUBE_DIRS:
		var neighbor := grid.get_hex_at_cube_id(hex.cube_id + direction)
		if neighbor != null and neighbor.is_traversable(HexInfo.TraversalTag.BOAT):
			print("neighbour valid")
			return true

	print("options exhausted")
	return false
