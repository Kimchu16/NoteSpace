extends RigidBody3D

func _on_highlight_updated(pickable, enable):
	if enable:
		$MeshInstance3D.modulate = Color(1,1,0.8)  # highlight
	else:
		$MeshInstance3D.modulate = Color.WHITE
