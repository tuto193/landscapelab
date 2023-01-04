extends ConfirmationDialog

var layer_composition: LayerComposition
var specific_layer_composition_ui: SpecificLayerCompositionUI

@onready var layer_composition_name = $VBoxContainer/GridContainer/Name
@onready var layer_composition_color_tag = $VBoxContainer/GridContainer/ColorTagMenu
@onready var type_chooser = $VBoxContainer/GridContainer/TypeChooser

var RenderTypeObject = {
	"NONE": LayerComposition,
	"BASIC_TERRAIN": LayerComposition,
	"REALISTIC_TERRAIN": LayerComposition,
	"PARTICLES": LayerComposition,
	"OBJECT": LayerComposition,
	"PATH": LayerComposition,
	"CONNECTED_OBJECT": LayerComposition,
	"POLYGON": LayerComposition,
	"VEGETATION": LayerComposition,
	"TWODIMENSIONAL": LayerComposition
}


func _ready():
	connect("confirmed",Callable(self,"_on_confirm"))
	type_chooser.connect("item_selected",Callable(self,"_on_type_select"))
	
	_add_types()


# Use this function instead of popup to also fill the according layer properties.
# If the layer is not set, the popup will handle the configuration as a new layer.
func layer_popup(min_size: Vector2, existing_layer_composition: LayerComposition = null):
	popup_centered(min_size)
	layer_composition = existing_layer_composition
	
	if layer_composition != null:
		layer_composition_name.text = layer_composition.name
		type_chooser.selected = layer_composition.render_info.get_class()
		
		# FIXME: this probably should not be done like this anyways so we should fix this
		var type_string: String = LayerComposition.RENDER_INFOS.find_key(layer_composition.render_info.get_class())
		_add_specific_layer_conf(type_string)


func _on_confirm():
	var is_new: bool = false
	var current_type = type_chooser.get_item_metadata(type_chooser.get_selected_id())
	
	if layer_composition == null:
		layer_composition = RenderTypeObject[current_type].new()
		is_new = true
	
	layer_composition.name = layer_composition_name.text
	layer_composition.render_info = LayerComposition.RENDER_INFOS[current_type]
	layer_composition.color_tag = layer_composition_color_tag.current_color
	specific_layer_composition_ui.assign_specific_layer_info(layer_composition)
	
	if not layer_composition.is_valid():
		logger.error("Confirmation would've created invalid layer with name: %s and type: %s. Aborting"
				% [layer_composition.name, current_type], "LAYERCONFIG")
		# TODO: Should we give an error in the UI here too, or did this definitely already happen
		#  in assign_specific_layer_info?
		return
	
	if is_new:
		LayerComposition.add_layer(layer_composition)
	else:
		layer_composition.emit_signal("layer_changed")
		layer_composition.emit_signal("refresh_view")
	
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
	type = type.substr(0, 1) + type.substr(1).to_lower()
	
	if specific_layer_composition_ui != null:
		$VBoxContainer.remove_child(specific_layer_composition_ui)
	
	_add_specific_layer_conf(type)


func _add_specific_layer_conf(type_string: String):
	specific_layer_composition_ui = load(
			"res://UI/Layers/LayerConfiguration/SpecificLayerCompositionUI/%sLayer.tscn" 
			% type_string).instantiate()
	
	if layer_composition: specific_layer_composition_ui.init(layer_composition)
	
	$VBoxContainer.add_child(specific_layer_composition_ui)
	$VBoxContainer.move_child(specific_layer_composition_ui, 1)
	
	specific_layer_composition_ui.connect("new_size",Callable(self,"resize"))
