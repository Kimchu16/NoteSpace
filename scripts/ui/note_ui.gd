extends CanvasLayer

@onready var note_label : TextEdit = $Control/ColorRect/MarginContainer/TextEdit
@onready var sub_viewport : SubViewport

var is_editing = false

func focus_note():
	var keyboard := get_tree().get_first_node_in_group("Keyboard")
	if not keyboard:
		print("No keyboard found!")
		return
	
	var keyboard_script := keyboard.get_node("Viewport/VirtualKeyboard2D2")
	if not keyboard_script:
		print("Could not find VirtualKeyboard2D2 inside keyboard")
		return
	
	# Assign this note's SubViewport as the target
	keyboard_script.target_viewport = get_parent()

	keyboard.visible = true

func _edit_note():
	#print("Edit note function called")
	is_editing = !is_editing
	note_label.editable = is_editing

	if is_editing:
		note_label.grab_focus()
		focus_note()
		#print("Is editing")
	else:
		note_label.release_focus()
		var keyboard := get_tree().get_first_node_in_group("Keyboard")
		if keyboard:
			keyboard.visible = false
		#print("Is not editing")
