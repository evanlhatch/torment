extends GameObjectComponent

const RANK_INCREASE_FACTOR = 0.001

@export var DefaultScoreOnDeath : int = 1000
@export var DefaultRankOnDeath : float = 1.0
@export var UseHealthForScore : bool = true
@export var UseHealthForRank : bool = true
@export var MonsterDifficulty : float = 1.0
@export var RankDecreasePeriod : float = 25.0

var TormentScoreOnDeath : int = 0
var UnscaledTormentScoreOnDeath : int = 0
var TormentRankOnDeath : float = 0.0
var RankChangePerSecond : float = -0.0

signal DifficultyApplied()
var DifficultySet : bool = false

func _ready():
	initGameObjectComponent()
	if _gameObject == null:
		return

	TormentScoreOnDeath = DefaultScoreOnDeath
	TormentRankOnDeath = DefaultRankOnDeath
	RankChangePerSecond = -(TormentRankOnDeath / RankDecreasePeriod)

	if RankChangePerSecond != 0:
		Global.World.SecondPassed.connect(_on_second_passed)
	_gameObject.connectToSignal("Killed", _on_killed_received)


func set_difficulty(difficulty:float, xpmod:float):
	var healthProvider = _gameObject.getChildNodeWithMethod("get_maxHealth")
	if healthProvider != null:
		if UseHealthForScore:
			TormentScoreOnDeath = healthProvider.get_maxHealthBase() * MonsterDifficulty * difficulty
			UnscaledTormentScoreOnDeath = healthProvider.get_maxHealthBase() * MonsterDifficulty
		if UseHealthForRank:
			TormentRankOnDeath = healthProvider.get_maxHealthBase() * RANK_INCREASE_FACTOR
	RankChangePerSecond = -(TormentRankOnDeath / RankDecreasePeriod)
	if RankChangePerSecond != 0 and not Global.World.SecondPassed.is_connected(_on_second_passed):
		Global.World.SecondPassed.connect(_on_second_passed)
	DifficultySet = true
	DifficultyApplied.emit()

func _on_killed_received(_byNode:Node):
	Global.World.TormentRank.increase_target_value(TormentRankOnDeath)
	Global.World.TormentRank.increase_score(TormentScoreOnDeath)

func _on_second_passed(_currentTime):
	Global.World.TormentRank.increase_target_value(RankChangePerSecond)

func get_torment_score():
	return TormentScoreOnDeath

func get_unscaled_torment_score():
	return UnscaledTormentScoreOnDeath
