extends ConfirmationDialog

var layer_composition
var specific_layer_composition_ui

@onready var layer_composition_name = $VBoxContainer/GridContainer/Name
@onready var layer_composition_color_tag = $VBoxContainer/GridContainer/ColorTagMenu
@onready var type_chooser = $VBoxContainer/GridContainer/TypeChooser


func _ready():
	connect("confirmed",Callable(self,"_on_confirm"))
	type_chooser.connect("item_selected",Callable(self,"_on_type_select"))
	
	_add_types()


# Use this function instead of popup to also fill the according layer properties.
# If the layer is not set, the popup will handle the configuration as a new layer.
func layer_popup(min_size: Vector2, existing_layer_composition: LayerComposition = null):
	layer_composition = existing_layer_composition
	
	if layer_composition != null:
		layer_composition_name.text = layer_composition.name
		
		# Find the type string corresponding to this layer's render info
		var type_string: String
		var type_id := 0
		
		for render_info_name in LayerComposition.RENDER_INFOS.keys():
			if layer_composition.render_info is LayerComposition.RENDER_INFOS[render_info_name]:
				type_string = render_info_name
			
			type_id += 1
		
		# Note that this requires the type_chooser to be filled in the same
		# order as LayerComposition.RENDER_INFOS
		type_chooser.selected = type_id
		
		_add_specific_layer_conf(type_string)
		
		# Fill attributes
		for property in layer_composition.render_info.get_property_list():
			if specific_layer_composition_ui.has_node(property["name"]):
				var node = specific_layer_composition_ui.get_node(property["name"])
				
				# FIXME: Doesn't work for some non-stringable types (especially Layers)
				# We'll need to handle this more intelligently based on property["class_name"]
				node.get_node("Data").text = var_to_str(
					layer_composition.render_info.get(property["name"]))
	
	popup_centered(min_size)


func _on_confirm():
	var is_new: bool = false
	var current_type = type_chooser.get_item_metadata(type_chooser.get_selected_id())
	
	if layer_composition == null:
		layer_composition = LayerComposition.new()
		is_new = true
	
	layer_composition.name = layer_composition_name.text
	layer_composition.render_info = LayerComposition.RENDER_INFOS[current_type].new()
	layer_composition.color_tag = layer_composition_color_tag.current_color
	
	for child in specific_layer_composition_ui.get_children():
		var property_name = child.name
		var property_value = child.get_node("Data").text
		
		# FIXME: Somewhat hacky, perhaps there's a better way to differentiate between what we can
		# enter 1:1 and what we need to load (in this rather specific way)
		if property_name.ends_with("_layer"):
			# FIXME: Code duplication with LayerConfigurator
			var full_path = property_value.split(":")
			var db_name = full_path[0]
			var layer_name = full_path[1]
			
			var db = Geodot.get_dataset(db_name)
			var layer = db.get_raster_layer(layer_name)
			
			property_value = layer
		
		layer_composition.render_info.set(property_name, property_value)
	
	if not layer_composition.is_valid():
		logger.error("Confirmation would've created invalid layer with name: %s and type: %s. Aborting"
				% [layer_composition.name, current_type], "LAYERCONFIG")
		# TODO: Should we give an error in the UI here too, or did this definitely already happen
		#  in assign_specific_layer_info?
		return
	
	if is_new:
		Layers.add_layer_composition(layer_composition)
	else:
		layer_composition.emit_signal("layer_changed")
		layer_composition.emit_signal("refresh_view")
	
	# FIXME: Make the LayerComposition renderer do a full load
	
	hide()


func _add_types():
	var idx = 0
	for type in LayerComposition.RENDER_INFOS.keys():
		type_chooser.add_item(type)
		type_chooser.set_item_metadata(idx, type)
		idx += 1


# TODO: This shouldnt be all upercase anyways, maybe move this functionality
func _on_type_select(idx: int):
	var type: String = type_chooser.get_item_text(idx)
	
	if specific_layer_composition_ui != null:
		$VBoxContainer.remove_child(specific_layer_composition_ui)
	
	_add_specific_layer_conf(type)


func _add_specific_layer_conf(type_string: String):
	var render_info = LayerComposition.RENDER_INFOS[type_string].new()
	
	specific_layer_composition_ui = VBoxContainer.new()
	
	# Create list of basic Object properties so we can ignore those later
	var base_property_names = []
	var base_render_info = LayerComposition.RenderInfo.new()
	for property in base_render_info.get_property_list():
		base_property_names.append(property["name"])
	
	for property in render_info.get_property_list():
		# Ignore basic Object properties
		if property["name"] in base_property_names: continue
		
		var container = HBoxContainer.new()
		container.name = property["name"]
		
		var label = Label.new()
		label.text = property["name"]
		
		var line_edit = LineEdit.new()
		line_edit.name = "Data"
		line_edit.placeholder_text = property["class_name"]
		
		container.add_child(label)
		container.add_child(line_edit)
		
		specific_layer_composition_ui.add_child(container)
	
	$VBoxContainer.add_child(specific_layer_composition_ui)
	$VBoxContainer.move_child(specific_layer_composition_ui, 1)
