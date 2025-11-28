extends  XRToolsInteractableArea

var is_dragged = false
var dragging_pointer = null
var drag_offset := Vector3.ZERO

func _ready() -> void:
	pointer_event.connect(_on_pointer_event)

func _on_pointer_event(event: XRToolsPointerEvent) -> void:
	var type := event.event_type
	var pointer := event.pointer
	var at := event.position

	match type:
		XRToolsPointerEvent.Type.ENTERED:
			#print("Pointer hovering Note")
			pass

		XRToolsPointerEvent.Type.EXITED:
			#print("Pointer left Note")
			pass

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
				global_transform.origin = at + drag_offset
