extends Node2D

@export var spawnObject : PackedScene


func _on_timer_timeout():
	var dir = get_viewport().get_mouse_position() - global_position
	dir = dir.normalized()
	var spawnedObject = spawnObject.instantiate()
	get_parent().add_child(spawnedObject)
	
	var mover = spawnedObject.getChildNodeWithMethod("set_targetDirection")
	mover.set_targetDirection(dir)
	spawnedObject.global_position = global_position
