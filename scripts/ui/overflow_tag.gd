extends PanelContainer

@onready var label: Label = $Label

func set_hidden_count(n: int) -> void:
	if n <= 0:
		label.text = "..."
	else:
		label.text = "... +" + str(n)
