extends CanvasLayer

@onready var delete_menu = $Control/ColorRect/MarginContainer/HBoxContainer/Button2/PanelContainer
@onready var edit_tags_menu = $Control/ColorRect/MarginContainer/HBoxContainer/Button3/PanelContainer
@onready var add_tags_list = $Control/ColorRect/MarginContainer/HBoxContainer/Button3/PanelContainer/HBoxContainer/AddList/MarginContainer5/ScrollContainer/TagList
@onready var remove_tags_list = $Control/ColorRect/MarginContainer/HBoxContainer/Button3/PanelContainer/HBoxContainer/RemoveList/MarginContainer5/ScrollContainer/TagList

signal edit_button
signal delete_button
signal send_to_main_interface

var note_id: int = -1

func _on_button_pressed():
	#print("Edit button pressed in toolbar UI:", self)
	#print("Forwarding to:", get_parent().get_parent().get_parent())
	
	# Viewport2Din3D creates a canvasLayer clone on runtime so to get to Toolbar in the heigharchy
	# which has the signal as it does not get cloned, get_parent is called 3 times
	get_parent().get_parent().get_parent().emit_signal("edit_button")

func _on_del_btn_pressed():
	delete_menu.visible = !delete_menu.visible

func _on_perma_del_pressed():
	emit_signal("delete_button")

func _send_to_main_interface():
	print("Send back to main interface.")
	emit_signal("send_to_main_interface")
	#print("Emitted from:", get_instance_id())

func _on_edit_tags_pressed() -> void:
	edit_tags_menu.visible = !edit_tags_menu.visible
	
	if edit_tags_menu.visible == true:
		var id = _resolve_note_id()
		if id == -1:
			printerr("Toolbar_UI could not resolve note_id.")
			return
		note_id = id
		update_tags_for_note(note_id)

func get_note_id(id: int) -> void:
	note_id = id
	print("note id obtained: ", id, "|| saved note_id: ", note_id, " || toolbar ui id: ", get_instance_id())

func _resolve_note_id() -> int:
	if note_id != -1:
		return note_id

	var current: Node = self
	while current != null:
		if current is Note3D:
			var owner_note: Note3D = current
			if owner_note.note_model:
				return owner_note.note_model.id
			return -1
		current = current.get_parent()

	return -1

func update_tags_for_note(id: int):
	print("update tags for note 3d MANAGEMENT called: ", id, " || Saved note_id: ", note_id, " || toolbar ui id: ", get_instance_id())
	# Add Tags list --------------------------------------------
	var tags = await NotesService.load_tags_for_note(id)
	for child in add_tags_list.get_children():
		child.queue_free()
	
	var attached_tag_ids: Dictionary = {}
	for tag in tags:
		var tag_instance = load("res://scenes/ui/tags/note_tag.tscn").instantiate()
		print("3d Tag instance children: ", tag_instance.get_children())
		tag_instance.text = tag.tag_name
		add_tags_list.add_child(tag_instance)
		attached_tag_ids[tag.tag_id] = true
		print("Loaded tags for 3d note ", id, ": ", tags)
		
	# Remove Tags list --------------------------------------------
	for child in remove_tags_list.get_children():
		child.queue_free()
		
	var user_tags = await TagsService.get_user_tags()
	for tag in user_tags:
		if attached_tag_ids.has(tag.tag_id):
			continue
		var tag_instance = load("res://scenes/ui/tags/note_tag.tscn").instantiate()
		tag_instance.text = tag.tag_name
		remove_tags_list.add_child(tag_instance)
