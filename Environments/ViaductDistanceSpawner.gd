@icon("res://Sprites/Icons/Quests/questicon_029.png")

extends Node2D

@export var SpawnedScene : PackedScene
@export var ViaductDirectionVector : Vector2 = Vector2(84, -64)
@export var SpawnAtDistance : float

@export_group("Quest and Tag Requirement Settings")
@export var LockedByQuestID : String = ""
@export var UnlockedByQuestID : String = ""
@export var UnlockedByTag : String = ""

func _ready():
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

	var spawnedObject = SpawnedScene.instantiate()
	var pos = global_position + ViaductDirectionVector.normalized() * SpawnAtDistance
	pos.x = round(pos.x)
	pos.y = round(pos.y)
	Global.attach_toWorld(spawnedObject)
	if spawnedObject is Node2D:
		spawnedObject.global_position = pos
	if spawnedObject is GameObject:
		var positionSetter = spawnedObject.getChildNodeWithMethod("set_worldPosition")
		if positionSetter != null:
			positionSetter.set_worldPosition(pos)
	queue_free()
