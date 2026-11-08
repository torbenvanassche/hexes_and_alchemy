class_name DeliveryDefinition
extends Resource

## Authored delivery requirements and effects. Movement belongs to the caller.
@export var id := ""
@export var title_key := ""
@export_multiline var description_key := ""
@export var cargo: Dictionary[ItemInfo, int] = {}
@export_range(0, 500, 1, "or_greater") var payment := 0
@export_range(0, 10, 1, "or_greater") var reputation_reward := 0
@export_range(0, 10, 1, "or_greater") var prestige_reward := 0
@export var return_required := false
@export var completion_task: JournalTask
