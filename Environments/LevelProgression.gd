@tool
extends Resource
class_name LevelProgression

@export var Entries : Array[Resource] = []

func _init():
	Entries = []
