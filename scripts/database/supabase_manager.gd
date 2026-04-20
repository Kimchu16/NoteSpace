extends Node

var supabase: SupabaseDatabase

func _ready():
	supabase = Supabase.database
	supabase.connect("selected", _on_selected)
	# print("Supabase initialized!")

	# Test connection by fetching notes
	#test_connection()

func test_connection():
	var query = SupabaseQuery.new().from("notes").select()
	var task = supabase.query(query)
	
	await task.completed # Pauses this function until the database query finishes so the result is ready to use
	
	var result = task.data
	# print("Query result: ", result)

func _on_selected(result: Array):
	if result == null:
		# print("Query failed!")
		return

	# print("Notes found: ", result.size())
