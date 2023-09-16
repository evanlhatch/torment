extends Node

@export var ActivateTags : Array[String] = []

## Makes sense for modifiers, items and all the things that
## can exist outside of GameObjects and are then duplicated and
## placed on a GameObject (the player)
@export var OnlyOnGameObjects : bool = false

func _ready():
	if not Global.is_world_ready():
		await Global.WorldReady
	
	if OnlyOnGameObjects and Global.get_gameObject_in_parents(self) == null:
		return
	
	if ActivateTags != null && ActivateTags.size() > 0:
		Global.World.Tags.setTagsActive(ActivateTags)
	
	queue_free()

