extends TextureButton


# change the toggle based on the UI signals
func _ready():

	# initialize the input scene invisible
	for child in get_children():
		child.visible = false	
	
	GlobalSignal.connect("input_lego", self, "_setpressedfalse")
	GlobalSignal.connect("input_disabled", self, "_setpressedfalse")


# if the status is changed to pressed emit the controller signal
func _toggled(button_pressed) -> void:
	if self.is_pressed():
		GlobalSignal.emit_signal("input_controller")
		for child in get_children():
			child.visible = true		
	else:
		GlobalSignal.emit_signal("input_disabled")


# if we set the pressed status to false also hide the editing menu
func _setpressedfalse():

	self.set_pressed(false)
	
	for child in get_children():
		child.visible = false
