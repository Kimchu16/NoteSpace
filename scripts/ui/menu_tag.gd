extends Button
class_name MenuTag

@onready var tag_label := $MarginContainer/VBoxContainer/Name
@onready var tag_desc := $MarginContainer/VBoxContainer/Desc


signal edit_note_button_pressed

var tag_data: TagModel = null

func set_tag_data(tag_model: TagModel) -> void:
	tag_data = tag_model
	tag_label.text = tag_model.tag_name
	tag_desc.text = tag_model.description

func _on_pressed() -> void:
	$EditBtn.visible = !$EditBtn.visible

func _on_edit_btn_pressed() -> void:
	emit_signal("edit_note_button_pressed", self)
