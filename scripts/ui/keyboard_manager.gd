extends Node

var current_focused_input: Control = null

func focus_input(target_control: Control, ui_panel: Node3D):
	# print("target control:", target_control)

	# prevent duplicate focus
	if current_focused_input == target_control:
		return

	current_focused_input = target_control

	var keyboard: Node3D = get_tree().get_first_node_in_group("Keyboard")
	if not keyboard:
		# print("No keyboard found!")
		return
	
	var keyboard_script = keyboard.get_node("Viewport/VirtualKeyboard2D")
	if not keyboard_script:
		# print("Could not find VirtualKeyboard2D")
		return
	
	keyboard_script.target_viewport = _resolve_target_viewport(target_control)
	
	if ui_panel:
		var panel_transform: Transform3D = ui_panel.global_transform
		var panel_basis: Basis = panel_transform.basis.orthonormalized()
		var offset_down: Vector3 = -panel_basis.y * 0.3
		var offset_forward: Vector3 = panel_basis.z * 0.08
		keyboard.global_transform.origin = panel_transform.origin + offset_down + offset_forward
		keyboard.global_transform.basis = panel_basis
		# print("Keyboard positioned at: ", keyboard.global_transform.origin, " using ui_panel: ", ui_panel.name)
	
	keyboard.visible = true

func unfocus_input():
	var keyboard: Node3D = get_tree().get_first_node_in_group("Keyboard")
	if keyboard:
		keyboard.visible = false
	
	current_focused_input = null

func _resolve_target_viewport(target_control: Control) -> Viewport:
	var current: Node = target_control
	while current != null:
		if current is SubViewport:
			return current as Viewport
		current = current.get_parent()
	
	return target_control.get_viewport()
