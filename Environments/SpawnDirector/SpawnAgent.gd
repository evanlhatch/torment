extends Node
class_name SpawnAgent

@export var Scenes : WeightedScenePool
@export var ReqDifficulty : float = 0
@export var AgonyMin : float = 0
@export var AgonyMax : float = 5

func base_check() -> bool:
	var currentAgony : float = Global.World.TormentRank.RankMultiplier
	if currentAgony > AgonyMin and currentAgony < AgonyMax:
		if currentAgony * Global.World.TormentRank.get_torment_difficulty() > ReqDifficulty:
			return true
	return false

func spawn_scene() -> void:
	var scene : PackedScene = Scenes.pick_random()
	var inst : Node = scene.instantiate()
	
	# test, spawning the randomly selected scene here
	Global.attach_toWorld(inst)
	var posProvider = Global.World.Player.getChildNodeWithMethod("get_worldPosition")
	if posProvider != null:
		inst.set_worldPosition(posProvider.get_worldPosition() + Vector2(0, -50))
