extends Node3D

var xr_interface: XRInterface

@export var xr_origin: Node3D
@export var right_controller: XRController3D

var spatial_anchor_manager: OpenXRFbSpatialAnchorManager
const SPATIAL_ANCHORS_FILE = "user://openxr_fb_spatial_anchors.json"

func _ready():
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
	load_anchors_from_file()

func load_anchors_from_file() -> void:
	var file := FileAccess.open(SPATIAL_ANCHORS_FILE, FileAccess.READ)
	if not file:
		return
	
	var json := JSON.new()
	var anchor_data: Array
	if json.parse(file.get_as_text()) != OK:
		print("ERROR: Unable to parse ", SPATIAL_ANCHORS_FILE)
		pass
	else:
		anchor_data = json.data
	
	print("Anchor data loading: ", anchor_data)
	print("Anchor data size: ", anchor_data.size())
	if anchor_data.size() > 0:
		print("Anchor load")
		for anchor in anchor_data:
			spatial_anchor_manager.load_anchor(anchor)

func _on_anchor_tracked(anchor_node: Object, spatial_entity: Object, is_new: bool) -> void:
	print("SE: ", spatial_entity)
