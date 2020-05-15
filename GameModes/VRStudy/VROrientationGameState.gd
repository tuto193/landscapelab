extends "res://addons/gameflow/GameState.gd"


onready var timer = get_node("Timer")


func _ready() -> void:
	
	# If the timer times out, this phase ends, even if no selection was made
	timer.connect("timeout", self, "done")
	
	var parent = get_parent()
	var minimap = get_parent().get_node("PlayerVR/Right/Tip/MinimapVR")
	assert(minimap != null)
	if minimap:
		minimap.map_ui.done_button.connect("pressed", self, "done", [], CONNECT_DEFERRED)
	
	# Start tracking
	Session.start_session(Session.scenario_id)
	GlobalSignal.emit_signal("tracking_start", "orientation")


func done():
	GlobalSignal.emit_signal("tracking_stop")
	emit_completed()
