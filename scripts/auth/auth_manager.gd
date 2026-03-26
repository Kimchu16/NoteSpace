extends Node

signal login_success(user)
signal login_failed(error)
signal logout_success()
signal auth_checked(is_logged_in)

var current_user : SupabaseUser = null
var is_authenticated : bool = false

func _ready():
	print("AuthManager ready")
	_try_restore_session()

func signup(email: String, password: String):
	var task = Supabase.auth.sign_up(email, password)
	task.completed.connect(_on_signup_completed)

func _on_signup_completed(task):
	if task.error:
		print("Signup failed: ", task.error.description)
		emit_signal("login_failed", task.error)
		return
	
	current_user = task.user
	is_authenticated = true
	
	_save_session(task.user)
	emit_signal("login_success", current_user)

func login(email: String, password: String):
	var task = Supabase.auth.sign_in(email, password)
	task.completed.connect(_on_login_completed)

func _on_login_completed(task):
	if task.error:
		print("Login failed: ", task.error)
		emit_signal("login_failed", task.error)
		return
	
	current_user = task.user
	is_authenticated = true
	
	_save_session(task.user)
	emit_signal("login_success", current_user)

func logout():
	var task = Supabase.auth.sign_out()
	task.completed.connect(_on_logout_completed)

func _on_logout_completed(task):
	current_user = null
	is_authenticated = false
	
	_clear_session()
	emit_signal("logout_success")

func _save_session(user: SupabaseUser):
	var data = {
		"access_token": user.access_token,
		"refresh_token": user.refresh_token
	}
	
	var file = FileAccess.open("user://session.save", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _try_restore_session():
	if not FileAccess.file_exists("user://session.save"):
		print("Emitting auth_checked now")
		emit_signal("auth_checked", false)
		return
	
	var file = FileAccess.open("user://session.save", FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	
	var data = JSON.parse_string(content)
	if data == null:
		print("Invalid session data")
		emit_signal("auth_checked", false)
		return
		
	if not data.has("access_token"):
		print("Session missing access_token")
		emit_signal("auth_checked", false)
		return
	
	print("Trying to restore session...")
	
	var task = Supabase.auth.user(data["access_token"])
	task.completed.connect(_on_session_restored)

func _on_session_restored(task):
	if task.error:
		print("Session restore failed: ", task.error)
		_clear_session()
		emit_signal("auth_checked", false)
		return
	
	current_user = task.user
	is_authenticated = true
	
	print("Session restored: ", current_user.email)
	emit_signal("auth_checked", true)
	emit_signal("login_success", current_user)

func _clear_session():
	if FileAccess.file_exists("user://session.save"):
		var err = DirAccess.remove_absolute("user://session.save")
		print("Session file removed: ", err == OK)
