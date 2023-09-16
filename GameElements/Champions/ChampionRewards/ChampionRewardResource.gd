extends Resource

class_name ChampionRewardResource

var SpawnOnDeathScript : GDScript = load("res://Scripts/SpawnOnDeath.gd")
var MultiSpawnRadiusPerDrop : float = 4

@export var SpawnSceneOnDeath : PackedScene
@export var SpawnAmount : int = 1
@export var SpawnProbabilityMin : float = 0
@export var SpawnProbabilityMax : float = 1
@export var RequiredTag : String = ""
@export var MaxDrops : int = 0
@export var PositionOffset : Vector2

var dropCount : int = 0

func AddSpawnOnDeathToGameObject(gameobject:GameObject):
	dropCount += 1
	# one in the center
	var spawnOnDeath : Node = SpawnOnDeathScript.new()
	spawnOnDeath.SpawnedObjects.append(SpawnSceneOnDeath)
	spawnOnDeath.SpawnProbabilities.append(1)
	spawnOnDeath.SpawnPosOffset = PositionOffset
	gameobject.add_child(spawnOnDeath)
	if SpawnAmount <= 1:
		return
	# the others in a circle around it
	var rotationPerInstance : float = TAU / (SpawnAmount - 1)
	for i in (SpawnAmount - 1):
		spawnOnDeath = SpawnOnDeathScript.new()
		spawnOnDeath.SpawnedObjects.append(SpawnSceneOnDeath)
		spawnOnDeath.SpawnProbabilities.append(1)
		spawnOnDeath.SpawnPosOffset = PositionOffset + (Vector2.RIGHT * MultiSpawnRadiusPerDrop * SpawnAmount).rotated(rotationPerInstance * i)
		gameobject.add_child(spawnOnDeath)

func choose_this_reward(agony: float) -> bool:
	if RequiredTag != "" and not Global.World.Tags.isTagActive(RequiredTag):
		return false
	if MaxDrops > 0 && dropCount >= MaxDrops:
		return false
	return randf() < lerp(SpawnProbabilityMin, SpawnProbabilityMax, agony)