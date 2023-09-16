extends Node

func _ready():
	var children = get_children()
	var random_child = children.pick_random()
	for c in children:
		if c == random_child: continue
		c.queue_free()
