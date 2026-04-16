extends CanvasLayer

@export var notes_root: Node3D
@onready var menu_notes:VBoxContainer = $Control/ColorRect/MarginContainer/VBoxContainer/MarginContainer5/ScrollContainer/MenuNotes
@onready var settings_menu: MarginContainer = $Control/ColorRect/SettingsMenu
@onready var main_menu: MarginContainer = $Control/ColorRect/MarginContainer
@onready var colour_chosen: Panel = $Control/ColorRect/MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer2/ColorBtn/Panel
@onready var tag_menu: MarginContainer = $Control/ColorRect/TagMenu
@onready var tag_editor: MarginContainer = $Control/ColorRect/TagEditor
@onready var tag_scene = preload("res://scenes/ui/tags/menu_tag.tscn")
@onready var tag_editor_name = $Control/ColorRect/TagEditor/VBoxContainer/Name/LineEdit
@onready var tag_editor_desc = $Control/ColorRect/TagEditor/VBoxContainer/Desc/LineEdit
@onready var tag_editor_save_btn = $Control/ColorRect/TagEditor/VBoxContainer/MarginContainer2/HBoxContainer2/SaveBtn
@onready var tag_count_label = $Control/ColorRect/TagMenu/VBoxContainer/MarginContainer3/GridContainer/HBoxContainer/Label2
@onready var note_count_label = $Control/ColorRect/MarginContainer/VBoxContainer/MarginContainer3/GridContainer/HBoxContainer/Label2

var spatial_anchor_manager: OpenXRFbSpatialAnchorManager
var opened_spawn_button: Button = null
var notes_by_id: Dictionary

var note_scene = preload("res://scenes/notes/note3D.tscn")
var menu_note_scene = preload("res://scenes/ui/note_main_interface.tscn")

var default_colour: String = "Yellow"
var is_new_tag: bool = false
var tag_count: int = 0
var note_count: int = 0

func _ready() -> void:
	AuthManager.login_success.connect(_on_user_logged_in)
	AuthManager.auth_checked.connect(_on_auth_checked)
	AuthManager.logout_success.connect(_on_user_logged_out)
	if notes_root == null:
		notes_root = get_tree().get_first_node_in_group("Notes")
	
	spatial_anchor_manager =  get_tree().get_nodes_in_group("Managers")[1]

func _on_auth_checked(is_logged_in):
	if is_logged_in:
		await load_notes_from_database()

func _on_user_logged_in(user):
	print("User authenticated -> loading notes...")
	clear_menu_notes()
	await load_notes_from_database()

func _on_user_logged_out():
	print("User logged out -> clearing notes")
	clear_menu_notes()
	notes_by_id.clear()

func clear_menu_notes():
	print("Clearing menu notes...")
	for child in menu_notes.get_children():
		child.queue_free()

func load_notes_from_database() -> void:#
	var notes = await NotesService.get_user_notes()
	note_count = notes.size()
	note_count_label.text = note_count
	print("Loading ", notes.size(), " notes from database...")
	
	for note_model in notes:
		var menu_note_instance: MenuNote = menu_note_scene.instantiate()
		menu_notes.add_child(menu_note_instance)
		menu_note_instance.set_note_data(note_model)
		menu_note_instance.spawn_note_button_pressed.connect(_on_spawn_note_requested)
		
		if note_model.is_anchored: # If note is placed
			menu_note_instance.is_note_placed = true
		else:
			menu_note_instance.is_note_placed = false
			
		menu_note_instance.highlight_note.connect(_on_highlight_note)

func load_tags_from_database() -> void:
	var tags = await TagsService.get_user_tags()
	tag_count = tags.size()
	tag_count_label.text = tag_count
	print("Loading ", tags.size(), " tags from database...")
	
	for tag_model in tags:
		var tag_instance: MenuTag = tag_scene.instantiate()
		tag_menu.add_child(tag_instance)
		tag_instance.set_tag_data(tag_model)
		tag_instance.edit_note_button_pressed.connect(_on_tag_edit_requested)

func register_note(note_instance: Note3D):
	notes_by_id[note_instance.note_model.id] = note_instance

func unregister_note(note_instance: Note3D):
	notes_by_id.erase(note_instance.note_model.id)

func _on_highlight_note(note_model):
	if notes_by_id.has(note_model.id):
		notes_by_id[note_model.id].highlight()

func _on_spawn_note_requested(note_model: NoteModel, menu_note: MenuNote) -> void:
	spawn_note(note_model)
	menu_note.spawn_button.visible = false
	menu_note.is_note_placed = true
	note_model.is_anchored = true

func spawn_note(note_model: NoteModel) -> void:
	var hmd = XRServer.get_hmd_transform()
	var forward = -hmd.basis.z
	var spawn_position = hmd.origin + forward * 0.5
	var note_instance: Note3D = note_scene.instantiate()
	notes_root.add_child(note_instance)
	print("Spawn note id: ", note_model.id, " | node name: ", note_instance.name)
	
	# Set position
	note_instance.global_position = hmd.origin + forward * 0.5
	
	note_instance.set_note_data(note_model)
	register_note(note_instance)

func request_spawn_button(button: Button) -> void:
	if opened_spawn_button == button:
		button.visible = false
		opened_spawn_button = null
		return
	
	if opened_spawn_button:
		opened_spawn_button.visible = false
	
	opened_spawn_button = button
	button.visible = true

func _on_create_button_pressed() -> void:
	# Position the note in front of the HMD (Head-Mounted Display)
	var hmd = XRServer.get_hmd_transform()
	var forward = -hmd.basis.z
	var spawn_position = hmd.origin + forward * 0.5
	
	# Create in database
	var note_model = await NotesService.create_note(
		"",  # Default content
		spawn_position,
		default_colour
	)
	
	if note_model:
		spawn_note(note_model)
		print(note_model)
	else:
		printerr("note model null")
	
	_update_note_count("plus")

func _on_note_returned_to_main_interface(note_model: NoteModel) -> void:
	for child in menu_notes.get_children():
		if child is MenuNote and child.note_model.id == note_model.id:
			child.is_note_placed = false
			break

func _on_settings_btn_pressed() -> void:
	main_menu.visible = false
	settings_menu.visible = true

func _on_back_btn_pressed() -> void:
	main_menu.visible = true
	settings_menu.visible = false
	tag_menu.visible = false

func _return_to_tag_menu() -> void:
	tag_editor.visible = false
	tag_menu.visible = true
	_reset_tag_editor()

func _on_logout_btn_pressed() -> void:
	AuthManager.logout()

func _on_color_btn_pressed() -> void:
	$Control/ColorRect/ColourExtension.visible = !$Control/ColorRect/ColourExtension.visible

func _on_tag_btn_pressed() -> void:
	main_menu.visible = false
	tag_menu.visible = true

func _on_colour_pick_pressed(colour: String) -> void:
	if colour == "blue":
		colour_chosen.bg_color = Color.CORNFLOWER_BLUE
		default_colour = "blue"
	elif colour == "yellow":
		colour_chosen.bg_color = Color.YELLOW
		default_colour = "yellow"
	elif colour == "purple":
		colour_chosen.bg_color = Color.MEDIUM_PURPLE
		default_colour = "purple"
	elif colour == "green":
		colour_chosen.bg_color = Color.LIGHT_GREEN
		default_colour = "green"
	else:
		printerr("Invalid colour picked")

func _on_tag_edit_requested(tag_instance: MenuTag) -> void:
	tag_menu.visible = false
	tag_editor.visible = true
	tag_editor_name.text = tag_instance.tag_data.tag_name
	tag_editor_desc.text = tag_instance.tag_data.description
	tag_editor_save_btn.pressed.connect(_on_save_btn_pressed, [tag_instance])

func _on_save_btn_pressed(tag_instance: MenuTag):
	if is_new_tag != true:
		if tag_editor_name != "":
			var updated_tag = await TagsService.update_tag(tag_instance.tag_data.id, tag_editor_name, tag_editor_desc)
			if updated_tag:
				print("Tag updated")
				tag_instance.set_tag_data(updated_tag)
				_return_to_tag_menu()
				_reset_tag_editor()
				return
	
	var tag_model = TagModel.new()
	tag_model.tag_name = tag_editor_name
	tag_model.description = tag_editor_desc
	tag_model.owner = AuthManager.current_user["id"]
	
	# Save the tag in the database
	var created_tag = await TagsService.create_tag(tag_model.tag_name, tag_model.description)
	if created_tag:
		print("Tag created: ", created_tag.tag_name)
		_update_tag_count("plus")
	else:
		print("Failed to create tag.")

func _reset_tag_editor() -> void:
	tag_editor_name.text = ""
	tag_editor_desc.text = ""

func _on_create_new_tag_btn_pressed() -> void:
	tag_editor.visible = true
	tag_menu.visible = false
	is_new_tag = true	

func _update_tag_count(operation: String):
	if operation == "plus":
		tag_count = tag_count + 1
		tag_count_label.text = tag_count
	if operation == "minus":
		tag_count = tag_count - 1
		tag_count_label.text = tag_count

func _update_note_count(operation: String):
	if operation == "plus":
		note_count = note_count + 1
		note_count_label.text = note_count
	if operation == "minus":
		note_count = note_count - 1
		note_count_label.text = note_count
