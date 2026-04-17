extends Node

func create_tag(tag_name: String, description: String) -> TagModel:
	var user_id = AuthManager.current_user["id"]

	var tag_data = {
		"tag_name": tag_name,
		"description": description,
		"owner": user_id
	}

	var query = SupabaseQuery.new().from("tags").insert([tag_data])
	var task = Supabase.database.query(query)
	await task.completed

	if task.data and task.data.size() > 0:
		print("Tag created in database")
		return TagModel.from_dict(task.data[0])
	else:
		push_error("Failed to create tag in database")
		return null

func get_user_tags() -> Array[TagModel]:
	var user_id = AuthManager.current_user["id"]
	var query = SupabaseQuery.new().from("tags").select().eq("owner", user_id)
	var task = Supabase.database.query(query)
	await task.completed

	var tags: Array[TagModel] = []
	if task.data:
		for tag_data in task.data:
			tags.append(TagModel.from_dict(tag_data))

	return tags

func get_tag_by_id(tag_id: int) -> TagModel:
	var query = SupabaseQuery.new().from("tags").select().eq("tag_id", str(tag_id))
	var task = Supabase.database.query(query)
	await task.completed

	if task.data and task.data.size() > 0:
		return TagModel.from_dict(task.data[0])
	return null

func update_tag(tag_id: int, new_name: String, new_description: String) -> TagModel:
	if tag_id == -1:
		return null

	var query = SupabaseQuery.new()\
		.from("tags")\
		.update({"tag_name": new_name, "description": new_description})\
		.eq("tag_id", str(tag_id))

	var task = Supabase.database.query(query)
	await task.completed

	if task.data and task.data.size() > 0:
		return TagModel.from_dict(task.data[0])
	else:
		push_error("Failed to return TagModel")
		return null

func delete_tag(tag_id: int) -> bool:
	if tag_id == -1:
		return false

	var query = SupabaseQuery.new()\
		.from("tags")\
		.delete()\
		.eq("tag_id", str(tag_id))

	var task = Supabase.database.query(query)
	await task.completed

	if task.data != null:
		print("Tag deleted from database")
		return true
	return false
