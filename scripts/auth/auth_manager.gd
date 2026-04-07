extends Node

signal login_success(user)
signal login_failed(error)
signal signup_failed(error)
signal signup_success(user)
signal logout_success()
signal auth_checked(is_logged_in)
signal email_confirmation_required(email)

var current_user = null
var is_authenticated : bool = false

func _ready():
	print("AuthManager ready")
	Supabase.auth.connect("signed_in", _on_signed_in)
	Supabase.auth.connect("signed_up", _on_signed_up)
	Supabase.auth.token_refreshed.connect(_on_token_restored)
	Supabase.auth.error.connect(_on_auth_error)
	_try_restore_session()

func signup(email: String, password: String):
	Supabase.auth.sign_up(email, password)


func login(email: String, password: String):
	Supabase.auth.sign_in(email, password)

func logout():
	Supabase.auth.sign_out()
	current_user = null
	is_authenticated = false
	_clear_session()
	
	emit_signal("logout_success")
	emit_signal("auth_checked", false)

func _on_signed_in(user: SupabaseUser):
	print("SIGNED IN:", user)
	
	current_user = user
	is_authenticated = true
	_save_session({
		"access_token": user.access_token,
		"refresh_token": user.refresh_token,
		"expires_in": user.expires_in,
		"token_type": user.token_type
	})
	
	emit_signal("login_success", current_user)
	emit_signal("auth_checked", true) 

func _on_signed_up(user: SupabaseUser):
	print("SIGNED UP:", user)
	
	if user.access_token == null:
		print("Signup requires email confirmation")
		emit_signal("email_confirmation_required", user.email)
		return

func _on_auth_error(err):
	print("AUTH ERROR:", err)
	
	if not is_authenticated:
		emit_signal("signup_failed", err)
		print("Ignoring pre-login error")
		emit_signal("auth_checked", false)
		return
	
	current_user = null
	is_authenticated = false
	_clear_session()
	
	emit_signal("auth_checked", false)
	emit_signal("login_failed", err)

func _check_existing_user():
	var task = Supabase.auth.user()
	task.completed.connect(_on_user_checked)

func _on_user_checked(task):
	if task.error:
		print("No active session")
		emit_signal("auth_checked", false)
		return
	
	current_user = task.user
	is_authenticated = true
	
	print("SESSION EXISTS:", current_user.email)
	
	emit_signal("auth_checked", true)
	emit_signal("login_success", current_user)

func _on_token_restored(user: SupabaseUser):
	print("SESSION RESTORED:", user.email)
	current_user = user
	is_authenticated = true
	
	_save_session({
		"access_token": user.access_token,
		"refresh_token": user.refresh_token,
		"expires_in": user.expires_in,
		"token_type": user.token_type
	})
	
	emit_signal("auth_checked", true)
	emit_signal("login_success", user)

func _try_restore_session():
	if not FileAccess.file_exists("user://session.save"):
		print("No saved session...checking SDK")
		_check_existing_user()
		return
	
	var file = FileAccess.open("user://session.save", FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if data == null or not data.has("refresh_token"):
		print("Invalid session... fallback to SDK")
		_check_existing_user()
		return
	
	print("Restoring session...")
	var task = await Supabase.auth.refresh_token(
		data["refresh_token"],
		data.get("expires_in", 3600),
		true
	)
	_on_refresh_completed(task)

func _on_refresh_completed(task):
	if task.error:
		print("Refresh failed:", task.error)
		_clear_session()
		emit_signal("auth_checked", false)
		return
	
	print("Refresh success:", task.data)
	
	var user_task = Supabase.auth.user()
	user_task.completed.connect(_on_user_checked)

func _save_session(data):
	var file = FileAccess.open("user://session.save", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _clear_session():
	if FileAccess.file_exists("user://session.save"):
		DirAccess.remove_absolute("user://session.save")
