extends Node2D
class_name ItemSpawner

@export var LockedByQuestID : String = ""
@export var UnlockedByQuestID : String = ""
@export var UnlockedByTag : String = ""
@export var SpawnedObjectScene : PackedScene
@export var MinCoordinates : Vector2 = Vector2(0, 0)
@export var MaxCoordinates : Vector2 = Vector2(0, 0)
@export var FreeParentGameObjectAfterSpawn : bool = false


func _ready():
	if process_mode == PROCESS_MODE_DISABLED:
		return

	if not Global.is_world_ready():
		await Global.WorldReady
	
	if (not LockedByQuestID.is_empty() and
		Global.QuestPool.is_quest_complete(LockedByQuestID)):
		return
		
	if (not UnlockedByQuestID.is_empty() and
		not Global.QuestPool.is_quest_complete(UnlockedByQuestID)):
		return

	if not UnlockedByTag.is_empty():
		while not Global.World.Tags.isTagActive(UnlockedByTag):
			await Global.World.Tags.TagsUpdated

	if SpawnedObjectScene != null:
		var position_reference : Node2D = self
		
		var spawnedObjectInstance = SpawnedObjectScene.instantiate()
		var rect : Rect2
		rect.position = MinCoordinates
		rect.end = MaxCoordinates
		rect = rect.abs()
		spawnedObjectInstance.global_position = Global.World.OffscreenPositioner.get_random_position_in_area(rect)
		Global.attach_toWorld(spawnedObjectInstance)
		if FreeParentGameObjectAfterSpawn:
			var gameObject = Global.get_gameObject_in_parents(self)
			if gameObject != null:
				gameObject.call_deferred("queue_free")
				return
		call_deferred("queue_free")
