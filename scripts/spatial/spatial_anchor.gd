extends Node3D

@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D

func setup_scene(spatial_entity: OpenXRFbSpatialEntity) -> void:
	var data := spatial_entity.custom_data
	var color := Color(data.get('color', '#FFFFFF'))

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance_3d.set_surface_override_material(0, material)
