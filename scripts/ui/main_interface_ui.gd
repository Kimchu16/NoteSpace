extends CanvasLayer

@export var notes_root: Node3D
var note_scene = preload("res://scenes/notes/note3D.tscn")

func _ready() -> void:
	if notes_root == null:
		notes_root = get_tree().get_first_node_in_group("Notes")
		
	# Load existing notes from database
	load_notes_from_database()
	
# Load all notes from database on startup
func load_notes_from_database() -> void:
	var notes = await NotesService.get_all_notes()
	print("Loading ", notes.size(), " notes from database...")
	
	for note_model in notes:
		spawn_note(note_model)

# Spawn a note in VR space
func spawn_note(note_model: NoteModel) -> void:
	var note_instance = note_scene.instantiate()
	notes_root.add_child(note_instance)
	print("Spawn note")
	
	# Set position
	note_instance.global_position = note_model.position
	
	# Set the note data
	note_instance.set_note_data(note_model)

func _on_create_button_pressed() -> void:
	
	#TODO: Preview note in main interface, then give option to spawn note in world space
	
	# Position the note in front of the HMD (Head-Mounted Display)
	var hmd = XRServer.get_hmd_transform()
	var forward = -hmd.basis.z
	var spawn_position = hmd.origin + forward * 1.0
	
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
