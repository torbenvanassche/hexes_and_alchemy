class_name CommunityPresentation
extends RefCounted

var props: Dictionary[String, Node3D] = {}
var _settlement_id := 0
# Improvements remain visible in the plaza; request authors exist on the board.

func refresh(regional: RegionalProgression) -> void:
	var settlement := Manager.instance.active_settlement
	if not is_instance_valid(settlement): return
	if _settlement_id != settlement.get_instance_id():
		for prop: Node3D in props.values():
			if is_instance_valid(prop): prop.queue_free()
		props.clear()
		_settlement_id = settlement.get_instance_id()
	for index in regional.catalog.projects.size():
		var definition := regional.catalog.projects[index]
		# Player-built improvements are persistent world structures, never props.
		if definition.construction != null: continue
		var prop := props.get(definition.id) as Node3D
		if not is_instance_valid(prop) and regional.project_complete(definition.id) and definition.visual != null:
			prop = definition.visual.instantiate() as Node3D
			prop.name = "CommunityImprovement_" + definition.id
			settlement.add_child(prop)
			prop.position = definition.improvement_position
			prop.scale = Vector3.ONE * definition.improvement_scale
			for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
				mesh.material_override = preload("res://materials/kay_fantasy_default.tres")
			props[definition.id] = prop
		if is_instance_valid(prop): prop.visible = regional.project_complete(definition.id)
