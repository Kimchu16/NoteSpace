extends StaticBody3D

func setup_scene(entity: OpenXRFbSpatialEntity) -> void:
	var room_manager = get_tree().get_first_node_in_group("RoomManager")
	if room_manager == null:
		queue_free()
		return

	room_manager.process_scene_entity(self, entity)
