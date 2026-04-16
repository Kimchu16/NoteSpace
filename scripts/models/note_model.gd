class_name NoteModel
extends RefCounted

var id: int = -1  # -1 means not saved to database yet
var content: String = ""
var colour: String = "yellow"
var is_anchored: bool = false
var created_at: String = ""
var updated_at: String = ""

# Create from database result
static func from_dict(data: Dictionary) -> NoteModel:
	var note = NoteModel.new()
	note.id = int(data.get("id", -1))
	note.content = data.get("context", "")
	note.colour = data.get("colour", "yellow")  
	note.is_anchored = data.get("is_anchored", false)
	
	note.created_at = data.get("created_at", "")
	note.updated_at = data.get("updated_at", "")
	
	return note

# Convert to dictionary for database
func to_dict() -> Dictionary:
	return {
		"context": content,
		"colour": colour
	}

func get_godot_colour() -> Color:
	match colour.to_lower():
		"yellow": return Color.YELLOW
		"blue": return Color.CORNFLOWER_BLUE
		"green": return Color.LIGHT_GREEN
		"purple": return Color.MEDIUM_PURPLE
		_: return Color.YELLOW
