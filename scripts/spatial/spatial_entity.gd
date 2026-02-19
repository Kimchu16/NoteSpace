extends StaticBody3D

func setup_scene(entity: OpenXRFbSpatialEntity) -> void:
	var labels: PackedStringArray = entity.get_semantic_labels()
	print("Semantic labels:", labels)
	# Only allow specific surface types
	var allowed := false

	if labels.has("wall_face"):
		allowed = true
	elif labels.has("table"):
		allowed = true
	elif labels.has("floor"):
		allowed = true
	elif labels.has("ceiling"):
		allowed = true
	elif labels.has("other"):
		allowed = true

	if not allowed:
		queue_free()
		return

	# Add to valid placement group
	add_to_group("valid_surfaces")

	var collision_shape = entity.create_collision_shape()
	if collision_shape:
		add_child(collision_shape)
