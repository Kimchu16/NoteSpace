extends  XRToolsInteractableArea

var toolbar : Node3D
var xr_controller : XRController3D
var drag_offset := Vector3.ZERO
var is_dragged = false
var dragging_pointer = null
var is_hovering = false
var is_pressed = false


func _ready() -> void:
	xr_controller = get_tree().get_first_node_in_group("LeftController")
	toolbar = get_parent().get_node("Toolbar")
	pointer_event.connect(_on_pointer_event)
	xr_controller.connect("button_pressed", _on_left_hand_pressed)

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
			drag_offset = global_transform.origin - at # How far the note is from the hit point

		XRToolsPointerEvent.Type.RELEASED:
			#print("Pointer released Note")
			is_dragged = false
			dragging_pointer = null

		XRToolsPointerEvent.Type.MOVED:
			if is_dragged and dragging_pointer == pointer:
				get_parent().global_transform.origin = at + drag_offset

			if is_hovering and is_pressed:
				toolbar.visible = true
			elif is_hovering and !is_pressed:
				toolbar.visible = false
