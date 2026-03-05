class_name NoteModel
extends RefCounted

var id: int = -1  # -1 means not saved to database yet
var content: String = ""
var position: Vector3 = Vector3.ZERO
var colour: String = "yellow"
var created_at: String = ""
var updated_at: String = ""

# Create from database result
static func from_dict(data: Dictionary) -> NoteModel:
	var note = NoteModel.new()
	note.id = int(data.get("id", -1))
	note.content = data.get("context", "")  # DB uses "context"
	note.colour = data.get("colour", "yellow")  # DB uses "colour"
	
	# Handle null positions
	var x = data.get("pos_x")
	var y = data.get("pos_y")
	var z = data.get("pos_z")
	note.position = Vector3(
		x if x != null else 0.0,
		y if y != null else 0.0,
		z if z != null else 0.0
	)
	
	note.created_at = data.get("created_at", "")
	note.updated_at = data.get("updated_at", "")
	
	return note

# Convert to dictionary for database
func to_dict() -> Dictionary:
	return {
		"context": content,
		"pos_x": position.x,
		"pos_y": position.y,
		"pos_z": position.z,
		"colour": colour
	}

func get_godot_colour() -> Color:
	match colour.to_lower():
		"yellow": return Color.YELLOW
		"blue": return Color.BLUE
		"green": return Color.GREEN
		"purple": return Color.PURPLE
		_: return Color.YELLOW
