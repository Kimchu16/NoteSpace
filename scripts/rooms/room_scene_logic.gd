extends RefCounted

const COMPONENT_TYPE_BOUNDED_2D := 3
const COMPONENT_TYPE_BOUNDED_3D := 4
const COMPONENT_TYPE_SEMANTIC_LABELS := 5
const COMPONENT_TYPE_ROOM_LAYOUT := 6
const COMPONENT_TYPE_CONTAINER := 7

const SURFACE_COLLISION_LAYER := 1 << 5
const PLANE_THICKNESS := 0.04
const MIN_BOX_EXTENT := 0.02

const PLANE_LABELS := {
	"wall_face": true,
	"floor": true,
	"ceiling": true
}

const BOX_LABELS := {
	"table": true,
	"desk": true,
	"chair": true,
	"couch": true,
	"sofa": true,
	"bed": true,
	"screen": true,
	"shelf": true,
	"storage": true,
	"cabinet": true,
	"other": true
}

static func resolve_discovered_member_uuids(entries: Array, camera_position: Vector3) -> Array[String]:
	var room_layout_entries: Array = _get_room_layout_entries(entries)
	if not room_layout_entries.is_empty():
		var layout_member_uuids: Array[String] = _select_room_layout_member_uuids(
			room_layout_entries,
			entries,
			camera_position
		)
		if not layout_member_uuids.is_empty():
			layout_member_uuids.sort()
			return layout_member_uuids

	var scene_anchor_uuids: Array[String] = []
	for entry in _select_fallback_room_entries(entries, camera_position):
		var entity: OpenXRFbSpatialEntity = entry.get("entity", null)
		if entity == null:
			continue

		var entity_uuid: String = str(entity.uuid)
		if entity_uuid.is_empty() or scene_anchor_uuids.has(entity_uuid):
			continue

		scene_anchor_uuids.append(entity_uuid)

	scene_anchor_uuids.sort()
	return scene_anchor_uuids

static func match_existing_room_id(
	rooms: Dictionary,
	scene_anchor_uuids: Array[String],
	min_shared_entities: int,
	min_ratio: float
) -> String:
	var scene_anchor_lookup: Dictionary = {}
	for entity_uuid in scene_anchor_uuids:
		scene_anchor_lookup[entity_uuid] = true

	var best_room_id: String = ""
	var best_overlap: int = 0
	var best_ratio: float = 0.0

	for room_id in rooms.keys():
		var room: RoomData = rooms[room_id]
		var known_floor_uuids: Array[String] = get_room_floor_entity_uuids(room)
		if known_floor_uuids.size() > 1:
			continue

		var known_entity_uuids: Array[String] = get_room_collision_entity_uuids(room)
		if known_entity_uuids.is_empty():
			continue

		var overlap: int = 0
		for entity_uuid in known_entity_uuids:
			if scene_anchor_lookup.has(entity_uuid):
				overlap += 1

		if overlap == 0:
			continue

		var max_size: int = max(scene_anchor_uuids.size(), known_entity_uuids.size())
		var overlap_ratio: float = float(overlap) / float(max_size)
		var meets_threshold: bool = overlap >= min_shared_entities or overlap_ratio >= min_ratio
		if not meets_threshold:
			continue

		if overlap > best_overlap or (overlap == best_overlap and overlap_ratio > best_ratio):
			best_room_id = room.id
			best_overlap = overlap
			best_ratio = overlap_ratio

	return best_room_id

static func get_room_overlap_count(room: RoomData, scene_anchor_uuids: Array[String]) -> int:
	var known_entity_uuids: Array[String] = get_room_collision_entity_uuids(room)
	if known_entity_uuids.is_empty() or scene_anchor_uuids.is_empty():
		return 0

	var scene_anchor_lookup: Dictionary = {}
	for entity_uuid in scene_anchor_uuids:
		scene_anchor_lookup[entity_uuid] = true

	var overlap: int = 0
	for entity_uuid in known_entity_uuids:
		if scene_anchor_lookup.has(entity_uuid):
			overlap += 1

	return overlap

static func get_room_collision_entity_uuids(room: RoomData) -> Array[String]:
	var entity_uuids: Array[String] = []
	for collision_data in room.collision_shapes:
		var entity_uuid: String = str(collision_data.get("entity_uuid", ""))
		if entity_uuid.is_empty() or entity_uuids.has(entity_uuid):
			continue
		entity_uuids.append(entity_uuid)

	return entity_uuids

static func get_room_floor_entity_uuids(room: RoomData) -> Array[String]:
	var floor_uuids: Array[String] = []
	for collision_data in room.collision_shapes:
		var labels: Array = collision_data.get("labels", [])
		var is_floor: bool = false
		for label in labels:
			if str(label) == "floor":
				is_floor = true
				break

		if not is_floor:
			continue

		var entity_uuid: String = str(collision_data.get("entity_uuid", ""))
		if entity_uuid.is_empty() or floor_uuids.has(entity_uuid):
			continue
		floor_uuids.append(entity_uuid)

	return floor_uuids

static func entity_belongs_to_room(discovered_room_members: Dictionary, entity_uuid: String) -> bool:
	if discovered_room_members.is_empty():
		return true
	return discovered_room_members.has(entity_uuid)

static func create_collision_descriptor(entity: OpenXRFbSpatialEntity) -> Dictionary:
	var labels: PackedStringArray = PackedStringArray()
	if entity.is_component_enabled(COMPONENT_TYPE_SEMANTIC_LABELS):
		labels = entity.get_semantic_labels()

	if entity.is_component_enabled(COMPONENT_TYPE_BOUNDED_2D) and _matches_labels(labels, PLANE_LABELS):
		var rect: Rect2 = entity.get_bounding_box_2d()
		var size: Vector3 = Vector3(
			max(rect.size.x, MIN_BOX_EXTENT),
			max(rect.size.y, MIN_BOX_EXTENT),
			PLANE_THICKNESS
		)
		var position: Vector3 = Vector3(
			rect.position.x + (rect.size.x * 0.5),
			rect.position.y + (rect.size.y * 0.5),
			0.0
		)
		return {
			"entity_uuid": str(entity.uuid),
			"shape_type": "plane",
			"labels": Array(labels),
			"position": _vector3_to_array(position),
			"size": _vector3_to_array(size)
		}

	if entity.is_component_enabled(COMPONENT_TYPE_BOUNDED_3D) and _matches_labels(labels, BOX_LABELS):
		var bounds: AABB = entity.get_bounding_box_3d()
		var size: Vector3 = Vector3(
			max(bounds.size.x, MIN_BOX_EXTENT),
			max(bounds.size.y, MIN_BOX_EXTENT),
			max(bounds.size.z, MIN_BOX_EXTENT)
		)
		var position: Vector3 = bounds.position + (bounds.size * 0.5)
		return {
			"entity_uuid": str(entity.uuid),
			"shape_type": "box",
			"labels": Array(labels),
			"position": _vector3_to_array(position),
			"size": _vector3_to_array(size)
		}

	return {}

static func apply_collision_descriptor(scene_node: StaticBody3D, descriptor: Dictionary) -> void:
	for child in scene_node.get_children():
		child.queue_free()

	scene_node.collision_layer = SURFACE_COLLISION_LAYER
	scene_node.collision_mask = 0
	scene_node.add_to_group("valid_surfaces")
	scene_node.add_to_group("room_collision_nodes")

	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = _array_to_vector3(descriptor.get("size", [MIN_BOX_EXTENT, MIN_BOX_EXTENT, MIN_BOX_EXTENT]))
	collision_shape.shape = shape
	collision_shape.position = _array_to_vector3(descriptor.get("position", [0.0, 0.0, 0.0]))
	scene_node.add_child(collision_shape)

static func _get_room_layout_entries(entries: Array) -> Array:
	var room_layout_entries: Array = []
	for entry in entries:
		var entity: OpenXRFbSpatialEntity = entry.get("entity", null)
		if entity == null or not _is_room_layout_entity(entity):
			continue
		room_layout_entries.append(entry)

	return room_layout_entries

static func _select_room_layout_member_uuids(
	room_layout_entries: Array,
	pending_entries: Array,
	camera_position: Vector3
) -> Array[String]:
	if room_layout_entries.is_empty():
		return []

	var selected_entry: Dictionary = _select_nearest_room_layout_entry(
		room_layout_entries,
		pending_entries,
		camera_position
	)
	if selected_entry.is_empty():
		return []

	var selected_entity: OpenXRFbSpatialEntity = selected_entry.get("entity", null)
	if selected_entity == null:
		return []

	var member_uuids: Array[String] = []
	var room_layout: Dictionary = selected_entity.get_room_layout()
	_append_unique_uuid(member_uuids, room_layout.get("floor", ""))
	_append_unique_uuid(member_uuids, room_layout.get("ceiling", ""))
	for wall_uuid in room_layout.get("walls", []):
		_append_unique_uuid(member_uuids, wall_uuid)

	if selected_entity.is_component_enabled(COMPONENT_TYPE_CONTAINER):
		for contained_uuid in selected_entity.get_contained_uuids():
			_append_unique_uuid(member_uuids, contained_uuid)

	return member_uuids

static func _select_nearest_room_layout_entry(
	room_layout_entries: Array,
	pending_entries: Array,
	camera_position: Vector3
) -> Dictionary:
	var pending_entry_lookup: Dictionary = _build_pending_entry_lookup(pending_entries)
	var best_entry: Dictionary = room_layout_entries[0]
	var best_distance: float = INF

	for entry in room_layout_entries:
		var entity: OpenXRFbSpatialEntity = entry.get("entity", null)
		if entity == null:
			continue

		var probe_position: Vector3 = _get_entry_world_center(entry)
		var room_layout: Dictionary = entity.get_room_layout()
		var floor_uuid: String = str(room_layout.get("floor", ""))
		if pending_entry_lookup.has(floor_uuid):
			probe_position = _get_entry_world_center(pending_entry_lookup[floor_uuid])

		var distance: float = _horizontal_distance(camera_position, probe_position)
		if distance < best_distance:
			best_distance = distance
			best_entry = entry

	return best_entry

static func _select_fallback_room_entries(entries: Array, camera_position: Vector3) -> Array:
	var floor_entries: Array = []
	for entry in entries:
		var entity: OpenXRFbSpatialEntity = entry.get("entity", null)
		if entity != null and _is_floor_entity(entity):
			floor_entries.append(entry)

	if floor_entries.size() < 2:
		return entries

	var selected_floor_entry: Dictionary = floor_entries[0]
	var best_distance: float = INF
	for floor_entry in floor_entries:
		var floor_distance: float = _horizontal_distance(camera_position, _get_entry_world_center(floor_entry))
		if floor_distance < best_distance:
			best_distance = floor_distance
			selected_floor_entry = floor_entry

	var selected_floor_entity: OpenXRFbSpatialEntity = selected_floor_entry.get("entity", null)
	var selected_floor_uuid: String = ""
	if selected_floor_entity != null:
		selected_floor_uuid = str(selected_floor_entity.uuid)

	var selected_entries: Array = []
	for entry in entries:
		var entry_center: Vector3 = _get_entry_world_center(entry)
		var nearest_floor_entry: Dictionary = floor_entries[0]
		var nearest_floor_distance: float = INF

		for floor_entry in floor_entries:
			var floor_center: Vector3 = _get_entry_world_center(floor_entry)
			var floor_distance: float = _horizontal_distance(entry_center, floor_center)
			if floor_distance < nearest_floor_distance:
				nearest_floor_distance = floor_distance
				nearest_floor_entry = floor_entry

		var nearest_floor_entity: OpenXRFbSpatialEntity = nearest_floor_entry.get("entity", null)
		if nearest_floor_entity != null and str(nearest_floor_entity.uuid) == selected_floor_uuid:
			selected_entries.append(entry)

	return selected_entries

static func _build_pending_entry_lookup(entries: Array) -> Dictionary:
	var entry_lookup: Dictionary = {}
	for entry in entries:
		var entity: OpenXRFbSpatialEntity = entry.get("entity", null)
		if entity == null:
			continue
		entry_lookup[str(entity.uuid)] = entry

	return entry_lookup

static func _is_room_layout_entity(entity: OpenXRFbSpatialEntity) -> bool:
	return entity.is_component_enabled(COMPONENT_TYPE_ROOM_LAYOUT)

static func _is_floor_entity(entity: OpenXRFbSpatialEntity) -> bool:
	if not entity.is_component_enabled(COMPONENT_TYPE_BOUNDED_2D):
		return false
	return _has_semantic_label(entity, "floor")

static func _has_semantic_label(entity: OpenXRFbSpatialEntity, label_name: String) -> bool:
	if not entity.is_component_enabled(COMPONENT_TYPE_SEMANTIC_LABELS):
		return false

	for label in entity.get_semantic_labels():
		if str(label) == label_name:
			return true

	return false

static func _get_entry_world_center(entry: Dictionary) -> Vector3:
	var scene_node: Node3D = entry.get("scene_node", null)
	var entity: OpenXRFbSpatialEntity = entry.get("entity", null)
	if scene_node == null or entity == null:
		return Vector3.ZERO

	return scene_node.to_global(_get_entity_local_center(entity))

static func _get_entity_local_center(entity: OpenXRFbSpatialEntity) -> Vector3:
	if entity.is_component_enabled(COMPONENT_TYPE_BOUNDED_2D):
		var rect: Rect2 = entity.get_bounding_box_2d()
		return Vector3(
			rect.position.x + (rect.size.x * 0.5),
			rect.position.y + (rect.size.y * 0.5),
			0.0
		)

	if entity.is_component_enabled(COMPONENT_TYPE_BOUNDED_3D):
		var bounds: AABB = entity.get_bounding_box_3d()
		return bounds.position + (bounds.size * 0.5)

	return Vector3.ZERO

static func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

static func _append_unique_uuid(member_uuids: Array[String], uuid_value: Variant) -> void:
	var normalized_uuid: String = str(uuid_value)
	if normalized_uuid.is_empty() or member_uuids.has(normalized_uuid):
		return
	member_uuids.append(normalized_uuid)

static func _matches_labels(labels: PackedStringArray, allowed_labels: Dictionary) -> bool:
	for label in labels:
		if allowed_labels.has(str(label)):
			return true
	return false

static func _vector3_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]

static func _array_to_vector3(value: Array) -> Vector3:
	if value.size() < 3:
		return Vector3.ZERO
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
