extends  XRToolsInteractableArea

var toolbar : Node3D
var xr_controller_l : XRController3D
var xr_controller_r : XRController3D
var drag_distance: float
var previous_hand_position: Vector3
var drag_offset := Vector3.ZERO
var is_dragged = false
var dragging_pointer = null
var is_hovering = false
var is_pressed = false


func _ready() -> void:
	xr_controller_l = get_tree().get_first_node_in_group("LeftController")
	xr_controller_r = get_tree().get_first_node_in_group("RightController")
	toolbar = get_parent().get_node("Toolbar")
	pointer_event.connect(_on_pointer_event)
	xr_controller_l.connect("button_pressed", _on_left_hand_pressed)

func _on_left_hand_pressed(name: String) -> void:
	match name:
		"menu_pressed":
			if is_pressed == false and is_hovering:
				#print("Toolbar activate!")
				is_pressed = true
			elif is_pressed == true and is_hovering:
				#print("Toolbar deactivate!")
				is_pressed = false

func _on_pointer_event(event: XRToolsPointerEvent) -> void:
	var type := event.event_type
	var pointer := event.pointer
	var at := event.position

	match type:
		XRToolsPointerEvent.Type.ENTERED:
			#print("Pointer hovering Note")
			is_hovering = true
			

		XRToolsPointerEvent.Type.EXITED:
			#print("Pointer left Note")
			is_hovering = false

		XRToolsPointerEvent.Type.PRESSED:
			#print("Pointer pressed Note")
			is_dragged = true
			dragging_pointer = pointer
			drag_distance = xr_controller_r.global_position.distance_to(get_parent().global_position)
			previous_hand_position = xr_controller_r.global_position
			#drag_offset = global_transform.origin - at # How far the note is from the hit point

		XRToolsPointerEvent.Type.RELEASED:
			#print("Pointer released Note")
			is_dragged = false
			dragging_pointer = null

		XRToolsPointerEvent.Type.MOVED:
			#get_parent().global_transform.origin = at + drag_offset

			if is_hovering and is_pressed:
				toolbar.visible = true
			elif is_hovering and !is_pressed:
				toolbar.visible = false

func _update_free_drag() -> void:
	var current_hand_position = xr_controller_r.global_position
	var hand_delta = current_hand_position - previous_hand_position
	
	var forward = -xr_controller_r.global_transform.basis.z
	var depth_delta = hand_delta.dot(forward)
	
	drag_distance += depth_delta
	drag_distance = clamp(drag_distance, 0.2, 3.0)
	
	previous_hand_position = current_hand_position
	
	var target_position = xr_controller_r.global_position + forward * drag_distance
	
	# Smooth movement
	get_parent().global_position = get_parent().global_position.lerp(target_position, 0.2)
	
	# Billboard toward camera
	var camera = get_viewport().get_camera_3d()
	var note = get_parent()

	var to_camera = camera.global_position - note.global_position
	var horizontal = Vector3(to_camera.x, 0, to_camera.z)

	#YAW (always face camera horizontally)
	var yaw = atan2(horizontal.x, horizontal.z)

	#PITCH (tilt forward/back)
	var horizontal_distance = horizontal.length()
	var pitch = atan2(to_camera.y, horizontal_distance)

	# Clamp tilt so it doesn’t over-rotate
	pitch = clamp(pitch, deg_to_rad(-45), deg_to_rad(45))

	# Apply rotation (no roll)
	note.rotation = Vector3(-pitch, yaw, 0)

func _process(delta: float) -> void:
	if not is_dragged:
		return
	
	_update_free_drag()
