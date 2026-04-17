extends CanvasLayer

@onready var note_label : TextEdit = $Control/Panel/MarginContainer/TextEdit
@onready var note_panel: Panel = $Control/Panel
@onready var sub_viewport : SubViewport
@onready var tag_container: HFlowContainer = $Control/Panel/HFlowContainer

var is_editing = false
var saved_border_colour: Color = Color8(255, 255, 128)

# Set initial content
func set_note_content(content: String) -> void:
	note_label.text = content

# Get current content
func get_note_content() -> String:
	return note_label.text

func focus_note():
	var note_owner := _find_note_owner() as Node3D
	KeyboardManager.focus_input(note_label, note_owner)

func _edit_note():
	is_editing = !is_editing
	note_label.editable = is_editing

	if is_editing:
		_cache_current_border_colour()
		note_label.grab_focus()
		focus_note()
		_set_panel_border_colour(Color8(67, 194, 240))

	else:
		note_label.release_focus()
		_set_panel_border_colour(saved_border_colour)
		KeyboardManager.unfocus_input()
		
		# Save content when done editing
		var note_3d = _find_note_owner()
		if note_3d.has_method("save_content"):
			note_3d.save_content(note_label.text)
		else:
			printerr("save_content not found.")

func update_tags_for_note(note_id: int):
	print("update tags for note 3d called")
	var tags = await NotesService.load_tags_for_note(note_id)
	for child in tag_container.get_children():
		child.queue_free()
	
	for tag in tags:
		var tag_instance = load("res://scenes/ui/tags/tag.tscn").instantiate()
		print("3d Tag instance children: ", tag_instance.get_children())
		var tag_label = tag_instance.get_node("Label")
		tag_label.text = tag.tag_name
		tag_container.add_child(tag_instance)
		print("Loaded tags for 3d note ", note_id, ": ", tags)

func _cache_current_border_colour() -> void:
	var panel_stylebox := note_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if panel_stylebox == null:
		return
	
	saved_border_colour = panel_stylebox.border_color

func _set_panel_border_colour(border_colour: Color) -> void:
	var panel_stylebox := note_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if panel_stylebox == null:
		return
	
	var updated_stylebox := panel_stylebox.duplicate() as StyleBoxFlat
	if updated_stylebox == null:
		return
	
	updated_stylebox.border_color = border_colour
	note_panel.add_theme_stylebox_override("panel", updated_stylebox)

func _find_note_owner() -> Node:
	var current: Node = self
	while current != null:
		if current.has_method("save_content"):
			return current
		current = current.get_parent()
	return self
