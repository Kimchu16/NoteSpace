extends CanvasLayer

@export var notes_root: Node3D
@onready var menu_notes:VBoxContainer = $Control/ColorRect/MarginContainer/VBoxContainer/MarginContainer5/ScrollContainer/MenuNotes

var spatial_anchor_manager: OpenXRFbSpatialAnchorManager
var opened_spawn_button: Button = null

var note_scene = preload("res://scenes/notes/note3D.tscn")
var menu_note_scene = preload("res://scenes/ui/note_main_interface.tscn")

func _ready() -> void:
	if notes_root == null:
		notes_root = get_tree().get_first_node_in_group("Notes")
	
	spatial_anchor_manager =  get_tree().get_nodes_in_group("Managers")[1]
	
	#load_anchors_from_file()
	# Load existing notes from database
	load_notes_from_database()

# Load all notes from database on startup
func load_notes_from_database() -> void:
	var notes = await NotesService.get_all_notes()
	print("Loading ", notes.size(), " notes from database...")
	
	for note_model in notes:
		if note_model.position != Vector3(0.0, 0.0, 0.0): # If note has a saved position
			#spawn_note(note_model)
			pass
		else:
			var menu_note_instance: MenuNote = menu_note_scene.instantiate()
			menu_notes.add_child(menu_note_instance)
			menu_note_instance.set_note_data(note_model)
			menu_note_instance.spawn_note_button_pressed.connect(_on_spawn_note_requested)

func _on_spawn_note_requested(note_model: NoteModel, menu_note: MenuNote) -> void:
	spawn_note(note_model)
	menu_note.spawn_button.visible = false

# Spawn a note in VR space
func spawn_note(note_model: NoteModel) -> void:
	var hmd = XRServer.get_hmd_transform()
	var forward = -hmd.basis.z
	var spawn_position = hmd.origin + forward * 0.5
	var note_instance: Note3D = note_scene.instantiate()
	notes_root.add_child(note_instance)
	print("Spawn note id: ", note_model.id, " | node name: ", note_instance.name)
	
	# Set position
	note_instance.global_position = hmd.origin + forward * 0.5
	
	# Set the note data
	note_instance.set_note_data(note_model)

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
	
	# Create in database first
	var note_model = await NotesService.create_note(
		"",  # Default content
		spawn_position,
		"yellow"  # Default color
	)
	
	if note_model:
		# Spawn in VR
		spawn_note(note_model)
		print(note_model)
	else:
		printerr("note model null")
