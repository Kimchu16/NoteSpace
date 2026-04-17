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
	#print("Fetching tag_ids for note_id:", note_id)
	var query = SupabaseQuery.new().from("note_tags")\
		.select(["tag_id"])\
		.eq("note_id", str(note_id))
		
	var task = Supabase.database.query(query)
	await task.completed

	if task.error != null:
		printerr(
			"Failed loading note_tags for note_id: ", note_id,
			" | code: ", task.error.code,
			" | message: ", task.error.message,
			" | details: ", task.error.details,
			" | hint: ", task.error.hint
		)
		return []
	#print("Task completed, task data:", task.data)
	
	var tag_ids: Array = []
	if task.data:
		for tag_data in task.data:
			#print("Found tag_id:", str(tag_data["tag_id"]))
			tag_ids.append(int(tag_data["tag_id"]))
	
	# Resolve tags through user's tags list so it works with schemas that use either id or tag_id.
	var user_tags = await TagsService.get_user_tags()
	var tags_by_id: Dictionary = {}
	for tag_model in user_tags:
		if tag_model.tag_id != -1:
			tags_by_id[tag_model.tag_id] = tag_model

	var tags: Array[TagModel] = []
	var seen: Dictionary = {}
	for tag_id in tag_ids:
		if tags_by_id.has(tag_id) and not seen.has(tag_id):
			tags.append(tags_by_id[tag_id])
			seen[tag_id] = true
		else:
			print("No user tag found for tag_id:", tag_id)
		
	print("Returning tags:", tags)
	return tags

func _note_has_tag(note_id: int, tag_id: int) -> bool:
	var tags = await load_tags_for_note(note_id)
	for tag in tags:
		if tag.tag_id == tag_id:
			return true
	return false

func add_tags_to_note(note_id: int, tag_ids: Array) -> bool:
	if note_id == -1 or tag_ids.size() == 0:
		return false
		
	for tag_id in tag_ids:
		var note_tag_data = {
			"note_id": note_id,
			"tag_id": tag_id
		}
			
		# Insert the relationship into note_tags table
		var query = SupabaseQuery.new().from("note_tags").insert([note_tag_data])
		var task: DatabaseTask = Supabase.database.query(query)
		await task.completed

		if task.error != null:
			# 23505 => unique_violation, relation already exists.
			if str(task.error.code) == "23505":
				print("Tag relationship already exists for note_id: ", note_id, " and tag_id: ", tag_id)
				continue
			printerr(
				"Failed to add tag relationship for note_id: ", note_id,
				" and tag_id: ", tag_id,
				" | code: ", task.error.code,
				" | message: ", task.error.message,
				" | details: ", task.error.details,
				" | hint: ", task.error.hint
			)
			return false

		if not await _note_has_tag(note_id, tag_id):
			printerr("Tag insert did not persist for note_id: ", note_id, " and tag_id: ", tag_id)
			return false
	
	print("Tags successfully added to note.")
	return true

func remove_tag_from_note(note_id: int, tag_id: int) -> bool:
	# Delete the tag-note relationship from the note_tags table
	var query = SupabaseQuery.new().from("note_tags")\
	.delete()\
	.eq("note_id", str(note_id))\
	.eq("tag_id", str(tag_id))
	
	var task: DatabaseTask = Supabase.database.query(query)
	await task.completed

	if task.error != null:
		printerr(
			"Failed to remove tag from note. note_id: ", note_id,
			" | tag_id: ", tag_id,
			" | code: ", task.error.code,
			" | message: ", task.error.message,
			" | details: ", task.error.details,
			" | hint: ", task.error.hint
		)
		return false

	if await _note_has_tag(note_id, tag_id):
		printerr("Tag delete did not persist for note_id: ", note_id, " and tag_id: ", tag_id)
		return false

	print("Tag successfully removed from note.")
	return true
