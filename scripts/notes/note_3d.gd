extends Node3D
class_name Note3D

@onready var visual_root: Node3D = $VisualRoot
@onready var highlight_ring: MeshInstance3D = $VisualRoot/HighlightRing
@onready var highlight_sound: AudioStreamPlayer3D = $VisualRoot/HighlightRing/AudioStreamPlayer3D

signal returned_to_main_interface

var note_model: NoteModel = null
var anchored: bool = false
var anchor_uuid: String = ""
var main_interface_ui: CanvasLayer

func _ready() -> void:
	var toolbar = $VisualRoot/Toolbar
	var toolbar_ui = $VisualRoot/Toolbar/Viewport2Din3D/Viewport/Toolbar_UI
	main_interface_ui = get_tree().get_first_node_in_group("MainInterfaceUI")
	toolbar.connect("edit_button", _on_edit_button_pressed)
	toolbar_ui.connect("delete_button", _on_delete_button_pressed)
	toolbar_ui.connect("send_to_main_interface", _on_send_to_main)
	#print("Connected to:", toolbar_ui.get_instance_id())

# Set the note data from database
func set_note_data(model: NoteModel) -> void:
	note_model = model
	
	# Update UI with content
	var note_ui = $VisualRoot/SubViewport/Note_UI
	note_ui.set_note_content(note_model.content)
	
	# Set color
	$VisualRoot/SubViewport/Note_UI/Control/ColorRect.color = note_model.get_godot_colour()

# Save anchor state to database
func save_anchor_state(state: bool) -> void:
	if not note_model or note_model.id == -1:
		return
	
	await NotesService.update_anchored_state(note_model.id, state)

# Save content when editing finishes
func save_content(new_content: String) -> void:
	if not note_model or note_model.id == -1:
		return
	
	note_model.content = new_content
	await NotesService.update_note_content(note_model.id, new_content)
	print("Content saved for note ", note_model.id)

func highlight():
	highlight_ring.visible = true
	highlight_sound.play()
	await get_tree().create_timer(5.0).timeout
	highlight_ring.visible = false

func _on_edit_button_pressed() -> void:
	$VisualRoot/SubViewport/Note_UI._edit_note()

func _on_delete_button_pressed() -> void:
	# Delete from database first
	if note_model and note_model.id != -1:
		await NotesService.delete_note(note_model.id)
	main_interface_ui.unregister_note(self)
	$VisualRoot/XRToolsInteractableArea.delete_spatial_anchor()
	queue_free()
	print("Note Deleted")

func _on_send_to_main() -> void:
	emit_signal("returned_to_main_interface", note_model)
	call_deferred("queue_free") # Queue free after anchor and other procedures is done running
