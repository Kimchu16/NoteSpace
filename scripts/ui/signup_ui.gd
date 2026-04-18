extends CanvasLayer

@onready var email_input = $Control/MarginContainer/VBoxContainer/VBoxContainer/LineEdit
@onready var password_input = $Control/MarginContainer/VBoxContainer/VBoxContainer2/LineEdit
@onready var signup_button = $Control/MarginContainer/VBoxContainer/SignupButton
@onready var email_confirmation = $Control/MarginContainer/EmailConfirmation
@onready var signup_panel = $Control/MarginContainer/VBoxContainer
@onready var error_popup: PanelContainer = $Control/MarginContainer/VBoxContainer/ErrorPopup
@onready var error_label: Label = $Control/MarginContainer/VBoxContainer/ErrorPopup/Label

var current_focused_input: Control = null
var ui_panel: Node3D
var loginUI: Node3D
var signupUI: Node3D

func _ready():
	AuthManager.signup_failed.connect(_on_signup_failed)
	AuthManager.email_confirmation_required.connect(_on_email_confirmation)
	ui_panel = get_tree().get_first_node_in_group("SignupUI3D")
	loginUI = get_tree().get_first_node_in_group("LoginUI")
	signupUI = get_tree().get_first_node_in_group("SignupUI")
	_hide_error()

func _on_signup_pressed():
	print("BUTTON CLICKED")
	_hide_error()
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	var error = _validate_signup(email, password)
	
	if error != "":
		_show_error(error)
		return
		
	print("Signing up with:", email)
	AuthManager.signup(email, password)

func _on_signup_failed(error):
	print("Signup failed UI:", error)
	_show_error(_extract_error_message(error, "Unable to sign up."))

func _on_email_focus():
	print("on_email focus input")
	KeyboardManager.focus_input(email_input, ui_panel)

func _unfocus():
	KeyboardManager.unfocus_input()

func _on_password_focus():
	print("on_password focus input")
	KeyboardManager.focus_input(password_input, ui_panel)

func _validate_signup(email: String, password: String) -> String:
	if email == "" or password == "":
		return "Fields cannot be empty"
		
	if not email.contains("@") or not email.contains("."):
		return "Invalid email format"
		
	if password.length() < 6:
		return "Password must be at least 6 characters"
		
	return ""

func _on_email_confirmation(email):
	print("Check your email:", email)
	_hide_error()
	signup_panel.visible = false
	email_confirmation.visible = true

func _switch_to_login():
	print("Switch to login")
	_hide_error()
	signupUI.visible = false
	loginUI.visible = true

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
