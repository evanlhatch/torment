extends Node2D

@export var WaitForFramesBeforeSpawn : int = 1
@export var SpawnedScene : PackedScene
@export var ArraySpawnOffset : Vector2 = Vector2(42, 32)
@export var SpawnCount : int = 1

func _ready():
	for i in WaitForFramesBeforeSpawn:
		await get_tree().process_frame

	var pos = global_position
	for i in SpawnCount:
		var spawnedObject = SpawnedScene.instantiate()
		Global.attach_toWorld(spawnedObject)
		if spawnedObject is Node2D:
			spawnedObject.global_position = pos
		if spawnedObject is GameObject:
			var positionSetter = spawnedObject.getChildNodeWithMethod("set_worldPosition")
			if positionSetter != null:
				positionSetter.set_worldPosition(pos)
		pos += ArraySpawnOffset
		pos.x = round(pos.x)
		pos.y = round(pos.y)
	queue_free()
