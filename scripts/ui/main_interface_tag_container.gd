extends HBoxContainer

# TODO: Edge case: UI tags won't update back if all tags bar overflow tag are hidden
#		so when a tag is modified or removed, emit a signal that this script will pick up
#		and call queue_layout()

@export var max_width: int = 600
@onready var overflow_tag: PanelContainer = $OverflowTag

var tags: Array[PanelContainer] = []
var _layout_dirty:= false

func _ready() -> void:
	for child in get_children():
		if child != overflow_tag:
			tags.append(child)
	
	queue_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_layout()

func queue_layout() -> void:
	if _layout_dirty:
		return
	
	_layout_dirty = true
	call_deferred("_recompute_layout")

func _rebuild_tags() -> void:
	tags.clear()
	for child in get_children():
		if child == overflow_tag:
			continue
		if not is_instance_valid(child):
			continue
		if child.is_queued_for_deletion():
			continue
		if child is PanelContainer:
			tags.append(child)

func _recompute_layout() -> void:
	_layout_dirty = false
	_rebuild_tags()
	
	if not is_instance_valid(overflow_tag):
		return
	
	var available := max_width # Remaining horizontal space available
	var hidden_count:= 0
	
	# First pass: assume no overflow tag
	for tag in tags:
		if not is_instance_valid(tag):
			continue
		if tag.is_queued_for_deletion():
			continue
		tag.visible = true
	
	overflow_tag.visible = false
	
	# Second pass: measure and fit
	for tag in tags:
		if not is_instance_valid(tag):
			continue
		if tag.is_queued_for_deletion():
			continue
		var w := tag.get_combined_minimum_size().x
		
		if w <= available:
			available -= w
		else:
			tag.visible = false
			hidden_count += 1
			
	# If tags hidden, resesrve space for overflow
	if hidden_count > 0:
		overflow_tag.visible = true
		
		var overflow_w := overflow_tag.get_combined_minimum_size().x
		
		# Make room for overflow tag by hiding more tags if needed
		for i in range(tags.size() -1, -1, -1):
			if available >= overflow_w:
				break
			var tag := tags[i]
			if not is_instance_valid(tag):
				continue
			if tag.is_queued_for_deletion():
				continue
			if tag.visible:
				tag.visible = false
				available += tag.get_combined_minimum_size().x
				hidden_count += 1
				
		overflow_tag.set_hidden_count(hidden_count)
