extends Node


func _ready():
	get_parent().connectToSignal("CollisionStarted", collisionStarted)
	get_parent().connectToSignal("CollisionEnded", collisionEnded)

func collisionStarted(withNode):
	print("collision with %s started" % withNode.name)

func collisionEnded(withNode):
	print("collision with %s ended" % withNode.name)
