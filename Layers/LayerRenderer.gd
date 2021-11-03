extends Spatial
class_name LayerRenderer


# Dependency comes from the LayerRenderers-Node which should always be above in the tree
var layer: Layer

# Offset to use as the center position
var center := [0, 0]

# Time management
var time_manager setget set_time_manager
var is_daytime = true


func _ready():
	layer.connect("visibility_changed", self, "set_visible")


# Overload with the functionality to load new data, but not use (visualize) it yet. Run in a thread,
#  so watch out for thread safety!
func load_new_data():
	pass


# Overload with applying and visualizing the data. Not run in a thread.
func apply_new_data():
	pass


func set_time_manager(manager: TimeManager):
	time_manager = manager
	time_manager.connect("daytime_changed", self, "_apply_daytime_change")


# Emitted from the injected time_manager
func _apply_daytime_change(daytime: bool):
	is_daytime = daytime
	
	for child in get_children():
		if child.has_method("apply_daytime_change"):
			child.apply_daytime_change(daytime)
