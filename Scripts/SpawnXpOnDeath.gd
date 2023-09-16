extends GameObjectComponent

const XP_FACTOR = 0.012
const XP_EXPONENT = 1.000

@export_enum("OnKilled", "OnEndOfLife") var OnEvent : int = 0
@export var UseTormentScore : bool = true
@export var UseXpModifier : bool = true
@export var XPMultiplier : float = 1.0
@export var XPAmount : float = 1.0
@export var MinGems : int = 1
@export var MaxGems : int = 1
@export var MinDistance : float = 0.0
@export var MaxDistance : float = 0.0
@export var UseOffscreenPositioner : bool = false
@export var GemPool : XPGemPool

var finalXPAmount : float

func _ready():
	initGameObjectComponent()
	if _gameObject == null:
		return
	finalXPAmount = XPAmount * XPMultiplier
	if OnEvent == 0:
		_gameObject.connectToSignal("Killed", _on_killed)
	elif OnEvent == 1:
		_gameObject.connectToSignal("OnEndOfLife", _on_killed.bind(null))


func _on_killed(killedBy : Node):
	var gemCount : int = get_gem_count()
	var xpPerGem : float = finalXPAmount / float(gemCount)
	for i in range(gemCount):
		var xpToSpawn : float = xpPerGem + Global.World.ExperienceOverflow
		var gem : XPGemPoolItem = GemPool.get_biggest_smaller_than_target(xpToSpawn)
		if gem != null:
			var gemObject = gem.GemScene.instantiate()
			if UseOffscreenPositioner:
				gemObject.global_position = Global.World.OffscreenPositioner.get_nearest_valid_position(
					get_spawn_position())
			else: gemObject.global_position = get_spawn_position()
			Global.attach_toWorld(gemObject)
			Global.World.ExperienceOverflow = xpToSpawn - gem.GemValue
		else:
			Global.World.ExperienceOverflow = xpToSpawn


func get_gem_count() -> int:
	if MaxGems <= MinGems: return MinGems
	return randi_range(MinGems, MaxGems)


func set_difficulty(difficulty:float, xpmod:float):
	if UseTormentScore:
		var tormentScoreProvider = _gameObject.getChildNodeWithMethod("get_unscaled_torment_score")
		if tormentScoreProvider != null:
			if not tormentScoreProvider.DifficultySet:
				await tormentScoreProvider.DifficultyApplied
			finalXPAmount = (tormentScoreProvider.get_unscaled_torment_score() * XP_FACTOR) ** XP_EXPONENT
	if UseXpModifier:
		finalXPAmount *= xpmod
	finalXPAmount *= XPMultiplier


func get_spawn_position() -> Vector2:
	var position = get_gameobjectWorldPosition()
	if MaxDistance <= 0.0 && MinDistance <= 0.0: return position
	if MinDistance > MaxDistance:
		position += Vector2.UP.rotated(PI * randf()) * MinDistance
	else:
		position += Vector2.UP.rotated(PI * randf()) * randf_range(MinDistance, MaxDistance)
	return position
