extends BoxContainer


func set_score(score: GameScore):
	for contrib in score.contributors:
		var contributor: GameScore.GameScoreContributor = contrib
		if contributor.weight_changable:
			var slider = HSlider.new()
			slider.min_value = contributor.weight_interval_start
			slider.max_value = contributor.weight_interval_end
			slider.value = contributor.weight
			slider.connect("drag_ended", self, "set_contributor_weight", [contributor, slider])
			slider.rect_min_size = Vector2(200, 50)
			var label = Label.new()
			label.text = contributor.get_name()
			get_node("AdditionalInfo/PopupPanel/VBoxContainer").add_child(label)
			get_node("AdditionalInfo/PopupPanel/VBoxContainer").add_child(slider)


func set_contributor_weight(value_changed: bool, contributor, slider):
	contributor.set_weight(slider.value)
