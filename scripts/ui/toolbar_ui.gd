extends CanvasLayer

@onready var delete_menu = $Control/ColorRect/MarginContainer/HBoxContainer/Button2/PanelContainer
@onready var edit_tags_menu = $Control/ColorRect/MarginContainer/HBoxContainer/Button3/PanelContainer
@onready var add_tags_list = $Control/ColorRect/MarginContainer/HBoxContainer/Button3/PanelContainer/HBoxContainer/AddList/MarginContainer5/ScrollContainer/TagList
@onready var remove_tags_list = $Control/ColorRect/MarginContainer/HBoxContainer/Button3/PanelContainer/HBoxContainer/RemoveList/MarginContainer5/ScrollContainer/TagList
@onready var note_tag_scene = preload("res://scenes/ui/tags/note_tag.tscn")

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
	# print("Send back to main interface.")
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
	# print("note id obtained: ", id, "|| saved note_id: ", note_id, " || toolbar ui id: ", get_instance_id())

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
	# print("update tags for note 3d MANAGEMENT called: ", id, " || Saved note_id: ", note_id, " || toolbar ui id: ", get_instance_id())
	# Add Tags list --------------------------------------------
	var attached_tags = await NotesService.load_tags_for_note(id)
	for child in add_tags_list.get_children():
		child.queue_free()
	
	var attached_tag_ids: Dictionary = {}
	for tag in attached_tags:
		var tag_instance: Button = _create_manage_tag_item(tag, true)
		add_tags_list.add_child(tag_instance)
		attached_tag_ids[tag.tag_id] = true
		# print("Loaded attached tag for 3d note ", id, ": ", tag.tag_name)
		
	# Remove Tags list --------------------------------------------
	for child in remove_tags_list.get_children():
		child.queue_free()

	var user_tags = await TagsService.get_user_tags()
	for tag in user_tags:
		if attached_tag_ids.has(tag.tag_id):
			continue
		var tag_instance: Button = _create_manage_tag_item(tag, false)
		remove_tags_list.add_child(tag_instance)

func _create_manage_tag_item(tag: TagModel, is_attached: bool) -> Button:
	var tag_instance: Button = note_tag_scene.instantiate()
	var delete_btn: Button = tag_instance.get_node("DeleteBtn")
	var add_btn: Button = tag_instance.get_node("CreateBtn")

	tag_instance.text = tag.tag_name
	tag_instance.set_meta("tag_model", tag)
	tag_instance.set_meta("is_attached", is_attached)
	delete_btn.visible = false
	add_btn.visible = false

	tag_instance.pressed.connect(func():
		_on_manage_tag_row_pressed(tag_instance)
	)

	delete_btn.pressed.connect(func():
		_on_remove_tag_pressed(tag)
	)

	add_btn.pressed.connect(func():
		_on_add_tag_pressed(tag)
	)

	return tag_instance

func _on_manage_tag_row_pressed(tag_instance: Button) -> void:
	_hide_all_action_buttons()
	var delete_btn: Button = tag_instance.get_node("DeleteBtn")
	var add_btn: Button = tag_instance.get_node("CreateBtn")
	var is_attached: bool = tag_instance.get_meta("is_attached", false)
	
	if is_attached:
		delete_btn.visible = true
		add_btn.visible = false
	else:
		delete_btn.visible = false
		add_btn.visible = true

func _hide_all_action_buttons() -> void:
	for row in add_tags_list.get_children():
		if row.has_node("DeleteBtn"):
			row.get_node("DeleteBtn").visible = false
		if row.has_node("CreateBtn"):
			row.get_node("CreateBtn").visible = false
	for row in remove_tags_list.get_children():
		if row.has_node("DeleteBtn"):
			row.get_node("DeleteBtn").visible = false
		if row.has_node("CreateBtn"):
			row.get_node("CreateBtn").visible = false

func _on_add_tag_pressed(tag: TagModel) -> void:
	if note_id == -1:
		return
	var success = await NotesService.add_tags_to_note(note_id, [tag.tag_id])
	if not success:
		printerr("Failed to add tag ", tag.tag_id, " to note ", note_id)
		return
	await update_tags_for_note(note_id)
	await _refresh_note_views(note_id)
	
func _on_remove_tag_pressed(tag: TagModel) -> void:
	if note_id == -1:
		return
	var success = await NotesService.remove_tag_from_note(note_id, tag.tag_id)
	if not success:
		printerr("Failed to remove tag ", tag.tag_id, " from note ", note_id)
		return
	await update_tags_for_note(note_id)
	await _refresh_note_views(note_id)
	
func _refresh_note_views(id: int) -> void:
	var current: Node = self
	while current != null:
		if current is Note3D:
			current.update_tags_for_note(id)
			break
		current = current.get_parent()

	var main_ui = get_tree().get_first_node_in_group("MainInterfaceUI")
	if main_ui and main_ui.has_method("refresh_note_tags"):
		await main_ui.refresh_note_tags(id)
