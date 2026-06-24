class_name MineVeinInfo extends LootableStructureInfo

@export var mine_state: Mineshaft.MineState = Mineshaft.MineState.POOR_VEIN
@export var prospect_weight: float = 0.0
@export_range(0.0, 1.0, 0.01) var collapse_chance: float = 0.0
@export_range(0.0, 1.0, 0.01) var exhaust_chance: float = 0.0
