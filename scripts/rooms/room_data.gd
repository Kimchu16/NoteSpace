class_name RoomData
extends RefCounted

var id: String = ""
var anchor_uuids: Array[String] = []
var notes: Array[Dictionary] = []
var collision_shapes: Array[Dictionary] = []

static func from_dict(data: Dictionary) -> RoomData:
	var room: RoomData = RoomData.new()
	room.id = str(data.get("id", ""))

	for uuid in data.get("anchor_uuids", []):
		room.anchor_uuids.append(str(uuid))

	for note_data in data.get("notes", []):
		if note_data is not Dictionary:
			continue

		var normalized: Dictionary = {}
		for key in note_data:
			normalized[key] = note_data[key]

		normalized["anchor_uuid"] = str(normalized.get("anchor_uuid", ""))
		normalized["note_id"] = int(normalized.get("note_id", -1))
		normalized["owner"] = str(normalized.get("owner", ""))
		room.notes.append(normalized)

	for collision_data in data.get("collision_shapes", []):
		if collision_data is Dictionary:
			room.collision_shapes.append(collision_data.duplicate(true))

	return room

func to_dict() -> Dictionary:
	return {
		"id": id,
		"anchor_uuids": anchor_uuids.duplicate(),
		"notes": notes.duplicate(true),
		"collision_shapes": collision_shapes.duplicate(true)
	}
