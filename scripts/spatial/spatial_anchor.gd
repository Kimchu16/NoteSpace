extends Node3D

#@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D

func setup_scene(spatial_entity: OpenXRFbSpatialEntity) -> void:#
	var note = get_parent().find_child("Note3D")
	# print("Child: ", note)
