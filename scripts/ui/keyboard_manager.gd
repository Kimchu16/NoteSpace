extends Node

var current_focused_input: Control = null

func focus_input(target_control: Control, ui_panel: Node3D):
	print("target control:", target_control)

	# prevent duplicate focus
	if current_focused_input == target_control:
		return

	current_focused_input = target_control

	var keyboard := get_tree().get_first_node_in_group("Keyboard")
	if not keyboard:
		print("No keyboard found!")
		return
	
	var keyboard_script := keyboard.get_node("Viewport/VirtualKeyboard2D")
	if not keyboard_script:
		print("Could not find VirtualKeyboard2D")
		return
	
	keyboard_script.target_viewport = target_control.get_viewport()
	
	if ui_panel:
		var offset_down = Vector3(0, -0.25, 0)
		keyboard.global_transform.origin = ui_panel.global_transform.origin + offset_down
		keyboard.global_transform.basis = ui_panel.global_transform.basis
	
	keyboard.visible = true

func unfocus_input():
	var keyboard := get_tree().get_first_node_in_group("Keyboard")
	if keyboard:
		keyboard.visible = false
	
	current_focused_input = null
