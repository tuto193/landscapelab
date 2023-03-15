extends Configurator

@onready var list: ItemList = get_parent().get_node("ItemList")


func _ready():
	# if the UI was instanced later than the world, we need to check for already instanced layers
	for layer in Layers.geo_layers["rasters"]:
		add_geo_layer(Layers.geo_layers["rasters"][layer])
	
	for layer in Layers.geo_layers["features"]:
		add_geo_layer(Layers.geo_layers["features"][layer])
	
	Layers.new_geo_layer.connect(add_geo_layer)
	list.z_index_changed.emit(list.get_items())


func add_geo_layer(geo_layer: Resource):
	var new_layer_idx = list.add_item(geo_layer.resource_name)
	list.set_item_metadata(new_layer_idx, geo_layer)


func remove_geo_layer(geo_layer_name: String):
	for i in range(list.item_count):
		if list.get_item_text(i) == geo_layer_name:
			list.remove_item(i)
