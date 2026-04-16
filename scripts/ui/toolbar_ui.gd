extends CanvasLayer

@onready var delete_menu = $Control/Panel/MarginContainer/HBoxContainer/Button2/PanelContainer

signal edit_button
signal delete_button
signal send_to_main_interface

func _on_button_pressed():
	#print("Edit button pressed in toolbar UI:", self)
	#print("Forwarding to:", get_parent().get_parent().get_parent())
	
	# Viewport2Din3D creates a canvasLayer clone on runtime so to get to Toolbar in the heigharchy
	# which has the signal as it does not get cloned, get_parent is called 3 times
	get_parent().get_parent().get_parent().emit_signal("edit_button")

func _on_del_btn_pressed():
	delete_menu.visible = !delete_menu.visible

func _on_perma_del_pressed():
	emit_signal("delete_button")

func _send_to_main_interface():
	print("Send back to main interface.")
	emit_signal("send_to_main_interface")
	#print("Emitted from:", get_instance_id())
