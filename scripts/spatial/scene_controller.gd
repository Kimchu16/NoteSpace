extends Node

@onready var scene_manager: OpenXRFbSceneManager
@onready var spatial_anchor_manager : OpenXRFbSpatialAnchorManager

func _ready():
	scene_manager = get_tree().get_nodes_in_group("Managers")[0]
	spatial_anchor_manager = get_tree().get_nodes_in_group("Managers")[1]
	scene_manager.openxr_fb_scene_data_missing.connect(_on_scene_data_missing)
	scene_manager.openxr_fb_scene_capture_completed.connect(_on_scene_capture_completed)
	
	#print("Managers: ", get_tree().get_nodes_in_group("Managers"))

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
	
	var anchor_uuids = scene_manager.get_anchor_uuids()
	for uuid in anchor_uuids:
		print("Anchor UUID: ", uuid)
