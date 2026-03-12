extends Button
class_name MenuNote

@onready var note_label := $MarginContainer/VBoxContainer/Label
var note_model: NoteModel = null
var note_stylebox: StyleBoxFlat
var note_stylebox_hover: StyleBoxFlat
var note_stylebox_pressed: StyleBoxFlat

func set_note_data(model: NoteModel) -> void:
	note_model = model
	
	note_stylebox = get_theme_stylebox("normal").duplicate()
	note_stylebox_hover = get_theme_stylebox("hover").duplicate()
	note_stylebox_pressed = get_theme_stylebox("pressed").duplicate()
	
	note_label.text = note_model.content
	note_stylebox.border_color = note_model.get_godot_colour()
	note_stylebox_hover.border_color = note_model.get_godot_colour()
	note_stylebox_pressed.border_color = note_model.get_godot_colour()
	
	add_theme_stylebox_override("normal", note_stylebox)
	add_theme_stylebox_override("hover", note_stylebox_hover)
	add_theme_stylebox_override("pressed", note_stylebox_pressed)

func _input(event: InputEvent) -> void:
	pass
