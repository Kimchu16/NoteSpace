extends HBoxContainer

# TODO: If tag is removed or shorted, listen if the size is < than max, if so add back cleared tag

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

func _recompute_layout() -> void:
	_layout_dirty = false
	
	var available := max_width
	var hidden_count:= 0
	
	# First pass: assume no overflow tag
	for tag in tags:
		tag.visible = true
	
	overflow_tag.visible = false
	
	# Second pass: measure and fit
	for tag in tags:
		var w := tag.get_combined_minimum_size().x
		
		if w <= available:
			available -= w
		else:
			tag.visible = false
			hidden_count += 1
			
	# If tags hidden, resesrve space for overflow
	if hidden_count > 0:
		overflow_tag.visible = true
		overflow_tag.set_hidden_count(hidden_count)
		
		var overflow_w := overflow_tag.get_combined_minimum_size().x
		
		# Make room for overflow tag by hiding more tags if needed
		for i in range(tags.size() -1, -1, -1):
			if available >= overflow_w:
				break
			
			if tags[i].visible:
				tags[i].visible = false
				available += tags[i].get_combined_minimum_size().x
