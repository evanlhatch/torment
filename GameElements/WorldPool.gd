extends Node

@export var Worlds : Array[Resource]

var SelectedWorldIndex : int

signal HallsEntered

func enterSelectedWorld(use_torment_rank:bool = false):
	enterWorld(SelectedWorldIndex, use_torment_rank)

func enterWorld(worldIndex:int, use_torment_rank:bool = false):
	SelectedWorldIndex = worldIndex
	var worldRes : WorldResource = Worlds[worldIndex] as WorldResource
	worldRes.queue_resource_load()

	# this is copied over from GameState.gd. we have to
	# unload the current scene here, because the InGameState
	# can't have a scene (there are different world scenes now!)
	GlobalMenus.transition.fade_out()
	await GlobalMenus.transition.TransitionFinished
	if get_tree().current_scene != null:
		get_tree().current_scene.queue_free()
		# need to wait at least one frame, so that the
		# queue_free really freed the scene!
		await get_tree().process_frame

	# wait for the scene resources in the worldRes
	await ResourceLoaderQueue.waitForLoadingFinished()

	var itemPoolSceneRes = ResourceLoaderQueue.getCachedResource(worldRes.ItemPoolScene)
	var itemPoolScene = itemPoolSceneRes.instantiate()
	itemPoolScene.queue_resource_load()

	var traitPoolSceneRes = ResourceLoaderQueue.getCachedResource(worldRes.TraitPoolScene)
	var traitPoolScene = traitPoolSceneRes.instantiate()
	traitPoolScene.queue_resource_load()

	var abilityPoolSceneRes = ResourceLoaderQueue.getCachedResource(worldRes.AbilityPoolScene)
	var abilityPoolScene = abilityPoolSceneRes.instantiate()
	abilityPoolScene.queue_resource_load()

	await ResourceLoaderQueue.waitForLoadingFinished()

	itemPoolScene.instantiate_items_children()
	traitPoolScene.instantiate_traits_children()
	abilityPoolScene.instantiate_abilities_children()

	var worldSceneRes = ResourceLoaderQueue.getCachedResource(worldRes.WorldScene)
	var worldScene : World = worldSceneRes.instantiate()

	# again: copied from GameState.gd ...
	get_tree().root.add_child(worldScene)
	# setting the current_scene means that we are still compatible with change_scene
	get_tree().current_scene = worldScene

	worldScene.WorldName = worldRes.WorldName
	worldScene.initialize(traitPoolScene, abilityPoolScene, itemPoolScene, use_torment_rank)

	GameState.SetState(GameState.States.InGame)
	GlobalMenus.transition.fade_in()

	HallsEntered.emit()

func get_unlockedWorldsCount() -> int:
	var count : int = 0
	for w in Worlds:
		if (w.LockedByQuestID.is_empty() or
			Global.QuestPool.is_quest_complete(w.LockedByQuestID)):
			count += 1
	return count
