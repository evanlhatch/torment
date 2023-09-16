extends GameObjectComponent

@export var EnabledTag : String

func _enter_tree():
	initGameObjectComponent()
	if Global.is_world_ready():
		if is_instance_valid(_gameObject):
			Global.World.Tags.setTagActive(EnabledTag)

func _exit_tree():
	if Global.is_world_ready():
		Global.World.Tags.deactivateTags([EnabledTag])
