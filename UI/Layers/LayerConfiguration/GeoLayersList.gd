extends ItemList

#
# Display of all geolayers and handling for z-index of geo-layers in the 2D space.
#


signal z_index_changed(item_array)
signal geolayer_visibility_changed(layer_name, is_visible)


func get_items():
	var items = []
	for idx in range(item_count):
		items.append({ "name": get_item_text(idx), "z_idx": item_count - idx })
	return items


func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		select(get_item_at_position(event.global_position))
		$GeoLayerOptions.menu_popup(
			Rect2(global_position + event.position + Vector2(25, 0), Vector2(4, 4)),
			get_item_metadata(get_selected_items()[0]) if not get_selected_items().is_empty() else null
		)


func _can_drop_data(at_position, data):
	if not "geolayer" in data: return
	return data.geolayer is GeoFeatureLayer or data.geolayer is GeoRasterLayer


func _drop_data(at_position, data):
	var item_idx = get_item_at_position(at_position)
	move_item(data.idx, item_idx)
	z_index_changed.emit(get_items())


func _get_drag_data(at_position):
	var item_idx = get_item_at_position(at_position)
	var item_metadata = get_item_metadata(item_idx)
	var item_name = get_item_text(item_idx)
	
	var data = {"idx": item_idx, "geolayer": item_metadata}
	var preview = Label.new()
	preview.text = item_name
	set_drag_preview(preview)
	
	return data
