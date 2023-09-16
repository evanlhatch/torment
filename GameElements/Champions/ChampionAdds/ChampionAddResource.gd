extends Resource

class_name ChampionAddResource

@export var MonsterScene : PackedScene
@export var BaseSpawnAmount : int = 8
@export var MinDifficulty : float = 1
@export var SpawnProbability : float = 0.2
@export var RequiredTag : String = ""

var CircleRadii : Array[float] = [
	25, 50, 75, 100, 125
]

var MaxMonstersOnCircle : Array[int] = [
	8, 16, 32, 64, 128
]

func SpawnAdds(center:Vector2, difficulty:float):
	var amount : int = min(64, floori(BaseSpawnAmount * (1 + MinDifficulty - difficulty)))
	var circleIndex : int = 0
	var distributedAmount : int = 0
	while distributedAmount < amount and circleIndex < MaxMonstersOnCircle.size():
		var currentCircleAmount : int = min(amount - distributedAmount, MaxMonstersOnCircle[circleIndex])
		var rotationPerInstance : float = TAU / currentCircleAmount
		var currentRadius : float = CircleRadii[circleIndex]
		for i in currentCircleAmount:
			var spawned : Node2D = MonsterScene.instantiate()
			spawned.global_position = center + (Vector2.RIGHT * currentRadius).rotated(rotationPerInstance * i)
			Global.attach_toWorld(spawned)
			var nodes_with_difficulty : Array
			spawned.getChildNodesWithMethod("set_difficulty", nodes_with_difficulty)
			for nodeWithDifficulty in nodes_with_difficulty:
				nodeWithDifficulty.set_difficulty(difficulty, 1)
		distributedAmount += currentCircleAmount
		circleIndex += 1
	if distributedAmount < amount:
		printerr("Could not spawn all Champion adds. There were too many!")



func choose_this_monster(difficulty: float) -> bool:
	if RequiredTag != "" and not Global.World.Tags.isTagActive(RequiredTag):
		return false
	if difficulty < MinDifficulty:
		return false
	return randf() < SpawnProbability
