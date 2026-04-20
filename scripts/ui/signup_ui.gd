extends CanvasLayer

@onready var email_input = $Control/MarginContainer/VBoxContainer/VBoxContainer/LineEdit
@onready var password_input = $Control/MarginContainer/VBoxContainer/VBoxContainer2/LineEdit
@onready var signup_button = $Control/MarginContainer/VBoxContainer/SignupButton
@onready var email_confirmation = $Control/MarginContainer/EmailConfirmation
@onready var signup_panel = $Control/MarginContainer/VBoxContainer

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

func _on_signup_pressed():
	# print("BUTTON CLICKED")
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	var error = _validate_signup(email, password)
	
	if error != "":
		# print(error)
		return
		
	# print("Signing up with:", email)
	AuthManager.signup(email, password)

func _on_signup_failed(error):
	# print("Signup failed UI:", error)
	pass

func _on_email_focus():
	# print("on_email focus input")
	KeyboardManager.focus_input(email_input, ui_panel)

func _unfocus():
	KeyboardManager.unfocus_input()

func _on_password_focus():
	# print("on_password focus input")
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
	# print("Check your email:", email)
	signup_panel.visible = false
	email_confirmation.visible = true

func _switch_to_login():
	# print("Switch to login")
	signupUI.visible = false
	loginUI.visible = true
