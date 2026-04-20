extends Node

@onready var scene_manager: OpenXRFbSceneManager = get_tree().current_scene.get_node("XROrigin3D/OpenXRFbSceneManager")
@onready var room_manager: RoomManager = get_tree().get_first_node_in_group("RoomManager")
@onready var xr_camera: Node3D = get_tree().current_scene.get_node_or_null("XROrigin3D/XRCamera3D")

const AUTO_ROOM_SCAN_INTERVAL_SEC := 6.0
const AUTO_ROOM_SCAN_MOVE_THRESHOLD := 2.5
const AUTO_ROOM_CAPTURE_COOLDOWN_SEC := 30.0
const AUTO_ROOM_CAPTURE_RETRY_DISTANCE := 1.5

var xr_interface: XRInterface
var scene_capture_requested: bool = false
var scene_refresh_in_progress: bool = false
var ignore_room_change_refresh: bool = false
var room_switch_pending_refresh: bool = false
var auto_room_scan_elapsed: float = 0.0
var auto_room_capture_cooldown_elapsed: float = AUTO_ROOM_CAPTURE_COOLDOWN_SEC
var last_room_origin: Vector3 = Vector3.ZERO
var has_last_room_origin: bool = false
var last_auto_capture_origin: Vector3 = Vector3.ZERO
var has_last_auto_capture_origin: bool = false
var last_auto_capture_room_id: String = ""
var allow_scene_capture_on_missing: bool = false
var auto_room_check_pending: bool = false
var auto_room_check_previous_room_id: String = ""
var auto_room_check_previous_room_origin: Vector3 = Vector3.ZERO
var auto_room_check_has_previous_room_origin: bool = false

func _ready():
	scene_manager.openxr_fb_scene_data_missing.connect(_on_scene_data_missing)
	scene_manager.openxr_fb_scene_capture_completed.connect(_on_scene_capture_completed)
	xr_interface = XRServer.find_interface("OpenXR")

	if room_manager:
		room_manager.current_room_changed.connect(_on_current_room_changed)
		room_manager.room_loaded.connect(_on_room_loaded)

	if xr_interface and xr_interface.is_initialized():
		xr_interface.session_begun.connect(_on_openxr_session_begun)

func _on_openxr_session_begun() -> void:
	refresh_current_room("Loading room data for the current space", true)

func _process(delta: float) -> void:
	if xr_interface == null or not xr_interface.is_initialized():
		return

	auto_room_capture_cooldown_elapsed += delta

	if scene_capture_requested or scene_refresh_in_progress:
		return

	auto_room_scan_elapsed += delta
	if auto_room_scan_elapsed < AUTO_ROOM_SCAN_INTERVAL_SEC:
		return

	auto_room_scan_elapsed = 0.0

	if room_manager == null:
		return

	if room_manager.current_room_id.is_empty():
		_begin_auto_room_verification("Searching for a room")
		return

	if xr_camera == null:
		return

	if not has_last_room_origin:
		_begin_auto_room_verification("Refreshing room after startup")
		return

	if _room_distance(xr_camera.global_position, last_room_origin) >= AUTO_ROOM_SCAN_MOVE_THRESHOLD:
		_begin_auto_room_verification("User moved far enough to check the current room")

func _clear_scene_surfaces() -> void:
	for surface in get_tree().get_nodes_in_group("valid_surfaces"):
		if is_instance_valid(surface):
			surface.queue_free()

func refresh_current_room(reason: String = "Refreshing current room", allow_capture_if_missing: bool = false) -> void:
	auto_room_scan_elapsed = 0.0
	_rebuild_room_from_current_scene(reason, allow_capture_if_missing)

func force_scene_capture(reason: String = "Manual room rescan") -> void:
	if scene_capture_requested or scene_refresh_in_progress:
		return

	auto_room_scan_elapsed = 0.0
	allow_scene_capture_on_missing = false
	_request_scene_capture(reason)

func _rebuild_room_from_current_scene(_reason: String = "Refreshing current room", allow_capture_if_missing: bool = false) -> void:
	if scene_refresh_in_progress:
		return

	scene_refresh_in_progress = true
	ignore_room_change_refresh = true
	allow_scene_capture_on_missing = allow_capture_if_missing

	if room_manager:
		room_manager.begin_scene_discovery(room_manager.current_room_id)
		room_manager.unload_current_room()

	_clear_scene_surfaces()

	if scene_manager.are_scene_anchors_created():
		# print("Removing cached scene anchors before creating fresh room anchors")
		scene_manager.remove_scene_anchors()

	var create_error: Error = scene_manager.create_scene_anchors()
	if create_error != OK:
		_finish_scene_refresh_without_room()
		return

func _on_current_room_changed(previous_room_id: String, current_room_id: String) -> void:
	if ignore_room_change_refresh:
		if current_room_id.is_empty():
			return

		ignore_room_change_refresh = false
		return

	if not previous_room_id.is_empty() and current_room_id.is_empty():
		room_switch_pending_refresh = true
		return

	if room_switch_pending_refresh and not current_room_id.is_empty():
		room_switch_pending_refresh = false
		refresh_current_room("Room changed - rebuilding scene data")

func _on_room_loaded(_room_id: String) -> void:
	scene_refresh_in_progress = false
	allow_scene_capture_on_missing = false
	ignore_room_change_refresh = false

	var should_auto_capture: bool = _should_auto_capture_after_refresh(_room_id)
	_clear_auto_room_check()

	if should_auto_capture:
		_request_auto_scene_capture("Detected movement away from room %s" % _room_id)
		return

	_remember_current_position()

func _request_scene_capture(reason: String) -> void:
	if scene_capture_requested:
		return

	if not scene_manager.is_scene_capture_supported():
		return

	scene_capture_requested = true

	# print(reason)
	if not scene_manager.request_scene_capture(reason):
		scene_capture_requested = false

func _on_scene_data_missing():
	var should_request_capture: bool = allow_scene_capture_on_missing
	_finish_scene_refresh_without_room()

	if should_request_capture:
		_request_scene_capture("Scene data missing - please scan this room")

func _on_scene_capture_completed(success: bool):
	scene_capture_requested = false

	if not success:
		allow_scene_capture_on_missing = false
		ignore_room_change_refresh = false
		# print("Scene capture failed")
		return

	refresh_current_room("Scene capture completed", false)

func _remember_current_position() -> void:
	if xr_camera == null:
		return

	last_room_origin = xr_camera.global_position
	has_last_room_origin = true

func _finish_scene_refresh_without_room() -> void:
	scene_refresh_in_progress = false
	allow_scene_capture_on_missing = false
	ignore_room_change_refresh = false
	_clear_auto_room_check()

func _begin_auto_room_verification(reason: String) -> void:
	if room_manager == null:
		return

	auto_room_check_pending = not room_manager.current_room_id.is_empty()
	auto_room_check_previous_room_id = room_manager.current_room_id
	auto_room_check_previous_room_origin = last_room_origin
	auto_room_check_has_previous_room_origin = has_last_room_origin
	refresh_current_room(reason)

func _should_auto_capture_after_refresh(room_id: String) -> bool:
	if not auto_room_check_pending:
		return false

	if auto_room_check_previous_room_id.is_empty():
		return false

	if room_id != auto_room_check_previous_room_id:
		return false

	if xr_camera == null or not auto_room_check_has_previous_room_origin:
		return false

	if _room_distance(xr_camera.global_position, auto_room_check_previous_room_origin) < AUTO_ROOM_SCAN_MOVE_THRESHOLD:
		return false

	return _can_request_auto_scene_capture()

func _can_request_auto_scene_capture() -> bool:
	if not scene_manager.is_scene_capture_supported():
		return false

	if auto_room_capture_cooldown_elapsed < AUTO_ROOM_CAPTURE_COOLDOWN_SEC:
		return false

	if xr_camera == null:
		return false

	if has_last_auto_capture_origin:
		var is_near_last_auto_capture: bool = _room_distance(
			xr_camera.global_position,
			last_auto_capture_origin
		) < AUTO_ROOM_CAPTURE_RETRY_DISTANCE
		var same_room_probe: bool = room_manager != null and room_manager.current_room_id == last_auto_capture_room_id
		if is_near_last_auto_capture and same_room_probe:
			return false

	return true

func _request_auto_scene_capture(reason: String) -> void:
	if xr_camera != null:
		last_auto_capture_origin = xr_camera.global_position
		has_last_auto_capture_origin = true

	last_auto_capture_room_id = ""
	if room_manager != null:
		last_auto_capture_room_id = room_manager.current_room_id

	auto_room_capture_cooldown_elapsed = 0.0
	force_scene_capture(reason)

func _clear_auto_room_check() -> void:
	auto_room_check_pending = false
	auto_room_check_previous_room_id = ""
	auto_room_check_previous_room_origin = Vector3.ZERO
	auto_room_check_has_previous_room_origin = false

func _room_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
