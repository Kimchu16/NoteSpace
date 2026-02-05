extends Node

var db

func _ready():
	# Wait a frame to ensure SupabaseManager is ready
	await get_tree().process_frame
	db = SupabaseManager.supabase

func create_note(content: String, position: Vector3, color: String) -> NoteModel:
	var note_data = {
		"context": content,
		"pos_x": position.x,
		"pos_y": position.y,
		"pos_z": position.z,
		"colour": color
	}
	
	var query = SupabaseQuery.new().from("notes").insert(note_data)
	var task = db.query(query)
	await task.completed
	
	if task.data and task.data.size() > 0:
		print("✓ Note created in database")
		return NoteModel.from_dict(task.data[0])
	else:
		push_error("Failed to create note in database")
		return null

func get_all_notes() -> Array[NoteModel]:
	var query = SupabaseQuery.new().from("notes").select()
	var task = db.query(query)
	await task.completed
	
	var notes: Array[NoteModel] = []
	if task.data:
		for note_data in task.data:
			notes.append(NoteModel.from_dict(note_data))
	
	return notes

func update_note_position(note_id: int, new_position: Vector3) -> bool:
	if note_id == -1:
		return false  # Note not saved yet
	
	var update_data = {
		"pos_x": new_position.x,
		"pos_y": new_position.y,
		"pos_z": new_position.z
	}
	
	var query = SupabaseQuery.new()\
		.from("notes")\
		.update(update_data)\
		.eq("id", str(note_id))
	
	var task = db.query(query)
	await task.completed
	
	return task.data != null

func update_note_content(note_id: int, new_content: String) -> bool:
	if note_id == -1:
		return false
	
	var query = SupabaseQuery.new()\
		.from("notes")\
		.update({"context": new_content})\
		.eq("id", str(note_id))
	
	var task = db.query(query)
	await task.completed
	
	return task.data != null

func delete_note(note_id: int) -> bool:
	if note_id == -1:
		return false
	
	var query = SupabaseQuery.new()\
		.from("notes")\
		.delete()\
		.eq("id", str(note_id))
	
	var task = db.query(query)
	await task.completed
	
	if task.data != null:
		print("✓ Note deleted from database")
		return true
	return false
