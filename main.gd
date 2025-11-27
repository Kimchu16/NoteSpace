extends Node3D

var xr_interface: XRInterface

@onready var right_ray: RayCast3D = $XROrigin3D/RightController/RayCast3D

@onready var ui := $MainInterface/SubViewport/MainInterface_UI
@onready var create_button := $MainInterface/SubViewport/MainInterface_UI/Control/ColorRect/MarginContainer/VBoxContainer/Button
@export var xr_origin: Node3D

func _ready():
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		print("OpenXR initialized successfully")

		# Turn off v-sync!
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

		# Change our main viewport to output to the HMD
		get_viewport().use_xr = true
		enable_passthrough()
	else:
		print("OpenXR not initialized, please check if your headset is connected")
	
	# Ensure rays start disabled
	right_ray.enabled = false
	
	create_button.pressed.connect(_on_create_note_pressed)

func _on_create_note_pressed():
	var note := preload("res://note3D.tscn").instantiate()
	xr_origin.add_child(note)

	var hmd = XRServer.get_hmd_transform()
	var forward = -hmd.basis.z
	note.global_position = hmd.origin + forward * 1.0

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

func _on_right_controller_button_pressed(name: String) -> void:
	if name == "index_pinch":
		right_ray.enabled = true

func _on_right_controller_button_released(name: String) -> void:
	if name == "index_pinch":
		right_ray.enabled = false
