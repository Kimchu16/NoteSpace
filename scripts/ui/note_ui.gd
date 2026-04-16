extends CanvasLayer

@onready var note_label : TextEdit = $Control/Panel/MarginContainer/TextEdit
@onready var sub_viewport : SubViewport
@onready var tag_container: HFlowContainer = $Control/Panel/HFlowContainer

var is_editing = false

# Set initial content
func set_note_content(content: String) -> void:
	note_label.text = content

# Get current content
func get_note_content() -> String:
	return note_label.text

func focus_note():
	var keyboard := get_tree().get_first_node_in_group("Keyboard")
	if not keyboard:
		print("No keyboard found!")
		return
	
	var keyboard_script := keyboard.get_node("Viewport/VirtualKeyboard2D")
	if not keyboard_script:
		print("Could not find VirtualKeyboard2D inside keyboard")
		return
	
	# Assign this note's SubViewport as the target
	keyboard_script.target_viewport = get_parent()

	keyboard.visible = true

func _edit_note():
	is_editing = !is_editing
	note_label.editable = is_editing

	if is_editing:
		note_label.grab_focus()
		focus_note()
		$Control/Panel.border_color =  Color8(67, 194, 240)

	else:
		note_label.release_focus()
		$Control/Panel.border_color =  Color8(255, 255, 128) 
		var keyboard := get_tree().get_first_node_in_group("Keyboard")
		if keyboard:
			keyboard.visible = false
		
		# Save content when done editing
		var note_3d = get_parent().get_parent()  # Navigate up to Note3D
		if note_3d.has_method("save_content"):
			note_3d.save_content(note_label.text)
		else:
			printerr("save_content not found.")

func update_tags_for_note(note_id: int):
	var tags = await NotesService.load_tags_for_note(note_id)
	for child in tag_container.get_children():
		child.queue_free()
	
	for tag in tags:
		var tag_instance = load("res://scenes/ui/tags/menu_tag.tscn").instantiate()
		var tag_label = tag_instance.get_node("Label")
		tag_label.text = tag.tag_name
		tag_container.add_child(tag_instance)
