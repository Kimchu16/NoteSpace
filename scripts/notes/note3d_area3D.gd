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
var note: Note3D
var notes_root: Node3D

enum PlacementState { FREE, SNAP_PREVIEW }
var placement_state = PlacementState.FREE

const SNAP_ENTER_DISTANCE = 0.25
const SNAP_EXIT_DISTANCE = 0.251

var snapped_surface: Node = null
var spatial_anchor_manager: OpenXRFbSpatialAnchorManager

var anchor_uuid : String = ""
var pending_note_for_anchor : Node3D = null
const SPATIAL_ANCHORS_FILE = "user://spatial_anchors.json"

func _ready() -> void:
	note = get_parent().get_parent()
	notes_root = get_tree().get_first_node_in_group("Notes")
	xr_controller_l = get_tree().get_first_node_in_group("LeftController")
	xr_controller_r = get_tree().get_first_node_in_group("RightController")
	toolbar = get_parent().get_node("Toolbar")
	pointer_event.connect(_on_pointer_event)
	xr_controller_l.connect("button_pressed", _on_left_hand_pressed)
	spatial_anchor_manager =  get_tree().get_nodes_in_group("Managers")[1]
	spatial_anchor_manager.connect("openxr_fb_spatial_anchor_tracked", _on_anchor_tracked)

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

		XRToolsPointerEvent.Type.RELEASED:
			#print("Pointer released Note")
			is_dragged = false
			dragging_pointer = null
			
			if placement_state == PlacementState.FREE or placement_state == PlacementState.SNAP_PREVIEW:
				#if note.anchored != true:
				create_spatial_anchor_and_parent()

		XRToolsPointerEvent.Type.MOVED:
			if is_hovering and is_pressed:
				toolbar.visible = true
			elif is_hovering and !is_pressed:
				toolbar.visible = false

func _update_free_drag() -> void:
	var camera = get_viewport().get_camera_3d()
	var space_state = get_world_3d().direct_space_state
	
	# Depth Control ----------------------------------
	var current_hand_position = xr_controller_r.global_position
	var hand_delta = current_hand_position - previous_hand_position
	
	var forward = -xr_controller_r.global_transform.basis.z
	var depth_delta = hand_delta.dot(forward)
	
	drag_distance += depth_delta
	drag_distance = clamp(drag_distance, 0.2, 3.0)
	
	previous_hand_position = current_hand_position
	
	var target_position = xr_controller_r.global_position + forward * drag_distance
	
	# Movement Collision Clamp ---------------------------------------
	var motion = target_position - note.global_position
	var ray_origin = note.global_position
	var ray_end = note.global_position + motion

	var clamp_query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	clamp_query.collision_mask = 1 << 5  # SceneSurfaces only

	var clamp_result = space_state.intersect_ray(clamp_query)

	if clamp_result:
		var collider = clamp_result.collider
		if collider and collider.is_in_group("valid_surfaces"):
			var hit_position = clamp_result.position
			var normal = clamp_result.normal
			
			# Stop slightly before surface
			target_position = hit_position + normal * 0.02

	# Smooth movement
	note.global_position = note.global_position.lerp(target_position, 0.2)
	
	# Snap Detection---------------------------------------------------
	var note_forward = -note.visual_root.global_transform.basis.z
	var snap_origin = note.global_position
	var snap_end = snap_origin + note_forward * 0.4
	
	var query = PhysicsRayQueryParameters3D.create(snap_origin, snap_end)
	query.collision_mask = 1 << 5  # SceneSurfaces layer

	var result = space_state.intersect_ray(query)
	
	var hit_position: Vector3
	var hit_normal: Vector3
	var candidate_surface: Node = null
	var distance_to_surface: float = INF
	
	if result:
		var collider = result.collider
		if collider.is_in_group("valid_surfaces"):
			hit_position = result.position
			hit_normal = result.normal
			candidate_surface = collider
			
			# Distance threshold check
			distance_to_surface = note.global_position.distance_to(hit_position)

	# State Update (Hysteresis) ---------------------------------------------------
	if placement_state == PlacementState.FREE:
		if candidate_surface and distance_to_surface < SNAP_ENTER_DISTANCE:
			placement_state = PlacementState.SNAP_PREVIEW
			snapped_surface = candidate_surface
	
	elif placement_state == PlacementState.SNAP_PREVIEW:
		if not candidate_surface or distance_to_surface > SNAP_EXIT_DISTANCE:
			placement_state = PlacementState.FREE
			snapped_surface = null

	# Apply Transform ----------------
	if placement_state == PlacementState.SNAP_PREVIEW  and snapped_surface:
		_apply_surface_snap(hit_position, hit_normal)
	else:
		_apply_billboard(camera)

func _apply_billboard(camera: Camera3D):
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
	var desired_global_basis = Basis.from_euler(Vector3(-pitch, yaw, 0))
	
	# Convert WORLD basis -> LOCAL basis under Note3D
	var parent_global_basis = note.global_transform.basis
	note.visual_root.transform.basis = parent_global_basis.inverse() * desired_global_basis

func _apply_surface_snap(hit_position: Vector3, normal: Vector3) -> void:
	var offset = 0.02  # avoid z-fighting
	var snap_position = hit_position + normal * offset
	
	note.global_position = note.global_position.lerp(snap_position, 0.3)
	
	# Align note to surface
	var forward = normal.normalized()
	var reference = Vector3.UP
	
	if abs(forward.dot(reference)) > 0.95: # Is forward almost parallel to reference?
		reference = Vector3.FORWARD  # if surface is horizontal, use different axis (prevents y axis flickering)
	
	var right = reference.cross(forward).normalized()
	var up = forward.cross(right).normalized()
	
	var desired_global_basis = Basis(right, up, forward)
	
	# Convert WORLD basis -> LOCAL basis under Note3D
	var parent_global_basis = note.global_transform.basis
	note.visual_root.transform.basis = parent_global_basis.inverse() * desired_global_basis

func delete_spatial_anchor() -> void: #TODO: Delete anchor when deleting note
	if note.anchor_uuid == "":
		return
		
	print("Deleting anchor:", note.anchor_uuid)
	spatial_anchor_manager.untrack_anchor(note.anchor_uuid)
	note.anchored = false
	note.anchor_uuid = ""

func create_spatial_anchor_and_parent() -> void:
	pending_note_for_anchor = get_parent().get_parent()
	print("Pending_note_for_anchor: ", pending_note_for_anchor)
	
	# Apply current visual root rotation
	var visual_global_basis = pending_note_for_anchor.visual_root.global_transform.basis
	var parent_basis = pending_note_for_anchor.get_parent().global_transform.basis
	pending_note_for_anchor.transform.basis = parent_basis.inverse() * visual_global_basis
	pending_note_for_anchor.visual_root.transform.basis = Basis.IDENTITY
	
	var note_transform = pending_note_for_anchor.global_transform
	
	# Create a new spatial anchor at the note's current position
	var custom_data: Dictionary = {
		"note_id": pending_note_for_anchor.note_model.id
	}
	spatial_anchor_manager.create_anchor(note_transform, custom_data)

# Gets called after create_anchor (or load_anchor but this code block doesn't run for load)
func _on_anchor_tracked(anchor_node: Object, spatial_entity: Object, is_new: bool) -> void:
	print("Anchor tracked successfully.")
	
	print("Note: ", note, " || pending_note_for_anchor: ", pending_note_for_anchor)
	if note != pending_note_for_anchor:
		return
	
	var old_anchor_uuid = note.anchor_uuid
	print("Note: ", note)
	print ("old anchor uuid: ", old_anchor_uuid)
	
	if spatial_entity:
		# Get the corresponding XRAnchor3D node for the spatial entity
		anchor_node = spatial_anchor_manager.get_anchor_node(spatial_entity.uuid)  # Get the XRAnchor3D node
		print("SE custom data: ",spatial_entity.get_custom_data())
		
		note.anchor_uuid = spatial_entity.uuid
		print("Note: ", note, " with UUID: ", note.anchor_uuid)
		
	if is_new: # New anchored created
		print("New anchor tracked.")
		
		if pending_note_for_anchor == null:
			return  # Ignore anchors not created by this note
		
		note = pending_note_for_anchor
		pending_note_for_anchor = null
		
		if anchor_node:
			#var global = note.global_transform
			print("This note: ",note)
			note.get_parent().remove_child(note)
			anchor_node.add_child(note)  # Attach the note to the anchor node
			#note.global_transform = global
			note.position = Vector3.ZERO
			note.rotation = Vector3.ZERO
			note.anchored = true
			
			var anchor_data: Dictionary
			
			# READ existing file if exists
			if FileAccess.file_exists(SPATIAL_ANCHORS_FILE):
				var read_file = FileAccess.open(SPATIAL_ANCHORS_FILE, FileAccess.READ)
				
				var json := JSON.new()
				if json.parse(read_file.get_as_text()) != OK:
					print("ERROR: Unable to parse ", SPATIAL_ANCHORS_FILE)
					pass
				else:
					anchor_data = json.data
					print("parsed json: ", JSON.stringify(anchor_data))
				
				read_file.close()
			
			# UPDATE anchor data
			anchor_data[note.anchor_uuid] = spatial_entity.get_custom_data()	
			
			if old_anchor_uuid != "":
				spatial_anchor_manager.untrack_anchor(old_anchor_uuid)
				anchor_data.erase(old_anchor_uuid)
				
			# WRITE updated data
			var write_file := FileAccess.open(SPATIAL_ANCHORS_FILE, FileAccess.WRITE)
			if not write_file:
				print("ERROR: Unable to open file for writing: ", SPATIAL_ANCHORS_FILE)
				return
			
			var stringified_json = JSON.stringify(anchor_data)
			write_file.store_string(stringified_json)
			write_file.close()
			
			print("new stringified json: ", stringified_json)
			print("------------------------------------------------------------------------")

func _process(delta: float) -> void:
	if not is_dragged:
		return
	
	_update_free_drag()
