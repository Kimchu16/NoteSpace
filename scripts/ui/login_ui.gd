extends CanvasLayer

@onready var email_input = $Control/MarginContainer/VBoxContainer/VBoxContainer/LineEdit
@onready var password_input = $Control/MarginContainer/VBoxContainer/VBoxContainer2/LineEdit
@onready var login_button = $Control/MarginContainer/VBoxContainer/LoginButton
@onready var error_popup: PanelContainer = $Control/MarginContainer/VBoxContainer/ErrorPopup
@onready var error_label: Label = $Control/MarginContainer/VBoxContainer/ErrorPopup/Label

var current_focused_input: Control = null
var ui_panel: Node3D
var loginUI: Node3D
var signupUI: Node3D

func _ready():
	AuthManager.login_failed.connect(_on_login_failed)
	ui_panel = get_tree().get_first_node_in_group("LoginUI3D")
	loginUI = get_tree().get_first_node_in_group("LoginUI")
	signupUI = get_tree().get_first_node_in_group("SignupUI")
	_hide_error()

func _on_login_pressed():
	print("BUTTON CLICKED")
	_hide_error()
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()

	if email == "" or password == "":
		_show_error("Please enter both email and password.")
		return

	print("Logging in:", email)
	AuthManager.login(email, password)

func _on_login_failed(error):
	print("Login failed UI:", error)
	_show_error(_extract_error_message(error, "Unable to log in."))

func _on_email_focus():
	print("on_email focus input")
	KeyboardManager.focus_input(email_input, ui_panel)

func _unfocus():
	KeyboardManager.unfocus_input()

func _on_password_focus():
	print("on_password focus input")
	KeyboardManager.focus_input(password_input, ui_panel)

func _on_link_button_pressed():
	_hide_error()
	signupUI.visible = true
	loginUI.visible = false

func _show_error(message: String) -> void:
	error_label.text = message
	error_popup.visible = true

func _hide_error() -> void:
	error_label.text = ""
	error_popup.visible = false

func _extract_error_message(error: Variant, fallback: String) -> String:
	if error == null:
		return fallback
	
	if error is String:
		var error_text: String = error.strip_edges()
		return error_text if not error_text.is_empty() else fallback
	
	if error is Dictionary:
		if error.has("message") and str(error["message"]).strip_edges() != "":
			return str(error["message"])
		if error.has("error_description") and str(error["error_description"]).strip_edges() != "":
			return str(error["error_description"])
		if error.has("error") and str(error["error"]).strip_edges() != "":
			return str(error["error"])
	
	if error is Object:
		var message = error.get("message")
		if message != null and str(message).strip_edges() != "":
			return str(message)
		var error_description = error.get("error_description")
		if error_description != null and str(error_description).strip_edges() != "":
			return str(error_description)
		var error_value = error.get("error")
		if error_value != null and str(error_value).strip_edges() != "":
			return str(error_value)
	
	var fallback_text: String = str(error).strip_edges()
	return fallback_text if not fallback_text.is_empty() else fallback
