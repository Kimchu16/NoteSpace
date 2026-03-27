extends Node

signal login_success(user)
signal login_failed(error)
signal logout_success()
signal auth_checked(is_logged_in)

var current_user = null
var is_authenticated : bool = false

func _ready():
	print("AuthManager ready")
	Supabase.auth.connect("signed_in", _on_signed_in)
	_try_restore_session()

func signup(email: String, password: String):
	var task = Supabase.auth.sign_up(email, password)
	task.completed.connect(_on_signup_completed)

func _on_signup_completed(task):
	if task.error:
		print("Signup failed: ", task.error)
		emit_signal("login_failed", task.error)
		return
		
	var data = task.data
	current_user = task.user
	is_authenticated = true
	
	_save_session({
		"access_token": data["access_token"],
		"refresh_token": data["refresh_token"]
	})
	emit_signal("login_success", current_user)

func _on_signed_in(user: SupabaseUser):
	print("SIGNED IN:", user)
	
	current_user = user
	is_authenticated = true
	_save_session({
		"access_token": user.access_token,
		"refresh_token": user.refresh_token
	})
	emit_signal("login_success", current_user)

func login(email: String, password: String):
	Supabase.auth.sign_in(email, password)

func logout():
	var task = Supabase.auth.sign_out()
	task.completed.connect(_on_logout_completed)

func _on_logout_completed(task):
	current_user = null
	is_authenticated = false
	
	_clear_session()
	emit_signal("logout_success")

func _save_session(user_data):
	print("Saving session...")
	var file = FileAccess.open("user://session.save", FileAccess.WRITE)
	file.store_string(JSON.stringify(user_data))
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
	
	if not data.has("refresh_token"):
		print("No refresh token found")
		emit_signal("auth_checked", false)
		return

	refresh_session(data["refresh_token"])

func _clear_session():
	if FileAccess.file_exists("user://session.save"):
		var err = DirAccess.remove_absolute("user://session.save")
		print("Session file removed: ", err == OK)

func refresh_session(refresh_token: String):
	var http = HTTPRequest.new()
	add_child(http)
	
	var url = "https://cpybzhdaszatwsxqurvh.supabase.co/auth/v1/token?grant_type=refresh_token"
	
	var headers = [
		"apikey: sb_publishable_nlfXcUNf9FSP6qjg6qxGwA_-cygG-39",
		"Content-Type: application/json"
	]
	
	var body = JSON.stringify({
		"refresh_token": refresh_token
	})
	
	http.request(url, headers, HTTPClient.METHOD_POST, body)
	http.request_completed.connect(_on_refresh_completed)

func _on_refresh_completed(result, response_code, headers, body):
	var data = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code != 200:
		print("Refresh failed:", data)
		return
	
	print("Refresh success:", data)
	
	_save_session({
		"access_token": data["access_token"],
		"refresh_token": data["refresh_token"]
	})
	
	current_user = data["user"]
	is_authenticated = true
	
	emit_signal("auth_checked", true)
	emit_signal("login_success", current_user)
