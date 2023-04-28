extends LayerCompositionRenderer
class_name FeatureLayerCompositionRenderer


# Define variables for loading features
var mutex = Mutex.new()
var features := []
var instances := {}
var radius = 6000.0
var max_features = 2000


func _ready():
	super._ready()
	layer_composition.render_info.geo_feature_layer.feature_added.connect(_on_feature_added)
	layer_composition.render_info.geo_feature_layer.feature_removed.connect(_on_feature_removed)


func full_load():
	features = layer_composition.render_info.geo_feature_layer.get_features_near_position(
		float(center[0]), float(center[1]), radius, max_features)
	
	for feature in features:
		mutex.lock()
		instances[feature.get_id()] = load_feature_instance(feature)
		mutex.unlock()


func adapt_load(_diff: Vector3):
	features = layer_composition.render_info.geo_feature_layer.get_features_near_position(
		float(center[0]) + position_manager.center_node.position.x,
		float(center[1]) - position_manager.center_node.position.z,
		radius, max_features
	)
	
	for feature in features:
		if not instances.has(feature.get_id()): 
			mutex.lock()
			instances[feature.get_id()] = load_feature_instance(feature)
			mutex.unlock()
	
	call_deferred("apply_new_data")


func apply_new_data():
	var valid_feature_ids = features.map(func(f): return f.get_id())
	
	for feature in features:
		var node_name = str(feature.get_id())
		
		if not has_node(node_name):
			apply_feature_instance(feature)
	
	for id in instances.keys():
		if not id in valid_feature_ids:
			remove_feature(id)
	
	super.apply_new_data()
	
	logger.info("Applied new feature data for %s" % [name])


func _on_feature_added(feature: GeoFeature):
	if loading_thread.is_started() and not loading_thread.is_alive():
		loading_thread.wait_to_finish()
	
	# Load the feature instance in a thread
	loading_thread.start(load_feature_instance.bind(feature))
	instances[feature.get_id()] = loading_thread.wait_to_finish()
	
	apply_feature_instance(feature)


func _on_feature_removed(feature: GeoFeature):
	if loading_thread.is_started() and not loading_thread.is_alive():
		loading_thread.wait_to_finish()
	
	remove_feature(feature.get_id())


# Might be necessary to be overwritten by inherited class
# Cannot be run in a thread
func remove_feature(feature_id: int):
	if has_node(str(feature_id)):
		get_node(str(feature_id)).queue_free()
		mutex.lock()
		instances.erase(feature_id)
		mutex.unlock()


# To be implemented by inherited class
# Instantiate and initially configure (e.g. set position) of  the instance - run in a thread
# Append instances to dictionary
func load_feature_instance(feature: GeoFeature) -> Node3D:
	return Node3D.new()


# Might be necessary to be overwritten by inherited class
# Apply feature to the main scene - not run in a thread
func apply_feature_instance(feature: GeoFeature):
	if not feature.feature_changed.is_connected(_on_feature_changed):
		feature.feature_changed.connect(_on_feature_changed.bind(feature))
	if not instances.has(feature.get_id()):
		logger.error("No feature instance was created for ID: {}".format([feature.get_id()], "{}"))
		return
	
	add_child(instances[feature.get_id()])


func _on_feature_changed(feature: GeoFeature):
	_on_feature_removed(feature)
	_on_feature_added(feature)


func is_new_loading_required(position_diff: Vector3) -> bool:
	if Vector2(position_diff.x, position_diff.z).length_squared() >= pow(radius / 4.0, 2):
		return true
	
	return false
