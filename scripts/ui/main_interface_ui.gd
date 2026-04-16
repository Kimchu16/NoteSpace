extends CanvasLayer

@export var notes_root: Node3D
@onready var menu_notes:VBoxContainer = $Control/ColorRect/MarginContainer/VBoxContainer/MarginContainer5/ScrollContainer/MenuNotes
@onready var settings_menu: MarginContainer = $Control/ColorRect/SettingsMenu
@onready var main_menu: MarginContainer = $Control/ColorRect/MarginContainer
@onready var colour_chosen: Panel = $Control/ColorRect/MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer2/ColorBtn/Panel

var spatial_anchor_manager: OpenXRFbSpatialAnchorManager
var opened_spawn_button: Button = null
var notes_by_id: Dictionary

var note_scene = preload("res://scenes/notes/note3D.tscn")
var menu_note_scene = preload("res://scenes/ui/note_main_interface.tscn")

var default_colour: String = "Yellow"

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

func _on_logout_btn_pressed() -> void:
	AuthManager.logout()

func _on_color_btn_pressed() -> void:
	$Control/ColorRect/ColourExtension.visible = !$Control/ColorRect/ColourExtension.visible

func _on_tag_btn_pressed() -> void:
	pass # Replace with function body.

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
