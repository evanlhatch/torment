@icon("res://Sprites/Icons/Quests/questicon_029.png")

extends Node2D
class_name QuestSpawner

@export var LockedByQuestID : String = ""
@export var UnlockedByQuestID : String = ""
@export var UnlockedByTag : String = ""
@export var SpawnedObjectScene : PackedScene
@export var PositionLocatorPoolName : String = ""
@export var OnlySpawnWhenLocatorWasFound : bool = false
@export var FreeParentGameObjectAfterSpawn : bool = false
@export var DelaySpawnByFrames : int = 0


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
		
		for _frame in DelaySpawnByFrames:
			await get_tree().process_frame
		
		var pos : Locator = Global.World.Locators.get_random_locator_in_pool(PositionLocatorPoolName)
		if pos != null: position_reference = pos
		elif OnlySpawnWhenLocatorWasFound: 
			queue_free()
			return
		
		var spawnedObjectInstance = SpawnedObjectScene.instantiate()
		spawnedObjectInstance.global_position = position_reference.global_position
		Global.attach_toWorld(spawnedObjectInstance)
		if FreeParentGameObjectAfterSpawn:
			var gameObject = Global.get_gameObject_in_parents(self)
			if gameObject != null:
				gameObject.call_deferred("queue_free")
				return
		call_deferred("queue_free")
