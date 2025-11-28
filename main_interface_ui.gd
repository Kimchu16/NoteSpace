extends CanvasLayer

@export var notes_root: Node3D

func _ready() -> void:
	if notes_root == null:
		notes_root = get_tree().get_first_node_in_group("Notes")
	
func _on_create_button_pressed() -> void:
	# Create a new note
	var note := preload("res://note3D.tscn").instantiate()
	
	# Position the note in front of the HMD (Head-Mounted Display)
	var hmd = XRServer.get_hmd_transform()
	var forward = -hmd.basis.z
	note.global_position = hmd.origin + forward * 1.0

	# Add the note to the notes_root
	notes_root.add_child(note)
