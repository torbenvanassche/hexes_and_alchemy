class_name GenerationJobs
extends RefCounted

class ChunkGeneration extends RefCounted:
	var chunk: HexChunk
	var next_cell := 0

class TileInstantiation extends RefCounted:
	var chunk: HexChunk
	var grid_id := Vector2i.ZERO
	var scene_info: SceneInfo
	var region: RegionInfo
	var elevation_units := 0

class ChunkPostProcess extends RefCounted:
	var chunk: HexChunk
	var stage := 0
	var index := 0
	var slope_candidates: Array[SceneInstance] = []

class StructureState extends RefCounted:
	var rng: RandomNumberGenerator
	var available_hexes: Array[Vector3i] = []
	var remaining_slots := 0
	var pending_structure: StructureInfo
	var search_start := 0
	var search_offset := 0

class RegionStructures extends RefCounted:
	var region_instance: RegionInstance
	var candidates: Array[Vector3i] = []
	var generation_state: StructureState

class RequiredCandidates extends RefCounted:
	var structure: StructureInfo
	var candidates: Array[HexBase] = []

class RequiredPlacement extends RefCounted:
	var structure: StructureInfo
	var cube_id := Vector3i.ZERO
