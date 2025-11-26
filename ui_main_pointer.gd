extends OpenXRCompositionLayerQuad

const NO_INTERSECTION = Vector2(-1.0, -1.0)

@export var controller: XRController3D
@export var button_action: String = "index_pinch"

var was_pressed := false
var was_intersect := NO_INTERSECTION

func _intersect_to_global_pos(intersect : Vector2) -> Vector3:
	if intersect != NO_INTERSECTION:
		var local_pos : Vector2 = (intersect - Vector2(0.5, 0.5)) * quad_size
		return global_transform * Vector3(local_pos.x, -local_pos.y, 0.0)
	else:
		return Vector3()

func _intersect_to_viewport_pos(intersect : Vector2) -> Vector2i:
	if layer_viewport and intersect != NO_INTERSECTION:
		var pos : Vector2 = intersect * Vector2(layer_viewport.size)
		return Vector2i(pos)
	else:
		return Vector2i(-1, -1)

func _process(_delta):
	$Pointer.visible = false

	if controller and layer_viewport:
		var t := controller.global_transform
		var intersect := intersects_ray(t.origin, -t.basis.z)

		if intersect != NO_INTERSECTION:
			var is_pressed := controller.is_button_pressed(button_action)

			$Pointer.visible = true
			$Pointer.global_position = _intersect_to_global_pos(intersect)

			if was_intersect != NO_INTERSECTION and intersect != was_intersect:
				var event := InputEventMouseMotion.new()
				event.position = _intersect_to_viewport_pos(intersect)
				layer_viewport.push_input(event)

			if is_pressed and not was_pressed:
				var event := InputEventMouseButton.new()
				event.position = _intersect_to_viewport_pos(intersect)
				event.pressed = true
				event.button_index = 1
				layer_viewport.push_input(event)

			if was_pressed and not is_pressed:
				var event := InputEventMouseButton.new()
				event.position = _intersect_to_viewport_pos(intersect)
				event.pressed = false
				event.button_index = 1
				layer_viewport.push_input(event)

			was_pressed = is_pressed
			was_intersect = intersect
		else:
			was_pressed = false
			was_intersect = NO_INTERSECTION
