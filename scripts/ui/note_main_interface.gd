extends Panel
class_name MenuNote

@onready var note_label := $MarginContainer/VBoxContainer/Label
var note_model: NoteModel = null
var note_stylebox: StyleBoxFlat

func set_note_data(model: NoteModel) -> void:
	note_model = model
	
	note_stylebox = get_theme_stylebox("panel").duplicate()
	note_label.text = note_model.content
	note_stylebox.border_color = note_model.get_godot_colour()
	add_theme_stylebox_override("panel", note_stylebox)

func _input(event: InputEvent) -> void:
	pass
