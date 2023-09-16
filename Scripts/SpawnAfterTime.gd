extends GameObjectComponent

@export var initialWaitTime : float = 1.5
@export var timePerSpawn : float = 5
@export var maxSpawns : int = 5
@export var SpawnObjects : Array[PackedScene]
@export var SpawnProbabilities : Array[float]
@export var InheritIsDisposable : bool

var _reimainingTime : float
var _remainingSpawns : int
signal OnEndOfLife

func _ready():
	initGameObjectComponent()
	if _gameObject == null:
		return
	_reimainingTime = initialWaitTime
	_remainingSpawns = maxSpawns

func _process(delta):
	if _remainingSpawns == 0: return
	if _reimainingTime > 0:
		_reimainingTime -= delta
		if _reimainingTime <= 0:
			_reimainingTime += timePerSpawn
			spawn_object()

func spawn_object():
	var spawnedObject = null
	for i in len(SpawnObjects):
		if randf() <= SpawnProbabilities[i]:
			spawnedObject = SpawnObjects[i]
			break

	if spawnedObject == null:
		return

	var obj = spawnedObject.instantiate()
	obj.global_position = get_gameobjectWorldPosition()
	Global.attach_toWorld(obj)

	if InheritIsDisposable && obj.is_in_group("Disposable"):
		obj.add_to_group("Disposable")
				
	if obj.has_method("getChildNodesWithMethod"):
		var nodes_with_difficulty : Array
		obj.getChildNodesWithMethod("set_difficulty", nodes_with_difficulty)
		var difficulty : float = Global.World.TormentRank.get_torment_difficulty()
		var xpmod : float = Global.World.TormentRank.get_rank_xp_modifier()
		for nodeWithDifficulty in nodes_with_difficulty:
			nodeWithDifficulty.set_difficulty(difficulty, xpmod)