extends Node3D

var xr_interface: XRInterface

@export var xr_origin: Node3D
@export var right_controller: XRController3D

var spatial_anchor_manager: OpenXRFbSpatialAnchorManager
const SPATIAL_ANCHORS_FILE = "user://spatial_anchors.json"
var note_scene = preload("res://scenes/notes/note3D.tscn")
var loaded_anchor_uuids: Array = []

var anchor_data: Dictionary

func _ready():
	xr_interface = XRServer.find_interface("OpenXR")
	spatial_anchor_manager =  get_tree().get_nodes_in_group("Managers")[1]
	spatial_anchor_manager.connect("openxr_fb_spatial_anchor_tracked", _on_anchor_tracked)
	AuthManager.login_success.connect(_on_login_success)
	AuthManager.logout_success.connect(_on_logout)
	
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
	#load_anchors_from_file()
	print("XR ready, waiting for auth...")

func load_anchors_from_file() -> void:
	var file := FileAccess.open(SPATIAL_ANCHORS_FILE, FileAccess.READ)
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
			spatial_anchor_manager.load_anchor(uuid)
			loaded_anchor_uuids.append(uuid)

func _on_anchor_tracked(anchor_node: Object, spatial_entity: Object, is_new: bool) -> void:
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
	load_anchors_from_file()

func _on_logout():
	print("User logged out")
	_clear_notes_and_anchors()

func _clear_notes_and_anchors():
	for child in get_children():
		if child is Note3D:
			child.queue_free()
		
	for uuid in loaded_anchor_uuids:
		var anchor_node = spatial_anchor_manager.get_anchor_node(uuid)
		if anchor_node:
			anchor_node.queue_free()
	
	loaded_anchor_uuids.clear()
