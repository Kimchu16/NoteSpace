extends Node

func create_note(content: String, is_anchored: bool, color: String) -> NoteModel:
	var user_id = AuthManager.current_user["id"]
	
	var note_data = {
		"context": content,
		"is_anchored": is_anchored,
		"colour": color,
		"owner": user_id
	}
	
	var query = SupabaseQuery.new().from("notes").insert([note_data])
	var task = Supabase.database.query(query)
	await task.completed
	
	if task.data and task.data.size() > 0:
		print("Note created in database")
		return NoteModel.from_dict(task.data[0])
	else:
		push_error("Failed to create note in database")
		return null

func get_user_notes() -> Array[NoteModel]:
	var query = SupabaseQuery.new().from("notes").select()
	var task = Supabase.database.query(query)
	await task.completed
	
	var notes: Array[NoteModel] = []
	if task.data:
		for note_data in task.data:
			notes.append(NoteModel.from_dict(note_data))
	
	return notes

func get_note_by_id(note_id: int) -> NoteModel:
	var query = SupabaseQuery.new()\
		.from("notes")\
		.select()\
		.eq("id", str(note_id))

	var task = Supabase.database.query(query)
	await task.completed
	print("Query result:", task.data)

	if task.data and task.data.size() > 0:
		return NoteModel.from_dict(task.data[0]) # ID column

	return null

func update_note_content(note_id: int, new_content: String) -> bool:
	if note_id == -1:
		return false
	
	var query = SupabaseQuery.new()\
		.from("notes")\
		.update({"context": new_content})\
		.eq("id", str(note_id))
	
	var task = Supabase.database.query(query)
	await task.completed
	
	return task.data != null

func delete_note(note_id: int) -> bool:
	if note_id == -1:
		return false
	
	var query = SupabaseQuery.new()\
		.from("notes")\
		.delete()\
		.eq("id", str(note_id))
	
	var task = Supabase.database.query(query)
	await task.completed
	
	if task.data != null:
		print("Note deleted from database")
		return true
	return false

func update_anchored_state(note_id: int, state: bool):
	if note_id == -1:
		return false
	
	var query = SupabaseQuery.new()\
		.from("notes")\
		.update({"is_anchored": state})\
		.eq("id", str(note_id))
	
	var task = Supabase.database.query(query)
	await task.completed
	
	return task.data != null
