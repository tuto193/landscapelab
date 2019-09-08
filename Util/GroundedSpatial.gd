extends Spatial
class_name GroundedSpatial

#
# Standard Spatial node which can stay on the LODTerrain ground.
#


var tile_underneath: WorldTile

var _just_placed_on_ground = false


func _ready():
	# Required to make the _notification with NOTIFICATION_TRANSFORM_CHANGED work
	set_notify_transform(true)
	
	_update_tile_underneath()
	_place_on_ground()


func _notification(what):
	# If the global position of this node has changed, get the tile this node is now on and
	#  place the node on the ground
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		# Without this flag, we would loop infinitely since we cause a NOTIFICATION_TRANSFORM_CHANGED
		#  inside _place_on_ground()!
		if _just_placed_on_ground:
			_just_placed_on_ground = false
		else:
			_update_tile_underneath()
			_place_on_ground()


# Gets the WorldTile which is at the position of this node and sets it to the tile_underneath variable.
func _update_tile_underneath():
	# Disconnect from the previous tile
	if tile_underneath:
		tile_underneath.disconnect("split", self, "_place_on_ground")
	
	# Get the new tile
	tile_underneath = WorldPosition.get_tile_at_position(global_transform.origin)
	
	# Connect to the new tile
	if tile_underneath:  # We may not have a tile, e.g. if it's not loaded (due to small view distance)
		tile_underneath.connect("split", self, "_place_on_ground")


# Puts the origin of the node on the ground.
func _place_on_ground():
	global_transform.origin = WorldPosition.get_position_on_ground(global_transform.origin)
	
	_just_placed_on_ground = true
