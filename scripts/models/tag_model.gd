class_name TagModel
extends RefCounted

var tag_id: int = -1
var tag_name: String = ""
var description: String = ""
var owner: String = "" 

var created_at: String = ""
var updated_at: String = ""

# Create from database result
static func from_dict(data: Dictionary) -> TagModel:
	var tag = TagModel.new()
	tag.tag_id = int(data.get("tag_id", -1))
	tag.tag_name = data.get("tag_name", "")
	tag.description = data.get("description", "")
	tag.owner = data.get("owner", "")

	tag.created_at = data.get("created_at", "")
	tag.updated_at = data.get("updated_at", "")

	return tag

# Convert to dictionary for database
func to_dict() -> Dictionary:
	return {
		"tag_name": tag_name,
		"description": description,
		"owner": owner
	}
