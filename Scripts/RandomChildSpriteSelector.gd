extends Node

func _ready():
	var random_index = randi_range(0, get_child_count() - 1)
	for i in get_child_count():
		get_child(i).visible = i == random_index
