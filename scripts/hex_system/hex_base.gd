class_name HexBase
extends Node3D

const SIDES := 6
const RADIUS_IN := 1.0
const RADIUS_OUT := 2.0 / sqrt(3.0)

var meshes: Array[MeshInstance3D] = [];

func _ready() -> void:
	meshes.assign(find_children("*", "MeshInstance3D", true, false))

func get_hex_vertices() -> Array[Vector3]:
	var vertices: Array[Vector3] = []
	for i in SIDES:
		var angle = deg_to_rad(60 * i - 30)
		vertices.append(Vector3(cos(angle) * RADIUS_OUT, 0, sin(angle) * RADIUS_OUT))
	return vertices

func get_edge_midpoints() -> Array[Vector3]:
	var vertices = get_hex_vertices()
	var midpoints: Array[Vector3] = []

	for i in SIDES:
		var a = vertices[i]
		var b = vertices[(i + 1) % SIDES]
		midpoints.append((a + b) * 0.5)

	return midpoints

func apply_region(reg: RegionInfo) -> void:
	for mesh in meshes:
		if reg && reg.material:
			mesh.material_override = reg.material;
