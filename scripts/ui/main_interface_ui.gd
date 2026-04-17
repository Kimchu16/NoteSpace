extends CanvasLayer

@export var notes_root: Node3D
@onready var menu_notes:VBoxContainer = $Control/ColorRect/MarginContainer/VBoxContainer/MarginContainer5/ScrollContainer/MenuNotes
@onready var settings_menu: MarginContainer = $Control/ColorRect/SettingsMenu
@onready var main_menu: MarginContainer = $Control/ColorRect/MarginContainer
@onready var colour_chosen: Panel = $Control/ColorRect/MarginContainer/VBoxContainer/MarginContainer2/HBoxContainer2/ColorBtn/Panel
@onready var tag_menu: MarginContainer = $Control/ColorRect/TagMenu
@onready var tag_editor: MarginContainer = $Control/ColorRect/TagEditor
@onready var tag_container: VBoxContainer = $Control/ColorRect/TagMenu/VBoxContainer/MarginContainer6/ScrollContainer/Tags
@onready var tag_scene = preload("res://scenes/ui/tags/menu_tag.tscn")
@onready var tag_editor_name = $Control/ColorRect/TagEditor/VBoxContainer/Name/LineEdit
@onready var tag_editor_desc = $Control/ColorRect/TagEditor/VBoxContainer/Desc/LineEdit
@onready var tag_editor_save_btn = $Control/ColorRect/TagEditor/VBoxContainer/MarginContainer2/HBoxContainer2/SaveBtn
@onready var tag_editor_del_btn = $Control/ColorRect/TagEditor/VBoxContainer/MarginContainer2/HBoxContainer2/DeleteBtn
@onready var tag_count_label = $Control/ColorRect/TagMenu/VBoxContainer/MarginContainer3/GridContainer/HBoxContainer/Label2
@onready var note_count_label = $Control/ColorRect/MarginContainer/VBoxContainer/MarginContainer3/GridContainer/HBoxContainer/Label2
@onready var tag_name_input = $Control/ColorRect/TagEditor/VBoxContainer/Name/LineEdit
@onready var tag_desc_input = $Control/ColorRect/TagEditor/VBoxContainer/Desc/LineEdit
@onready var notes_search_input: LineEdit = $Control/ColorRect/MarginContainer/VBoxContainer/MarginContainer4/VBoxContainer/Searchbar
@onready var tags_search_input: LineEdit = $Control/ColorRect/TagMenu/VBoxContainer/MarginContainer5/Searchbar
@onready var filter_extension: PanelContainer = $Control/ColorRect/FilterExtension
@onready var filter_tags_container: HFlowContainer = $Control/ColorRect/FilterExtension/MarginContainer/VBoxContainer/MarginContainer4/HFlowContainer

var spatial_anchor_manager: OpenXRFbSpatialAnchorManager
var opened_spawn_button: Button = null
var notes_by_id: Dictionary

var note_scene = preload("res://scenes/notes/note3D.tscn")
var menu_note_scene = preload("res://scenes/ui/note_main_interface.tscn")
var filter_tag_scene = preload("res://scenes/ui/tags/tag_button.tscn")

var default_colour: String = "Yellow"
var is_new_tag: bool = false
var tag_count: int = 0
var note_count: int = 0
var ui_panel: Node3D
var edit_tag_instance: MenuTag = null
var selected_note_colours: Dictionary = {}
var selected_filter_tag_ids: Dictionary = {}

func _ready() -> void:
	AuthManager.login_success.connect(_on_user_logged_in)
	AuthManager.auth_checked.connect(_on_auth_checked)
	AuthManager.logout_success.connect(_on_user_logged_out)
	if notes_root == null:
		notes_root = get_tree().get_first_node_in_group("Notes")
	
	spatial_anchor_manager =  get_tree().get_nodes_in_group("Managers")[1]
	ui_panel = get_tree().get_first_node_in_group("MainUI3D")
	_connect_search_inputs()

func _on_auth_checked(is_logged_in):
	if is_logged_in:
		#await load_notes_from_database()
		#await load_tags_from_database()
		print("load notes on auth checked")

func _on_user_logged_in(user):
	print("User authenticated -> loading notes...")
	clear_menu_notes()
	clear_menu_tags()
	await load_notes_from_database()
	await load_tags_from_database()
	print("load notes on user logged in")

func _on_user_logged_out():
	print("User logged out -> clearing notes")
	clear_menu_notes()
	clear_menu_tags()
	notes_by_id.clear()

func clear_menu_notes():
	print("Clearing menu notes...")
	for child in menu_notes.get_children():
		child.queue_free()

func clear_menu_tags():
	print("Clearing menu tags...")
	for child in tag_container.get_children():
		child.queue_free()
	_clear_filter_tag_buttons()
	selected_filter_tag_ids.clear()

func load_notes_from_database() -> void:
	var notes = await NotesService.get_user_notes()
	note_count = notes.size()
	note_count_label.text = str(note_count)
	print("Loading ", notes.size(), " notes from database...")
	
	for note_model in notes:
		var menu_note_instance: MenuNote = menu_note_scene.instantiate()
		menu_notes.add_child(menu_note_instance)
		menu_note_instance.set_note_data(note_model)
		print("note model id: ", note_model.id)
		await menu_note_instance.update_tags_for_note(note_model.id)
		menu_note_instance.spawn_note_button_pressed.connect(_on_spawn_note_requested)
		
		if note_model.is_anchored: # If note is placed
			menu_note_instance.is_note_placed = true
		else:
			menu_note_instance.is_note_placed = false
			
		menu_note_instance.highlight_note.connect(_on_highlight_note)
	
	_apply_notes_filter(notes_search_input.text)

func load_tags_from_database() -> void:
	var tags = await TagsService.get_user_tags()
	tag_count = tags.size()
	tag_count_label.text = str(tag_count)
	print("Loading ", tags.size(), " tags from database...")
	
	for tag_model in tags:
		var tag_instance: MenuTag = tag_scene.instantiate()
		tag_container.add_child(tag_instance)
		tag_instance.set_tag_data(tag_model)
		tag_instance.edit_note_button_pressed.connect(_on_tag_edit_requested)
	
	_rebuild_filter_tag_buttons(tags)
	_apply_tags_filter(tags_search_input.text)

func register_note(note_instance: Note3D):
	notes_by_id[note_instance.note_model.id] = note_instance

func unregister_note(note_instance: Note3D):
	notes_by_id.erase(note_instance.note_model.id)
	_update_note_count("minus")

func _on_highlight_note(note_model):
	if notes_by_id.has(note_model.id):
		notes_by_id[note_model.id].highlight()

func refresh_note_tags(note_id: int) -> void:
	for child in menu_notes.get_children():
		if child is MenuNote and child.note_model.id == note_id:
			await child.update_tags_for_note(note_id)
			_apply_notes_filter(notes_search_input.text)
			return

func _on_spawn_note_requested(note_model: NoteModel, menu_note: MenuNote) -> void:
	spawn_note(note_model)
	menu_note.spawn_button.visible = false
	menu_note.is_note_placed = true
	note_model.is_anchored = true

func spawn_note(note_model: NoteModel) -> void:
	var hmd = XRServer.get_hmd_transform()
	var forward = -hmd.basis.z
	var spawn_position = hmd.origin + forward * 0.5
	var note_instance: Note3D = note_scene.instantiate()
	notes_root.add_child(note_instance)
	print("Spawn note id: ", note_model.id, " | node name: ", note_instance.name)
	
	# Set position
	note_instance.global_position = hmd.origin + forward * 0.5
	
	note_instance.set_note_data(note_model)
	print("CALLED NOTE3D TAGS FOR NOTE: ", note_model.id)
	note_instance.update_tags_for_note(note_model.id)
	register_note(note_instance)

func request_spawn_button(button: Button) -> void:
	if opened_spawn_button == button:
		button.visible = false
		opened_spawn_button = null
		return
	
	if opened_spawn_button:
		opened_spawn_button.visible = false
	
	opened_spawn_button = button
	button.visible = true

func _on_create_button_pressed() -> void:
	# Create in database
	var note_model = await NotesService.create_note(
		"",  # Default content
		true,
		default_colour
	)
	
	if note_model:
		spawn_note(note_model)
		print(note_model)
	else:
		printerr("note model null")
	
	_update_note_count("plus")

func _on_note_returned_to_main_interface(note_model: NoteModel) -> void:
	for child in menu_notes.get_children():
		if child is MenuNote and child.note_model.id == note_model.id:
			child.is_note_placed = false
			break

func _on_settings_btn_pressed() -> void:
	main_menu.visible = false
	settings_menu.visible = true

func _on_back_btn_pressed() -> void:
	main_menu.visible = true
	settings_menu.visible = false
	tag_menu.visible = false

func _return_to_tag_menu() -> void:
	tag_editor.visible = false
	tag_menu.visible = true
	_reset_tag_editor()

func _on_logout_btn_pressed() -> void:
	AuthManager.logout()

func _on_color_btn_pressed() -> void:
	$Control/ColorRect/ColourExtension.visible = !$Control/ColorRect/ColourExtension.visible

func _on_tag_btn_pressed() -> void:
	main_menu.visible = false
	tag_menu.visible = true

func _on_colour_pick_pressed(colour: String) -> void:
	#var style_box = StyleBoxFlat.new()
	var style_box = colour_chosen.get_theme_stylebox("panel").duplicate()
	if colour == "blue":
		style_box.bg_color = Color.CORNFLOWER_BLUE
		default_colour = "blue"
	elif colour == "yellow":
		style_box.bg_color = Color.YELLOW
		default_colour = "yellow"
	elif colour == "purple":
		style_box.bg_color = Color.MEDIUM_PURPLE
		default_colour = "purple"
	elif colour == "green":
		style_box.bg_color = Color.LIGHT_GREEN
		default_colour = "green"
	else:
		printerr("Invalid colour picked")
	
	colour_chosen.add_theme_stylebox_override("panel", style_box)

func _on_tag_edit_requested(tag_instance: MenuTag) -> void:
	print("edit tag pressed: ", tag_instance)
	edit_tag_instance = tag_instance
	tag_menu.visible = false
	tag_editor.visible = true
	tag_editor_name.text = tag_instance.tag_data.tag_name
	tag_editor_desc.text = tag_instance.tag_data.description
	tag_editor_save_btn.pressed.connect(_on_save_btn_pressed)
	tag_editor_del_btn.pressed.connect(_on_tag_delete_btn_pressed)

func _on_save_btn_pressed():
	print("button pressed: ", edit_tag_instance)
	if is_new_tag != true:
		if tag_editor_name.text != "":
			var updated_tag = await TagsService.update_tag(edit_tag_instance.tag_data.tag_id, tag_editor_name.text, tag_editor_desc.text)
			if updated_tag:
				print("Tag updated")
				edit_tag_instance.set_tag_data(updated_tag)
				await _refresh_filter_tag_buttons()
				_apply_tags_filter(tags_search_input.text)
				_return_to_tag_menu()
				_reset_tag_editor()
				edit_tag_instance = null
				return
	
	var tag_model = TagModel.new()
	tag_model.tag_name = tag_editor_name.text
	tag_model.description = tag_editor_desc.text
	tag_model.owner = AuthManager.current_user["id"]
	
	# Save the tag in the database and add to menu list
	var created_tag = await TagsService.create_tag(tag_model.tag_name, tag_model.description)
	if created_tag:
		print("Tag created: ", created_tag.tag_name)
		_update_tag_count("plus")
		var tag_instance: MenuTag = tag_scene.instantiate()
		tag_container.add_child(tag_instance)
		tag_instance.set_tag_data(created_tag)
		tag_instance.edit_note_button_pressed.connect(_on_tag_edit_requested)
		await _refresh_filter_tag_buttons()
		_apply_tags_filter(tags_search_input.text)
	else:
		print("Failed to create tag.")

func _reset_tag_editor() -> void:
	tag_editor_name.text = ""
	tag_editor_desc.text = ""

func _on_create_new_tag_btn_pressed() -> void:
	tag_editor.visible = true
	tag_menu.visible = false
	is_new_tag = true	

func _update_tag_count(operation: String):
	if operation == "plus":
		tag_count = tag_count + 1
		tag_count_label.text = str(tag_count)
	if operation == "minus":
		tag_count = tag_count - 1
		tag_count_label.text = str(tag_count)

func _update_note_count(operation: String):
	if operation == "plus":
		note_count = note_count + 1
		note_count_label.text = str(note_count)
	if operation == "minus":
		note_count = note_count - 1
		note_count_label.text = str(note_count)

func _on_tag_delete_btn_pressed(tag_instance: MenuTag) -> void:
	var tag_id = tag_instance.tag_data.tag_id
	
	if tag_id != -1:
		var success = await TagsService.delete_tag(tag_id)
		if success:
			tag_container.remove_child(tag_instance)
			tag_instance.queue_free()
			print("Tag deleted from UI and database.")
			_update_tag_count("minus")
			await _refresh_filter_tag_buttons()
			_apply_tags_filter(tags_search_input.text)
		else:
			print("Failed to delete tag.")
	else:
		print("Invalid tag ID.")


func _on_blue_pressed() -> void:
	_on_colour_pick_pressed("blue")

func _on_yellow_pressed() -> void:
	_on_colour_pick_pressed("yellow")

func _on_purple_pressed() -> void:
	_on_colour_pick_pressed("purple")

func _on_green_pressed() -> void:
	_on_colour_pick_pressed("green")

func _on_line_edit_focus_entered() -> void:
	KeyboardManager.focus_input(tag_name_input, ui_panel)

func _on_desc_edit_focus_entered() -> void:
	KeyboardManager.focus_input(tag_desc_input, ui_panel)

func _on_line_edit_focus_exited() -> void:
	KeyboardManager.unfocus_input()

func _connect_search_inputs() -> void:
	if not notes_search_input.text_changed.is_connected(_on_notes_search_text_changed):
		notes_search_input.text_changed.connect(_on_notes_search_text_changed)
	if not notes_search_input.focus_entered.is_connected(_on_notes_search_focus_entered):
		notes_search_input.focus_entered.connect(_on_notes_search_focus_entered)
	if not notes_search_input.focus_exited.is_connected(_on_search_focus_exited):
		notes_search_input.focus_exited.connect(_on_search_focus_exited)
	
	if not tags_search_input.text_changed.is_connected(_on_tags_search_text_changed):
		tags_search_input.text_changed.connect(_on_tags_search_text_changed)
	if not tags_search_input.focus_entered.is_connected(_on_tags_search_focus_entered):
		tags_search_input.focus_entered.connect(_on_tags_search_focus_entered)
	if not tags_search_input.focus_exited.is_connected(_on_search_focus_exited):
		tags_search_input.focus_exited.connect(_on_search_focus_exited)

func _on_notes_search_text_changed(new_text: String) -> void:
	_apply_notes_filter(new_text)

func _on_tags_search_text_changed(new_text: String) -> void:
	_apply_tags_filter(new_text)

func _on_notes_search_focus_entered() -> void:
	KeyboardManager.focus_input(notes_search_input, ui_panel)

func _on_tags_search_focus_entered() -> void:
	KeyboardManager.focus_input(tags_search_input, ui_panel)

func _on_search_focus_exited() -> void:
	KeyboardManager.unfocus_input()

func _apply_notes_filter(raw_query: String) -> void:
	var query := raw_query.strip_edges().to_lower()
	
	for child in menu_notes.get_children():
		if child is not MenuNote:
			continue

		var note_text: String = ""
		var note_colour: String = ""
		var note_tags: Array = []
		if child.note_model != null:
			note_text = child.note_model.content.to_lower()
			note_colour = child.note_model.colour.to_lower()
			note_tags = child.note_model.tags
		
		var matches_search = query.is_empty() or note_text.contains(query)
		var matches_colour = selected_note_colours.is_empty() or selected_note_colours.has(note_colour)
		var matches_tags = _note_matches_selected_tags(note_tags)
		child.visible = matches_search and matches_colour and matches_tags

func _apply_tags_filter(raw_query: String) -> void:
	var query := raw_query.strip_edges().to_lower()
	
	for child in tag_container.get_children():
		if child is not MenuTag:
			continue
		
		if query.is_empty():
			child.visible = true
			continue
		
		var tag_name: String = ""
		var tag_description: String = ""
		if child.tag_data != null:
			tag_name = child.tag_data.tag_name.to_lower()
			tag_description = child.tag_data.description.to_lower()
		child.visible = tag_name.contains(query) or tag_description.contains(query)


func _on_filter_pressed() -> void:
	filter_extension.visible = !filter_extension.visible
	if filter_extension.visible and filter_tags_container.get_child_count() == 0:
		_rebuild_filter_tag_buttons(_collect_loaded_menu_tags())

func _on_blue_filter_pressed(toggled_on: bool) -> void:
	_set_note_colour_filter("blue", toggled_on)

func _on_yellow_filter_pressed(toggled_on: bool) -> void:
	_set_note_colour_filter("yellow", toggled_on)

func _on_purple_filter_pressed(toggled_on: bool) -> void:
	_set_note_colour_filter("purple", toggled_on)

func _on_green_filter_pressed(toggled_on: bool) -> void:
	_set_note_colour_filter("green", toggled_on)

func _set_note_colour_filter(colour: String, toggled_on: bool) -> void:
	var normalized_colour := colour.to_lower()
	if toggled_on:
		selected_note_colours[normalized_colour] = true
	else:
		selected_note_colours.erase(normalized_colour)
	_apply_notes_filter(notes_search_input.text)

func _refresh_filter_tag_buttons() -> void:
	var tags = await TagsService.get_user_tags()
	_rebuild_filter_tag_buttons(tags)

func _rebuild_filter_tag_buttons(tags: Array) -> void:
	_clear_filter_tag_buttons()
	
	var valid_tag_ids: Dictionary = {}
	for tag_model in tags:
		if tag_model == null or tag_model.tag_id == -1:
			continue
		
		valid_tag_ids[tag_model.tag_id] = true
		var tag_button: Button = filter_tag_scene.instantiate()
		tag_button.text = tag_model.tag_name
		tag_button.tooltip_text = tag_model.description
		tag_button.button_pressed = selected_filter_tag_ids.has(tag_model.tag_id)
		tag_button.toggled.connect(_on_filter_tag_toggled.bind(tag_model.tag_id))
		filter_tags_container.add_child(tag_button)
	
	for tag_id in selected_filter_tag_ids.keys():
		if not valid_tag_ids.has(tag_id):
			selected_filter_tag_ids.erase(tag_id)
	
	_apply_notes_filter(notes_search_input.text)

func _clear_filter_tag_buttons() -> void:
	for child in filter_tags_container.get_children():
		filter_tags_container.remove_child(child)
		child.queue_free()

func _collect_loaded_menu_tags() -> Array:
	var loaded_tags: Array = []
	for child in tag_container.get_children():
		if child is MenuTag and child.tag_data != null:
			loaded_tags.append(child.tag_data)
	return loaded_tags

func _on_filter_tag_toggled(toggled_on: bool, tag_id: int) -> void:
	if toggled_on:
		selected_filter_tag_ids[tag_id] = true
	else:
		selected_filter_tag_ids.erase(tag_id)
	_apply_notes_filter(notes_search_input.text)

func _note_matches_selected_tags(note_tags: Array) -> bool:
	if selected_filter_tag_ids.is_empty():
		return true
	
	for tag in note_tags:
		if tag != null and selected_filter_tag_ids.has(tag.tag_id):
			return true
	
	return false
