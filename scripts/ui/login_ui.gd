extends CanvasLayer

@onready var email_input = $Control/MarginContainer/VBoxContainer/VBoxContainer/LineEdit
@onready var password_input = $Control/MarginContainer/VBoxContainer/VBoxContainer2/LineEdit
@onready var login_button = $Control/MarginContainer/VBoxContainer/LoginButton

var current_focused_input: Control = null
var ui_panel: Node3D

func _ready():
	AuthManager.login_failed.connect(_on_login_failed)
	ui_panel = get_tree().get_first_node_in_group("LoginUI3D")

func _on_login_pressed():
	print("BUTTON CLICKED")
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()

	if email == "" or password == "":
		print("Missing fields")
		return

	print("Logging in:", email)
	AuthManager.login(email, password)

func _on_login_failed(error):
	print("Login failed UI:", error)

func _on_email_focus():
	print("on_email focus input")
	KeyboardManager.focus_input(email_input, ui_panel)

func _unfocus():
	KeyboardManager.unfocus_input()

func _on_password_focus():
	print("on_password focus input")
	KeyboardManager.focus_input(password_input, ui_panel)
