extends VBoxContainer

#
# This script loads asset_types and their according energy into the gui
#

var assets
var assets_list
# The dictionaries hold the the values for a type so they can be changed easily with an update
var type_energy_dict : Dictionary
var type_amount_dict : Dictionary


func _ready():
	GlobalSignal.connect("asset_removed", self, "_update")
	GlobalSignal.connect("asset_spawned", self, "_update")
	
	draw_rect(get_viewport_rect(), Color.aliceblue, true)
	
	_setup()
	_update()


# An update should be called whenever the value changes (new asset spawned, asset removed, etc.)
func _update():
	ThreadPool.enqueue_task(ThreadPool.Task.new(self, "_update_threaded", []), 100.0)


# Thread the server request
func _update_threaded(data):
	for asset_type in assets:
		var asset_type_name = assets[asset_type]["name"]
		var asset_type_details = ServerConnection.get_json("/assetpos/energy_contribution/" + asset_type + ".json")
		
		var asset_type_energy = "Current energy value: " + String(asset_type_details["total_energy_contribution"]) + " MW"
		var asset_type_amount = "Placed amount: " + String(asset_type_details["number_of_assets"])
		
		type_energy_dict[asset_type_name].text = asset_type_energy
		type_amount_dict[asset_type_name].text = asset_type_amount


func _setup():
	# Load all possible assets from the server
	assets = Assets.get_asset_types_with_assets()
	
	for asset_type in assets:
		assets_list = load("res://UI/EnergyUI/AssetsList.tscn").instance()
		
		var asset_type_label = assets_list.get_node("AssetType")
		var asset_type_image = assets_list.get_node("Image")
		var asset_type_details = assets_list.get_node("Details")
		
		var asset_type_name = assets[asset_type]["name"]
		
		#if asset_type_name == "Wind Turbine":
		#	asset_type_image.texture = load("res://Resources/Images/UI/MapIcons/windmill_icon.png")
			
		asset_type_label.text = asset_type_name + "s"
		
		_setup_type_details(asset_type_details, asset_type_name)
		
		add_child(assets_list)


func _setup_type_details(asset_type_details, asset_type_name):
	# Set the values for the details in an own label so they can be manipulated easily later
	var asset_type_amount = Label.new()
	var asset_type_energy = Label.new()
	
	# Set the value into the dictionary so they can easily be accessed later and updated
	type_amount_dict[asset_type_name] = asset_type_amount
	type_energy_dict[asset_type_name] = asset_type_energy
	
	asset_type_details.add_child(asset_type_amount)
	asset_type_details.add_child(asset_type_energy)