extends RefCounted
class_name LLFileAccess

var json_object := JSON.new()
var path: String
var file_access: FileAccess


static func open(init_path: String) -> LLFileAccess:
	logger.info("Loading LL project file from " + init_path + "...")
	var file
	if FileAccess.file_exists(init_path):
		file = FileAccess.open(init_path, FileAccess.READ_WRITE)
	else:
		file = FileAccess.open(init_path, FileAccess.WRITE_READ)
	
	var ll_file_access = LLFileAccess.new()
	ll_file_access.path = init_path
	ll_file_access.file_access = file
	
	if file == null:
		logger.error("Error opening LL project file at " + init_path)
		return null
	
	var error = ll_file_access.json_object.parse(file.get_as_text())
	
	if error != OK:
		logger.error("Error parsing LL project at " + init_path + ": "
				+ ll_file_access.json_object.get_error_message() + " at line "
				+ str(ll_file_access.json_object.get_error_line()))
	
	return ll_file_access


func save():
	var ll_config = {
		"LayerCompositions": {},
		"Scenarios":  {},
		"Vegetation": {}
	}
	
	# FIXME: After the first layercomposition has been serialized, 
	# FIXME: the other ones will not have a valid layer.get_dataset().resource_path
	for layer_composition in Layers.layer_compositions.values():
		var serialized: Dictionary = LayerCompositionSerializer.serialize(layer_composition)
		ll_config["LayerCompositions"].merge(serialized)
	
	for scenario in Scenarios.scenarios:
		ll_config.Scenarios.merge({
			scenario.name: {
				"layers": scenario.visible_layer_names
			}
		})
	
	# FIXME: unmake hardcode
	ll_config["Vegetation"] = Vegetation.paths
	
	var json_string = JSON.stringify(ll_config)
	file_access.store_line(json_string)
	var error = json_object.parse(json_string)
	
	if error != OK:
		logger.error("Error parsing LL project at : "
			+ json_object.get_error_message() + " at line "
			+ str(json_object.get_error_line()))


func apply(vegetation: Node, layers: Node, scenarios: Node):
	apply_vegetation(vegetation)
	apply_layers(layers)
	apply_scenarios(scenarios)


static func get_rel_or_abs_path(base_path: String, file_path: String):
	if file_path.begins_with("./"):
		return base_path.get_base_dir().path_join(file_path)
	else:
		return file_path


func apply_vegetation(vegetation: Node):
	var ll_project = json_object.data
	
	# Load vegetation if in config
	if ll_project.has("Vegetation"):
		logger.info("Loading vegetation...")
		vegetation.load_data_from_csv(
			get_rel_or_abs_path(path, ll_project["Vegetation"]["Plants"]),
			get_rel_or_abs_path(path, ll_project["Vegetation"]["Groups"]),
			get_rel_or_abs_path(path, ll_project["Vegetation"]["Densities"]),
			get_rel_or_abs_path(path, ll_project["Vegetation"]["Textures"])
		)
		logger.info("Done loading vegetation!")


func apply_layers(layers: Node):
	var ll_project = json_object.data
	
	for composition_name in ll_project["LayerCompositions"].keys():
		logger.info("Loading layer composition " + composition_name + "...")
		
		var composition_data = ll_project["LayerCompositions"][composition_name]
		var type = composition_data["type"]
		
		var layer_composition = LayerCompositionSerializer.deserialize(
			path, 
			composition_name, 
			type, 
			composition_data["attributes"])
		
		layers.add_layer_composition(layer_composition)
		layers.recalculate_center()


func apply_scenarios(scenarios: Node):
	var ll_project = json_object.data
	
	# Load scenarios if in config
	if ll_project.has("Scenarios"):
		logger.info("Loading scenarios...")
		for scenario_name in ll_project["Scenarios"].keys():
			var scenario = Scenario.new()
			scenario.name = scenario_name
			
			for layer_name in ll_project["Scenarios"][scenario_name]["layers"]:
				scenario.add_visible_layer_name(layer_name)
			
			scenarios.add_scenario(scenario)
		
		logger.info("Done loading scenarios!")
