extends PanelContainer

@onready var label: Label = $Label

func set_text(t: String) -> void:
	label.text = t
	update_minimum_size()
	emit_signal("tag_content_changed")
