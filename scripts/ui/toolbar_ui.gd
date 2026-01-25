extends CanvasLayer

@onready var edit_btn = $Control/ColorRect/MarginContainer/HBoxContainer/Button
@onready var del_btn = $Control/ColorRect/MarginContainer/HBoxContainer/Button2

signal edit_button
signal delete_button

func _ready():
	edit_btn.pressed.connect(_on_button_pressed)
	#print("Toolbar_UI instance ready:", self)
	del_btn.pressed.connect(_on_del_btn_pressed)

func _on_button_pressed():
	#print("Edit button pressed in toolbar UI:", self)
	#print("Forwarding to:", get_parent().get_parent().get_parent())
	
	# Viewport2Din3D creates a canvasLayer clone on runtime so to get to Toolbar in the heigharchy
	# which has the signal as it does not get cloned, get_parent is called 3 times
	get_parent().get_parent().get_parent().emit_signal("edit_button")

func _on_del_btn_pressed():
	get_parent().get_parent().get_parent().emit_signal("delete_button")
