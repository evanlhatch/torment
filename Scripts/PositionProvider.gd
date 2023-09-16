extends StaticBody2D

var gameObject : GameObject

func _ready():
	gameObject = Global.get_gameObject_in_parents(self)

func get_worldPosition():
	return global_position
