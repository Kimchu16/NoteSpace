extends Node3D
class_name Note3D

@onready var visual_root: Node3D = $VisualRoot

signal returned_to_main_interface

var note_model: NoteModel = null
var last_saved_position: Vector3 = Vector3.ZERO
var position_update_timer: float = 0.0
const POSITION_UPDATE_DELAY = 1.0  # Save position every 1 second when moved
var anchored: bool = false
var anchor_uuid: String = ""

func _ready() -> void:
	var toolbar = $VisualRoot/Toolbar
	var toolbar_ui = $VisualRoot/Toolbar/Viewport2Din3D/Viewport/Toolbar_UI
	toolbar.connect("edit_button", _on_edit_button_pressed)
	toolbar_ui.connect("delete_button", _on_delete_button_pressed)
	toolbar_ui.connect("send_to_main_interface", _on_send_to_main)
	print("Connected to:", toolbar_ui.get_instance_id())

func _process(delta: float) -> void:
	# Auto-save position if it changed
	if note_model and note_model.id != -1:
		if global_position.distance_to(last_saved_position) > 0.01:
			position_update_timer += delta
			if position_update_timer >= POSITION_UPDATE_DELAY:
				save_position()
				position_update_timer = 0.0

# Set the note data from database
func set_note_data(model: NoteModel) -> void:
	note_model = model
	last_saved_position = global_position
	
	# Update UI with content
	var note_ui = $VisualRoot/SubViewport/Note_UI
	note_ui.set_note_content(note_model.content)
	
	# Set color
	$VisualRoot/SubViewport/Note_UI/Control/ColorRect.color = note_model.get_godot_colour()

# Save position to database
func save_position() -> void:
	if not note_model or note_model.id == -1:
		return
	
	await NotesService.update_note_position(note_model.id, global_position)
	last_saved_position = global_position
	#print("Position saved for note ", note_model.id)

# Save content when editing finishes
func save_content(new_content: String) -> void:
	if not note_model or note_model.id == -1:
		return
	
	note_model.content = new_content
	await NotesService.update_note_content(note_model.id, new_content)
	print("Content saved for note ", note_model.id)

func _on_edit_button_pressed() -> void:
	$VisualRoot/SubViewport/Note_UI._edit_note()

func _on_delete_button_pressed() -> void:
	# Delete from database first
	if note_model and note_model.id != -1:
		await NotesService.delete_note(note_model.id)
	queue_free()
	print("Note Deleted")

func _on_send_to_main() -> void:
	emit_signal("returned_to_main_interface", note_model)
	call_deferred("queue_free") # Queue free after anchor and other procedures is done running
