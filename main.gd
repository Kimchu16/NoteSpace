extends Node3D

var xr_interface: XRInterface

@export var xr_origin: Node3D
@export var right_controller: XRController3D

@onready var login_ui = get_node("LoginUI")
@onready var main_ui = get_node("MainInterface")

var spatial_anchor_manager: OpenXRFbSpatialAnchorManager
const SPATIAL_ANCHORS_FILE = "user://spatial_anchors.json"
var note_scene = preload("res://scenes/notes/note3D.tscn")
var loaded_anchor_uuids: Array = []
var anchor_data: Dictionary
var xr_ready = false
var auth_ready = false

func _ready():
	AuthManager.auth_checked.connect(_on_auth_checked)
	AuthManager.login_success.connect(_on_login_success)
	AuthManager.logout_success.connect(_on_logout)
	xr_interface = XRServer.find_interface("OpenXR")
	spatial_anchor_manager =  get_tree().get_nodes_in_group("Managers")[1]
	spatial_anchor_manager.connect("openxr_fb_spatial_anchor_tracked", _on_anchor_tracked)
	
	if xr_interface and xr_interface.is_initialized():
		print("OpenXR initialized successfully")
		xr_interface.session_begun.connect(_on_openxr_session_begun)

		# Turn off v-sync!
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

		# Change our main viewport to output to the HMD
		get_viewport().use_xr = true
		enable_passthrough()
	else:
		print("OpenXR not initialized, please check if your headset is connected")

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
	print("XR ready, waiting for auth...")
	xr_ready = true
	_try_load()

func load_anchors_from_file() -> void:
	var file := FileAccess.open(SPATIAL_ANCHORS_FILE, FileAccess.READ)
	var current_user_id = AuthManager.current_user.id
	print(ProjectSettings.globalize_path(SPATIAL_ANCHORS_FILE))

	if not file:
		print("No file to load in anchors.")
		return
	
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		print("ERROR: Unable to parse ", SPATIAL_ANCHORS_FILE)
		pass
	else:
		anchor_data = json.data
	
	print("Anchor data loading: ", anchor_data)
	print("Anchor data size: ", anchor_data.size())
	
	if anchor_data.size() > 0:
		print("Anchor load")
		for uuid in anchor_data.keys():
			var data = anchor_data[uuid]
			if not data.has("owner") or data["owner"] != current_user_id:
				continue

			print("Loading anchor for current user:", uuid)
			var existing = spatial_anchor_manager.get_anchor_node(uuid)
			
			if existing:
				print("Anchor already exists:", uuid)
				_force_attach_note(uuid)
			else:
				print("Loading anchor:", uuid)
				spatial_anchor_manager.load_anchor(uuid)
				loaded_anchor_uuids.append(uuid)

func _on_anchor_tracked(anchor_node: Object, spatial_entity: Object, is_new: bool) -> void:
	print("TRACKED:", spatial_entity.uuid)
	if !is_new:
		# Anchor reloaded
		print("Anchor reload tracked successfully.")
		var note: Note3D
		
		if spatial_entity:
			# Get the corresponding XRAnchor3D node for the spatial entity
			anchor_node = spatial_anchor_manager.get_anchor_node(spatial_entity.uuid)  # Get the XRAnchor3D node
			#print("SE custom data: ", anchor_data[spatial_entity.uuid]["note_id"])
			var note_id = anchor_data[spatial_entity.uuid]["note_id"]
			var model = await NotesService.get_note_by_id(note_id)
			
			note = note_scene.instantiate()
			anchor_node.add_child(note)
			note.anchor_uuid = spatial_entity.uuid
		
			# Set position
			note.position = Vector3.ZERO
			note.rotation = Vector3.ZERO
			
			# Set the note data
			note.set_note_data(model)
			note.update_tags_for_note(model.id)
			print("Load note id: ", note.note_model.id, " | node name: ", note.name)
			note.anchored = true
			setup_note(note)
			
			var main_interface_ui = get_tree().get_first_node_in_group("MainInterfaceUI")
			main_interface_ui.register_note(note)

func setup_note(note: Note3D) -> void:
	var main_interface_UI = get_tree().get_first_node_in_group("MainInterfaceUI")
	if main_interface_UI:
		note.returned_to_main_interface.connect(main_interface_UI._on_note_returned_to_main_interface)

func _on_login_success(user):
	print("User logged in: ", user.email)

func _on_logout():
	print("User logged out")
	login_ui.visible = true
	main_ui.visible = false
	_clear_user_notes()

func _clear_user_notes():
	print("---- CLEAR USER NOTES START ----")
	
	if anchor_data == null:
		print("anchor_data is NULL")
		return
	
	print("Anchor data keys:", anchor_data.keys())
	
	for uuid in anchor_data.keys():
		var anchor_node = spatial_anchor_manager.get_anchor_node(uuid)
		
		print("Anchor node found:", anchor_node.name)
		print("Children count:", anchor_node.get_child_count())
		
		if not anchor_node:
			print("No anchor node found for:", uuid)
			continue
			
		for child in anchor_node.get_children():
			if child is Note3D:
				print("Removing Note3D:", child.name)
				child.queue_free()
	
	loaded_anchor_uuids.clear()

func _on_auth_checked(is_logged_in: bool):
	print("AUTH CHECKED SIGNAL FIRED ->", is_logged_in)
	if is_logged_in:
		login_ui.visible = false
		main_ui.visible = true
		auth_ready = true
		print("xr_ready: ", xr_ready, " || auth_ready: ", auth_ready)
		_try_load()
	else:
		main_ui.visible = false
		
		if AuthManager.pending_email_confirmation:
			print("Pending email confirmation -> do not force login UI reset")
			return
			
		login_ui.visible = true

func _try_load():
	if xr_ready and auth_ready:
		load_anchors_from_file()

func _force_attach_note(uuid):
	await get_tree().create_timer(0.2).timeout
	var anchor_node = spatial_anchor_manager.get_anchor_node(uuid)
	
	if not anchor_node:
		print("Anchor not ready yet:", uuid)
		return
		
	# Prevent duplicates
	var has_note := false
	
	for child in anchor_node.get_children():
		if child is Note3D:
			has_note = true
			break
			
	if has_note:
		print("Note already exists on anchor, skipping:", uuid)
		return
	
	var data = anchor_data.get(uuid, null)
	if data == null:
		print("No anchor data for:", uuid)
		return
	
	var current_user_id = AuthManager.current_user.id
	if data.get("owner", "") != current_user_id:
		return
	
	var note_id = anchor_data[uuid]["note_id"]
	var model = await NotesService.get_note_by_id(note_id)
	
	var note = note_scene.instantiate()
	anchor_node.add_child(note)
	
	note.anchor_uuid = uuid
	note.position = Vector3.ZERO
	note.rotation = Vector3.ZERO
	note.set_note_data(model)
	note.anchored = true
	
	setup_note(note)
	
	print("FORCED ATTACH:", note.note_model.id)
