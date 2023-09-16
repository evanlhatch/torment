extends SpawnAgent

@export var Repeats : int = -1
@export var TimeMin : float = 0.0
@export var TimeMax : float = 1.0
@export var Frequence : float = 180.0
@export var Variance : float = 30.0
@export var AgonyInfluence : float = 1.0

var remainingRepeats : int = 0
var remainingTime : float = 0.0

func _ready():
	remainingRepeats = Repeats
	remainingTime = Frequence + randf_range(-Variance, Variance)

func _process(delta):
	if remainingRepeats == 0: return
	if not base_check(): return
	if Global.World.TormentRank.TimeProgress < TimeMin or Global.World.TormentRank.TimeProgress > TimeMax: return
	remainingTime -= delta * get_agony_multiplier()
	if remainingTime <= 0.0:
		remainingTime = Frequence + randf_range(-Variance, Variance)
		remainingRepeats -= 1
		spawn_scene()

func get_agony_multiplier() -> float:
	var currentAgony : float = Global.World.TormentRank.RankMultiplier
	return 1.0 + ((currentAgony - AgonyMin) / (AgonyMax - AgonyMin) * AgonyInfluence)
