class_name OpeningChapterDefinition
extends Resource
## Opening targets and milestone grants are content, not UI conditions.
@export_range(1, 3, 1) var required_projects := 2
@export_range(0, 1000, 1) var forge_grant := 20
@export_range(0, 1000, 1) var completion_grant := 40
@export_range(0, 100, 1) var completion_prestige := 2
