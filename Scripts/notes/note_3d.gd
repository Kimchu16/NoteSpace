extends Node3D

func _enter_tree():
	var toolbar = $Toolbar
	#print("Note3D connecting to Toolbar instance:", toolbar)
	toolbar.connect("edit_button", _on_edit_button_pressed)
	
func _on_edit_button_pressed() -> void:
	$SubViewport/Note_UI._edit_note()
