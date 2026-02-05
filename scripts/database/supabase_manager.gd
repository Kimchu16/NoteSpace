extends Node

var supabase: SupabaseDatabase

func _ready():
	await get_tree().process_frame
	supabase = Supabase.database
	supabase.connect("selected", _on_selected)
	print("Supabase initialized!")

	# Test connection by fetching notes
	test_connection()


func test_connection():
	print("Sending Supabase query...")
	var query = SupabaseQuery.new().from("notes").select()
	var task = supabase.query(query)
	
	await task.completed
	
	var result = task.data
	print("Query result: ", result)

func _on_selected(result: Array):
	if result == null:
		print("Query failed!")
		return

	print("Notes found: ", result.size())
