extends RefCounted

static func ensure_room(rooms: Dictionary, room_id: String) -> RoomData:
	var normalized_room_id: String = str(room_id)
	if rooms.has(normalized_room_id):
		return rooms[normalized_room_id]

	var room: RoomData = RoomData.new()
	room.id = normalized_room_id
	rooms[normalized_room_id] = room
	return room

static func upsert_anchor_note(
	rooms: Dictionary,
	current_room_id: String,
	room_id: String,
	anchor_uuid: String,
	note_id: int,
	owner: String
) -> void:
	var normalized_room_id: String = str(room_id)
	var normalized_anchor_uuid: String = str(anchor_uuid)
	if normalized_room_id.is_empty() or normalized_anchor_uuid.is_empty():
		return

	remove_anchor_record(rooms, current_room_id, normalized_anchor_uuid, normalized_room_id)

	var room: RoomData = ensure_room(rooms, normalized_room_id)
	if not room.anchor_uuids.has(normalized_anchor_uuid):
		room.anchor_uuids.append(normalized_anchor_uuid)

	var updated: bool = false
	for i in range(room.notes.size()):
		if str(room.notes[i].get("anchor_uuid", "")) != normalized_anchor_uuid:
			continue

		room.notes[i] = {
			"anchor_uuid": normalized_anchor_uuid,
			"note_id": note_id,
			"owner": str(owner)
		}
		updated = true
		break

	if not updated:
		room.notes.append({
			"anchor_uuid": normalized_anchor_uuid,
			"note_id": note_id,
			"owner": str(owner)
		})

static func upsert_collision_descriptor(rooms: Dictionary, room_id: String, descriptor: Dictionary) -> void:
	var room: RoomData = ensure_room(rooms, room_id)
	var entity_uuid: String = str(descriptor.get("entity_uuid", ""))
	if entity_uuid.is_empty():
		return

	for i in range(room.collision_shapes.size()):
		if str(room.collision_shapes[i].get("entity_uuid", "")) != entity_uuid:
			continue

		room.collision_shapes[i] = descriptor.duplicate(true)
		return

	room.collision_shapes.append(descriptor.duplicate(true))

static func remove_anchor_record(
	rooms: Dictionary,
	current_room_id: String,
	anchor_uuid: String,
	preferred_room_id: String = ""
) -> void:
	var normalized_anchor_uuid: String = str(anchor_uuid)
	if normalized_anchor_uuid.is_empty():
		return

	var room_ids: Array = rooms.keys()
	if not preferred_room_id.is_empty():
		room_ids.erase(preferred_room_id)
		room_ids.push_front(preferred_room_id)

	for room_id_variant in room_ids:
		var room_id: String = str(room_id_variant)
		var room: RoomData = rooms[room_id]
		var room_changed: bool = false

		if room.anchor_uuids.has(normalized_anchor_uuid):
			room.anchor_uuids.erase(normalized_anchor_uuid)
			room_changed = true

		for i in range(room.notes.size() - 1, -1, -1):
			if str(room.notes[i].get("anchor_uuid", "")) != normalized_anchor_uuid:
				continue
			room.notes.remove_at(i)
			room_changed = true

		if room_changed and room.notes.is_empty() and room.collision_shapes.is_empty() and room.anchor_uuids.is_empty() and room_id != current_room_id:
			rooms.erase(room_id)

static func find_room_id_for_anchor(rooms: Dictionary, anchor_uuid: String) -> String:
	var normalized_anchor_uuid: String = str(anchor_uuid)
	if normalized_anchor_uuid.is_empty():
		return ""

	for room_id in rooms.keys():
		var room: RoomData = rooms[room_id]
		if room.anchor_uuids.has(normalized_anchor_uuid):
			return room.id

	return ""

static func get_room_note_map(rooms: Dictionary, room_id: String, owner_id: String = "") -> Dictionary:
	var result: Dictionary = {}
	var room = rooms.get(str(room_id), null)
	if room == null:
		return result

	var normalized_owner_id: String = str(owner_id)
	for note_data in room.notes:
		var anchor_uuid: String = str(note_data.get("anchor_uuid", ""))
		if anchor_uuid.is_empty():
			continue

		if not normalized_owner_id.is_empty() and str(note_data.get("owner", "")) != normalized_owner_id:
			continue

		result[anchor_uuid] = note_data.duplicate(true)

	return result

static func get_note_record(
	rooms: Dictionary,
	room_id: String,
	anchor_uuid: String,
	owner_id: String = ""
) -> Dictionary:
	var room = rooms.get(str(room_id), null)
	if room == null:
		return {}

	var normalized_anchor_uuid: String = str(anchor_uuid)
	var normalized_owner_id: String = str(owner_id)

	for note_data in room.notes:
		if str(note_data.get("anchor_uuid", "")) != normalized_anchor_uuid:
			continue

		if not normalized_owner_id.is_empty() and str(note_data.get("owner", "")) != normalized_owner_id:
			continue

		return note_data.duplicate(true)

	return {}

static func get_anchor_room_lookup(rooms: Dictionary) -> Dictionary:
	var anchor_room_lookup: Dictionary = {}

	for room_id_variant in rooms.keys():
		var room_id: String = str(room_id_variant)
		var room = rooms.get(room_id, null)
		if room == null:
			continue

		for anchor_uuid_variant in room.anchor_uuids:
			var anchor_uuid: String = str(anchor_uuid_variant)
			if anchor_uuid.is_empty():
				continue

			anchor_room_lookup[anchor_uuid] = room_id

	return anchor_room_lookup

static func generate_next_room_id(rooms: Dictionary) -> String:
	var next_room_id: int = 1
	for room_id_variant in rooms.keys():
		var room_id: String = str(room_id_variant)
		if not room_id.is_valid_int():
			continue
		next_room_id = max(next_room_id, int(room_id) + 1)

	while rooms.has(str(next_room_id)):
		next_room_id += 1

	return str(next_room_id)

static func load_rooms_from_file(rooms_file: String, legacy_anchors_file: String) -> Dictionary:
	var rooms: Dictionary = {}

	if not FileAccess.file_exists(rooms_file):
		_migrate_legacy_anchor_file(rooms, legacy_anchors_file)
		if not rooms.is_empty():
			save_rooms_to_file(rooms, rooms_file)
		return rooms

	var file: FileAccess = FileAccess.open(rooms_file, FileAccess.READ)
	if not file:
		return rooms

	var json: JSON = JSON.new()
	var file_text: String = file.get_as_text()
	file.close()

	if json.parse(file_text) != OK:
		return rooms

	var raw_data: Dictionary = json.data
	for room_id in raw_data.get("rooms", {}).keys():
		var room_dict: Dictionary = raw_data["rooms"][room_id]
		var room: RoomData = RoomData.from_dict(room_dict)
		if room.id.is_empty():
			room.id = str(room_id)
		rooms[room.id] = room

	if _normalize_room_ids(rooms):
		save_rooms_to_file(rooms, rooms_file)

	return rooms

static func save_rooms_to_file(rooms: Dictionary, rooms_file: String) -> void:
	var data: Dictionary = {
		"rooms": {}
	}

	for room_id in rooms.keys():
		var room: RoomData = rooms[room_id]
		data["rooms"][room_id] = room.to_dict()

	var file: FileAccess = FileAccess.open(rooms_file, FileAccess.WRITE)
	if not file:
		return

	file.store_string(JSON.stringify(data))
	file.close()

static func _migrate_legacy_anchor_file(rooms: Dictionary, legacy_anchors_file: String) -> void:
	if not FileAccess.file_exists(legacy_anchors_file):
		return

	var file: FileAccess = FileAccess.open(legacy_anchors_file, FileAccess.READ)
	if not file:
		return

	var json: JSON = JSON.new()
	var file_text: String = file.get_as_text()
	file.close()

	if json.parse(file_text) != OK:
		return

	var legacy_data: Dictionary = json.data
	if legacy_data.is_empty():
		return

	var room: RoomData = ensure_room(rooms, generate_next_room_id(rooms))
	for anchor_uuid in legacy_data.keys():
		var note_data = legacy_data[anchor_uuid]
		var normalized_anchor_uuid: String = str(anchor_uuid)
		if not room.anchor_uuids.has(normalized_anchor_uuid):
			room.anchor_uuids.append(normalized_anchor_uuid)

		room.notes.append({
			"anchor_uuid": normalized_anchor_uuid,
			"note_id": int(note_data.get("note_id", -1)),
			"owner": str(note_data.get("owner", ""))
		})

static func _normalize_room_ids(rooms: Dictionary) -> bool:
	if rooms.is_empty():
		return false

	var normalized_rooms: Dictionary = {}
	var ordered_room_ids: Array[String] = []
	for room_id in rooms.keys():
		ordered_room_ids.append(str(room_id))
	ordered_room_ids.sort()

	var next_room_number: int = 1
	var room_ids_to_migrate: Array[String] = []
	var room_id_changed: bool = false

	for room_id in ordered_room_ids:
		var room: RoomData = rooms[room_id]
		if room_id.is_valid_int() and not normalized_rooms.has(room_id):
			normalized_rooms[room_id] = room
			if room.id != room_id:
				room.id = room_id
				room_id_changed = true
			next_room_number = max(next_room_number, int(room_id) + 1)
			continue

		room_ids_to_migrate.append(room_id)

	for old_room_id in room_ids_to_migrate:
		var room: RoomData = rooms[old_room_id]
		while normalized_rooms.has(str(next_room_number)):
			next_room_number += 1

		var new_room_id: String = str(next_room_number)
		next_room_number += 1
		normalized_rooms[new_room_id] = room
		if room.id != new_room_id or old_room_id != new_room_id:
			room.id = new_room_id
			room_id_changed = true

	if room_id_changed:
		rooms.clear()
		for room_id in normalized_rooms.keys():
			rooms[room_id] = normalized_rooms[room_id]

	return room_id_changed
