extends Node

@onready var scene_manager: OpenXRFbSceneManager = $"../../XROrigin3D/OpenXRFbSceneManager"

func _ready():
	scene_manager.openxr_fb_scene_data_missing.connect(_on_scene_data_missing)
	scene_manager.openxr_fb_scene_capture_completed.connect(_on_scene_capture_completed)

func _on_scene_data_missing():
	print("Scene data missing - requesting capture")
	scene_manager.request_scene_capture()

func _on_scene_capture_completed(success: bool):
	if not success:
		print("Scene capture failed")
		return

	print("Scene capture completed")

	if scene_manager.are_scene_anchors_created():
		scene_manager.remove_scene_anchors()

	scene_manager.create_scene_anchors()
