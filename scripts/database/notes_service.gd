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

func load_tags_for_note(note_id: int) -> Array[TagModel]:
	# Fetch the tag_ids associated with the note from note_tags
	var query = SupabaseQuery.new().from("note_tags")\
		.select(["tag_id"])\
		.eq("note_id", str(note_id))
		
	var task = Supabase.database.query(query)
	await task.completed
	
	var tag_ids: Array = []
	if task.data:
		for tag_data in task.data:
			tag_ids.append(tag_data["tag_id"])
	
	# Fetch the tags based on tag_ids
	var tags: Array[TagModel] = []
	for tag_id in tag_ids:
		var tag_query = SupabaseQuery.new().from("tags")\
		.select(["tag_name", "tag_id"])\
		.eq("tag_id", str(tag_id))
		
		var tag_task = Supabase.database.query(tag_query)
		await tag_task.completed
		
		if tag_task.data:
			var tag_model = TagModel.from_dict(tag_task.data[0])
			tags.append(tag_model)
			
	return tags

func add_tags_to_note(note_id: int, tag_ids: Array) -> bool:
	if note_id == -1 or tag_ids.size() == 0:
		return false
		
	for tag_id in tag_ids:
		var note_tag_data = {
			"note_id": note_id,
			"tag_id": tag_id,
			}
			
		# Insert the relationship into note_tags table
		var query = SupabaseQuery.new().from("note_tags").insert([note_tag_data])
		var task = Supabase.database.query(query)
		await task.completed
		
		if not task.data:
			printerr("Failed to add tag relationship for note_id: ", note_id, " and tag_id: ", tag_id)
			return false
	
	print("Tags successfully added to note.")
	return true

func remove_tag_from_note(note_id: int, tag_id: int) -> bool:
	# Delete the tag-note relationship from the note_tags table
	var query = SupabaseQuery.new().from("note_tags")\
	.delete()\
	.eq("note_id", str(note_id))\
	.eq("tag_id", str(tag_id))
	
	var task = Supabase.database.query(query)
	await task.completed
	
	if task.data:
		print("Tag successfully removed from note.")
		return true
	else:
		printerr("Failed to remove tag from note.")
		return false
