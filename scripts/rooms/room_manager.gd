class_name RoomManager
extends Node

signal room_loaded(room_id: String)
signal room_unloading(room_id: String)
signal current_room_changed(previous_room_id: String, current_room_id: String)
signal room_anchor_records_changed

const RoomSceneLogic = preload("res://scripts/rooms/room_scene_logic.gd")
const RoomStore = preload("res://scripts/rooms/room_store.gd")

const ROOMS_FILE := "user://rooms.json"
const LEGACY_ANCHORS_FILE := "user://spatial_anchors.json"
const ROOM_MATCH_MIN_SHARED_ENTITIES := 2
const ROOM_MATCH_MIN_RATIO := 0.35
const ANCHOR_ROOM_HINT_TTL_MSEC := 15000

var current_room_id: String = ""
var rooms: Dictionary = {}

var _discovered_room_id: String = ""
var _discovered_room_members: Dictionary = {}
var _pending_scene_entities: Array = []
var _fallback_finalize_serial: int = 0
var _preferred_room_id: String = ""
var _anchor_room_hint_id: String = ""
var _anchor_room_hint_time_msec: int = 0

func _ready() -> void:
	_load_rooms_from_file()

func begin_scene_discovery(preferred_room_id: String = "") -> void:
	_discovered_room_id = ""
	_discovered_room_members.clear()
	_pending_scene_entities.clear()
	_fallback_finalize_serial += 1
	_preferred_room_id = str(preferred_room_id)

func load_room(id: String, force_reload: bool = false) -> void:
	var room_id: String = str(id)
	if room_id.is_empty():
		return

	_ensure_room(room_id)

	var previous_room_id: String = current_room_id
	if not force_reload and previous_room_id == room_id:
		return

	current_room_id = room_id
	emit_signal("current_room_changed", previous_room_id, current_room_id)
	emit_signal("room_loaded", current_room_id)

func unload_current_room() -> void:
	if current_room_id.is_empty():
		_clear_active_collision_nodes()
		return

	var previous_room_id: String = current_room_id
	emit_signal("room_unloading", previous_room_id)
	_clear_active_collision_nodes()
	current_room_id = ""
	emit_signal("current_room_changed", previous_room_id, current_room_id)

func process_scene_entity(scene_node: StaticBody3D, entity: OpenXRFbSpatialEntity) -> void:
	if not is_instance_valid(scene_node) or entity == null:
		if is_instance_valid(scene_node):
			scene_node.queue_free()
		return

	if _discovered_room_id.is_empty():
		_pending_scene_entities.append({
			"scene_node": scene_node,
			"entity": entity
		})
		_schedule_fallback_room_finalize()
		return

	_process_room_member_scene_entity(scene_node, entity)

func upsert_anchor_note(room_id: String, anchor_uuid: String, note_id: int, owner: String) -> void:
	RoomStore.upsert_anchor_note(rooms, current_room_id, room_id, anchor_uuid, note_id, owner)
	_save_rooms_to_file()
	emit_signal("room_anchor_records_changed")

func remove_anchor_record(anchor_uuid: String, room_id: String = "") -> void:
	RoomStore.remove_anchor_record(rooms, current_room_id, anchor_uuid, str(room_id))
	_save_rooms_to_file()
	emit_signal("room_anchor_records_changed")

func find_room_id_for_anchor(anchor_uuid: String) -> String:
	return RoomStore.find_room_id_for_anchor(rooms, anchor_uuid)

func maybe_switch_room_for_anchor(anchor_uuid: String) -> void:
	var room_id: String = find_room_id_for_anchor(anchor_uuid)
	if room_id.is_empty():
		return

	_remember_anchor_room_hint(room_id)
	if room_id == current_room_id:
		return

	unload_current_room()
	load_room(room_id)

func get_room_note_map(room_id: String, owner_id: String = "") -> Dictionary:
	return RoomStore.get_room_note_map(rooms, room_id, owner_id)

func get_note_record(room_id: String, anchor_uuid: String, owner_id: String = "") -> Dictionary:
	return RoomStore.get_note_record(rooms, room_id, anchor_uuid, owner_id)

func get_room_data(room_id: String) -> RoomData:
	var normalized_room_id: String = str(room_id)
	if not rooms.has(normalized_room_id):
		return null
	return rooms[normalized_room_id]

func get_current_room_data() -> RoomData:
	return get_room_data(current_room_id)

func get_room_ids() -> Array[String]:
	var ids: Array[String] = []
	for room_id in rooms.keys():
		ids.append(str(room_id))
	return ids

func get_anchor_room_lookup() -> Dictionary:
	return RoomStore.get_anchor_room_lookup(rooms)

func _process_room_member_scene_entity(scene_node: StaticBody3D, entity: OpenXRFbSpatialEntity) -> void:
	var entity_uuid: String = str(entity.uuid)
	if not RoomSceneLogic.entity_belongs_to_room(_discovered_room_members, entity_uuid):
		scene_node.queue_free()
		return

	var descriptor: Dictionary = RoomSceneLogic.create_collision_descriptor(entity)
	if descriptor.is_empty():
		scene_node.queue_free()
		return

	RoomSceneLogic.apply_collision_descriptor(scene_node, descriptor)
	RoomStore.upsert_collision_descriptor(rooms, current_room_id, descriptor)
	_save_rooms_to_file()

func _register_discovered_room(member_uuids: Array[String]) -> void:
	_fallback_finalize_serial += 1
	_discovered_room_members.clear()

	var discovered_member_uuids: Array[String] = member_uuids.duplicate()
	discovered_member_uuids.sort()
	for member_uuid in discovered_member_uuids:
		_discovered_room_members[member_uuid] = true

	var matched_room_id: String = RoomSceneLogic.match_existing_room_id(
		rooms,
		discovered_member_uuids,
		ROOM_MATCH_MIN_SHARED_ENTITIES,
		ROOM_MATCH_MIN_RATIO
	)
	var hinted_room_id: String = _resolve_hint_room_id(discovered_member_uuids, matched_room_id)
	if not hinted_room_id.is_empty():
		_discovered_room_id = hinted_room_id
	elif matched_room_id.is_empty():
		_discovered_room_id = RoomStore.generate_next_room_id(rooms)
	else:
		_discovered_room_id = matched_room_id

	var room: RoomData = _ensure_room(_discovered_room_id)
	room.collision_shapes.clear()
	load_room(_discovered_room_id)

func _flush_pending_scene_entities() -> void:
	if _discovered_room_id.is_empty():
		return

	var pending: Array = _pending_scene_entities.duplicate()
	_pending_scene_entities.clear()

	for entry in pending:
		var scene_node: StaticBody3D = entry.get("scene_node", null)
		var entity: OpenXRFbSpatialEntity = entry.get("entity", null)
		if not is_instance_valid(scene_node) or entity == null:
			continue

		_process_room_member_scene_entity(scene_node, entity)

func _schedule_fallback_room_finalize() -> void:
	_fallback_finalize_serial += 1
	var serial: int = _fallback_finalize_serial
	_finalize_fallback_room_async(serial)

func _finalize_fallback_room_async(serial: int) -> void:
	await get_tree().create_timer(0.35).timeout

	if serial != _fallback_finalize_serial:
		return

	if not _discovered_room_id.is_empty() or _pending_scene_entities.is_empty():
		return

	var member_uuids: Array[String] = RoomSceneLogic.resolve_discovered_member_uuids(
		_pending_scene_entities,
		_get_camera_world_position()
	)
	if member_uuids.is_empty():
		return

	_register_discovered_room(member_uuids)
	_flush_pending_scene_entities()

func _clear_active_collision_nodes() -> void:
	for collision_node in get_tree().get_nodes_in_group("room_collision_nodes"):
		if is_instance_valid(collision_node):
			collision_node.queue_free()

func _ensure_room(room_id: String) -> RoomData:
	return RoomStore.ensure_room(rooms, room_id)

func _remember_anchor_room_hint(room_id: String) -> void:
	var normalized_room_id: String = str(room_id)
	if normalized_room_id.is_empty():
		return

	_anchor_room_hint_id = normalized_room_id
	_anchor_room_hint_time_msec = Time.get_ticks_msec()

func _resolve_hint_room_id(discovered_member_uuids: Array[String], matched_room_id: String) -> String:
	var anchor_hint_room_id: String = _get_valid_anchor_hint_room_id()
	if not anchor_hint_room_id.is_empty():
		return anchor_hint_room_id

	if _preferred_room_id.is_empty() or matched_room_id == _preferred_room_id:
		return ""

	if not rooms.has(_preferred_room_id):
		return ""

	var preferred_room: RoomData = rooms[_preferred_room_id]
	if RoomSceneLogic.get_room_overlap_count(preferred_room, discovered_member_uuids) > 0:
		return _preferred_room_id

	return ""

func _get_valid_anchor_hint_room_id() -> String:
	if _anchor_room_hint_id.is_empty():
		return ""

	if not rooms.has(_anchor_room_hint_id):
		return ""

	var age_msec: int = Time.get_ticks_msec() - _anchor_room_hint_time_msec
	if age_msec > ANCHOR_ROOM_HINT_TTL_MSEC:
		return ""

	return _anchor_room_hint_id

func _load_rooms_from_file() -> void:
	rooms = RoomStore.load_rooms_from_file(ROOMS_FILE, LEGACY_ANCHORS_FILE)

func _save_rooms_to_file() -> void:
	RoomStore.save_rooms_to_file(rooms, ROOMS_FILE)

func _get_camera_world_position() -> Vector3:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return Vector3.ZERO

	var xr_camera: Node3D = current_scene.get_node_or_null("XROrigin3D/XRCamera3D")
	if xr_camera == null:
		return Vector3.ZERO

	return xr_camera.global_position
