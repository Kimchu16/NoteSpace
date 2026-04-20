extends Node3D

var xr_interface: XRInterface

@export var xr_origin: Node3D
@export var right_controller: XRController3D

@onready var login_ui = get_node("LoginUI")
@onready var main_ui = get_node("MainInterface")

var spatial_anchor_manager: OpenXRFbSpatialAnchorManager
var room_manager: RoomManager
var note_scene = preload("res://scenes/notes/note3D.tscn")
var loaded_anchor_uuids: Array[String] = []
var current_room_anchor_data: Dictionary = {}
var xr_ready = false
var auth_ready = false

func _ready():
	AuthManager.auth_checked.connect(_on_auth_checked)
	AuthManager.login_success.connect(_on_login_success)
	AuthManager.logout_success.connect(_on_logout)
	xr_interface = XRServer.find_interface("OpenXR")
	spatial_anchor_manager = get_node("XROrigin3D/OpenXRFbSpatialAnchorManager")
	room_manager = get_tree().get_first_node_in_group("RoomManager")
	spatial_anchor_manager.connect("openxr_fb_spatial_anchor_tracked", _on_anchor_tracked)
	spatial_anchor_manager.connect("openxr_fb_spatial_anchor_load_failed", _on_anchor_load_failed)

	if room_manager:
		room_manager.room_loaded.connect(_on_room_loaded)
		room_manager.room_unloading.connect(_on_room_unloading)
	
	if xr_interface and xr_interface.is_initialized():
		# print("OpenXR initialized successfully")
		xr_interface.session_begun.connect(_on_openxr_session_begun)

		# Turn off v-sync!
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

		# Change our main viewport to output to the HMD
		get_viewport().use_xr = true
		enable_passthrough()
	else:
		# print("OpenXR not initialized, please check if your headset is connected")
		pass

@onready var viewport : Viewport = get_viewport()
@onready var environment : Environment = $WorldEnvironment.environment

func enable_passthrough() -> bool:
	if xr_interface:
		var modes = xr_interface.get_supported_environment_blend_modes()
		if XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes:
			xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
			viewport.transparent_bg = true
		elif XRInterface.XR_ENV_BLEND_MODE_ADDITIVE in modes:
			xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ADDITIVE
			viewport.transparent_bg = false
	else:
		return false

	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	return true

func _on_openxr_session_begun() -> void:
	# print("XR ready, waiting for auth...")
	xr_ready = true
	_try_load()

func _load_room_anchors(room_id: String) -> void:
	if not xr_ready or not auth_ready or room_manager == null:
		return

	var current_user_id: String = str(AuthManager.current_user.id)
	current_room_anchor_data = room_manager.get_room_note_map(room_id, current_user_id)
	loaded_anchor_uuids.clear()

	for uuid in current_room_anchor_data.keys():
		var existing = spatial_anchor_manager.get_anchor_node(uuid)
		if existing:
			_force_attach_note(uuid)
			continue

		# print("Loading anchor:", uuid, " for room: ", room_id)
		spatial_anchor_manager.load_anchor(uuid)
		loaded_anchor_uuids.append(uuid)

func _on_anchor_tracked(anchor_node: Object, spatial_entity: Object, is_new: bool) -> void:
	if spatial_entity == null:
		return

	var anchor_uuid: String = str(spatial_entity.uuid)
	# print("TRACKED:", anchor_uuid)

	if is_new:
		var custom_data: Dictionary = spatial_entity.get_custom_data()
		if room_manager and str(custom_data.get("room_id", "")) == room_manager.current_room_id:
			current_room_anchor_data[anchor_uuid] = custom_data.duplicate(true)
		return

	if room_manager:
		room_manager.maybe_switch_room_for_anchor(anchor_uuid)

	if not current_room_anchor_data.has(anchor_uuid):
		return

	var anchor_node_3d = spatial_anchor_manager.get_anchor_node(anchor_uuid)
	if not anchor_node_3d:
		return

	await _attach_note_to_anchor(anchor_node_3d, anchor_uuid)

func _on_anchor_load_failed(uuid: StringName, _custom_data: Dictionary, _location: int) -> void:
	if not current_room_anchor_data.has(str(uuid)):
		return

	printerr("Failed to load saved spatial anchor: ", uuid)

func _attach_note_to_anchor(anchor_node: Node, anchor_uuid: String) -> void:
	if not is_instance_valid(anchor_node):
		return

	for child in anchor_node.get_children():
		if child is Note3D:
			# print("Note already exists on anchor, skipping:", anchor_uuid)
			return

	var data = current_room_anchor_data.get(anchor_uuid, {})
	if data.is_empty():
		# print("No room anchor data for:", anchor_uuid)
		return

	var current_user_id: String = str(AuthManager.current_user.id)
	if str(data.get("owner", "")) != current_user_id:
		return

	var note_id: int = int(data.get("note_id", -1))
	if note_id == -1:
		return

	var model = await NotesService.get_note_by_id(note_id)
	if model == null:
		return

	var note: Note3D = note_scene.instantiate()
	anchor_node.add_child(note)
	note.anchor_uuid = anchor_uuid
	note.position = Vector3.ZERO
	note.rotation = Vector3.ZERO
	note.set_note_data(model)
	note.update_tags_for_note(model.id)
	note.anchored = true
	setup_note(note)

	var main_interface_ui = get_tree().get_first_node_in_group("MainInterfaceUI")
	if main_interface_ui:
		main_interface_ui.register_note(note)

func setup_note(note: Note3D) -> void:
	var main_interface_UI = get_tree().get_first_node_in_group("MainInterfaceUI")
	if main_interface_UI:
		note.returned_to_main_interface.connect(main_interface_UI._on_note_returned_to_main_interface)

func _on_login_success(user):
	# print("User logged in: ", user.email)
	pass

func _on_logout():
	# print("User logged out")
	login_ui.visible = true
	main_ui.visible = false
	if room_manager:
		room_manager.unload_current_room()

func _clear_loaded_room_notes() -> void:
	var anchor_uuids: Array = current_room_anchor_data.keys()
	for uuid in loaded_anchor_uuids:
		if not anchor_uuids.has(uuid):
			anchor_uuids.append(uuid)

	var main_interface_ui = get_tree().get_first_node_in_group("MainInterfaceUI")

	for uuid in anchor_uuids:
		var anchor_node = spatial_anchor_manager.get_anchor_node(uuid)
		if not anchor_node:
			continue

		for child in anchor_node.get_children():
			if child is Note3D:
				if main_interface_ui:
					main_interface_ui.unregister_loaded_note(child)
				child.queue_free()

	loaded_anchor_uuids.clear()
	current_room_anchor_data.clear()

func _on_auth_checked(is_logged_in: bool):
	# print("AUTH CHECKED SIGNAL FIRED ->", is_logged_in)
	if is_logged_in:
		login_ui.visible = false
		main_ui.visible = true
		auth_ready = true
		# print("xr_ready: ", xr_ready, " || auth_ready: ", auth_ready)
		_try_load()
	else:
		main_ui.visible = false
		
		if AuthManager.pending_email_confirmation:
			# print("Pending email confirmation -> do not force login UI reset")
			return
			
		login_ui.visible = true

func _try_load():
	if xr_ready and auth_ready and room_manager and not room_manager.current_room_id.is_empty():
		_load_room_anchors(room_manager.current_room_id)

func _on_room_loaded(room_id: String) -> void:
	await _load_room_anchors(room_id)

func _on_room_unloading(_room_id: String) -> void:
	_clear_loaded_room_notes()

func _force_attach_note(uuid: String) -> void:
	await get_tree().create_timer(0.2).timeout
	var anchor_node = spatial_anchor_manager.get_anchor_node(uuid)
	
	if not anchor_node:
		# print("Anchor not ready yet:", uuid)
		return

	await _attach_note_to_anchor(anchor_node, uuid)
