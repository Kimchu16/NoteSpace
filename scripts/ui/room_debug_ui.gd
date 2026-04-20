extends CanvasLayer

@onready var room_label: Label = $Control/Panel/MarginContainer/VBoxContainer/RoomLabel
@onready var counts_label: Label = $Control/Panel/MarginContainer/VBoxContainer/CountsLabel
@onready var active_label: Label = $Control/Panel/MarginContainer/VBoxContainer/ActiveLabel
@onready var refresh_button: Button = $Control/Panel/MarginContainer/VBoxContainer/RefreshButton
@onready var status_label: Label = $Control/Panel/MarginContainer/VBoxContainer/StatusLabel

var room_manager: RoomManager
var update_accumulator: float = 0.0
var last_status_text: String = "Ready"

func _ready() -> void:
	room_manager = get_tree().get_first_node_in_group("RoomManager")
	refresh_button.pressed.connect(_on_refresh_button_pressed)

	if room_manager:
		room_manager.current_room_changed.connect(_on_current_room_changed)
		room_manager.room_loaded.connect(_on_room_loaded)
		room_manager.room_unloading.connect(_on_room_unloading)

	_refresh_debug_text()
	status_label.text = last_status_text

func _process(delta: float) -> void:
	update_accumulator += delta
	if update_accumulator < 0.25:
		return

	update_accumulator = 0.0
	_refresh_debug_text()

func _on_refresh_button_pressed() -> void:
	var scene_controller = get_tree().current_scene.get_node_or_null("Managers/SceneController")
	if scene_controller == null or not scene_controller.has_method("force_scene_capture"):
		last_status_text = "SceneController missing"
		status_label.text = last_status_text
		return

	last_status_text = "Requesting room scan..."
	status_label.text = last_status_text
	scene_controller.force_scene_capture("Manual debug room scan")

func _on_current_room_changed(previous_room_id: String, current_room_id: String) -> void:
	if not previous_room_id.is_empty() and current_room_id.is_empty():
		last_status_text = "Switching rooms..."
	elif current_room_id.is_empty():
		last_status_text = "No active room"
	else:
		last_status_text = "Current room: %s" % _format_room_id(current_room_id)

	status_label.text = last_status_text

func _on_room_loaded(room_id: String) -> void:
	last_status_text = "Loaded room: %s" % _format_room_id(room_id)
	status_label.text = last_status_text
	_refresh_debug_text()

func _on_room_unloading(room_id: String) -> void:
	last_status_text = "Unloading: %s" % _format_room_id(room_id)
	status_label.text = last_status_text

func _refresh_debug_text() -> void:
	if room_manager == null:
		room_label.text = "Room: RoomManager missing"
		counts_label.text = "Anchors: 0  Notes: 0  Colliders: 0"
		active_label.text = "Active collider nodes: 0"
		return

	var room_data: RoomData = room_manager.get_current_room_data()
	var room_id: String = room_manager.current_room_id
	var anchor_count: int = 0
	var note_count: int = 0
	var collider_count: int = 0

	if room_data != null:
		anchor_count = room_data.anchor_uuids.size()
		note_count = room_data.notes.size()
		collider_count = room_data.collision_shapes.size()

	room_label.text = "Room: %s" % _format_room_id(room_id)
	counts_label.text = "Anchors: %d  Notes: %d  Colliders: %d" % [anchor_count, note_count, collider_count]
	active_label.text = "Active collider nodes: %d" % get_tree().get_nodes_in_group("room_collision_nodes").size()

func _format_room_id(room_id: String) -> String:
	if room_id.is_empty():
		return "none"

	if room_id.is_valid_int():
		return room_id

	if room_id.begins_with("room::"):
		var parts: PackedStringArray = room_id.split("::")
		if parts.size() >= 3:
			var fingerprint: String = parts[1]
			var entity_count: String = parts[2]
			if fingerprint.length() > 12:
				return "%s...%s (%s)" % [
					fingerprint.substr(0, 8),
					fingerprint.substr(fingerprint.length() - 4, 4),
					entity_count
				]
			return "%s (%s)" % [fingerprint, entity_count]

	if room_id.length() <= 18:
		return room_id

	return "%s...%s" % [room_id.substr(0, 8), room_id.substr(room_id.length() - 6, 6)]
