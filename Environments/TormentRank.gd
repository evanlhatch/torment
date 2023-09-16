extends Node

signal TormentLevelChanged(tormentLevel:int)

@export var enable_torment_rank : bool = false
@export var RankMaximum : float = 10000

@export_category("Boss Health")
@export var BossHealthOffset : float = 0.0
@export var BossHealthTimeMod : float = 0.0
@export var BossHealthRankMod : float = 0.0
@export var BossHealthLevelMod : float = 0.0

@export_category("Boss Difficulty")
@export var BossOffset : float = 0.0
@export var BossTimeMod : float = 0.0
@export var BossRankMod : float = 0.0
@export var BossLevelMod : float = 0.0

@export_category("Health")
@export var HealthOffset : float = 0.0
@export var HealthTimeMod : float = 0.0
@export var HealthRankMod : float = 0.0
@export var HealthLevelMod : float = 0.0

@export_category("Movement Speed")
@export var SpeedOffset : float = 0.0
@export var SpeedTimeMod : float = 0.0
@export var SpeedRankMod : float = 0.0
@export var SpeedLevelMod : float = 0.0

@export_category("Enemy Damage")
@export var DamageOffset : float = 0.0
@export var DamageTimeMod : float = 0.0
@export var DamageRankMod : float = 0.0
@export var DamageLevelMod : float = 0.0

@export_category("Defense (Absolute)")
@export var DefenseOffset : float = 0.0
@export var DefenseTimeMod : float = 0.0
@export var DefenseRankMod : float = 0.0
@export var DefenseLevelMod : float = 0.0

@export_category("Spawn Interval")
@export var IntervalOffset : float = 0.0
@export var IntervalTimeMod : float = 0.0
@export var IntervalRankMod : float = 0.0
@export var IntervalLevelMod : float = 0.0

@export_category("Spawn Cap")
@export var CapOffset : float = 0.0
@export var CapTimeMod : float = 0.0
@export var CapRankMod : float = 0.0
@export var CapLevelMod : float = 0.0

@export_category("XP Drops")
@export var XpOffset : float = 0.0
@export var XpTimeMod : float = 0.0
@export var XpRankMod : float = 0.0
@export var XpLevelMod : float = 0.0

@export_category("Gold Rewards")
@export var GoldOffset : float = 0.0
@export var GoldTimeMod : float = 0.0
@export var GoldRankMod : float = 0.2
@export var GoldLevelMod : float = 0.0

@export_category("Difficulty")
@export var DifficultyOffset : float = 0.0
@export var DifficultyTimeMod : float = 0.0
@export var DifficultyRankMod : float = 0.0
@export var DifficultyLevelMod : float = 0.0

const RankLimits = [0, 0.012, 0.035, 0.111, 0.32, 0.96]
const RankNames = ["0", "I", "II", "III", "IV", "V"]

const StartValue : float = 0
const DecayFixed : float = 0
const DecayBase : float = 0.2
const DecayDivisor : float = 100
const DecayPower : float = 1.3
const TargetToRealValueSpeedFactor : float = 0.033

var RankTime : float = 0
var TimeLength : float = 1800
var TimeProgress : float = 0

var RankValue : float
var RankTargetValue : float
var RankProgress : float
var RankIndex : int
var RankName : String
var RankMultiplier : float
var HighestRankMultiplier : float

var TormentLevel : int = 0
var TormentScore : int = 0

var TempScore : int = 0
var ScoreKeys : Array[int] = [1, 2, 3, 5, 7, 11, 13, 17, 19, 23, 29]
var ScoreValues : Array[int] = []

func _ready():
	await Global.WorldReady
	Global.World.Player.connectToSignal("DeathCheated", _on_player_cheated_death)
	RankTargetValue = 0
	RankValue = 0
	RankMultiplier = 0.0
	HighestRankMultiplier = 0.0
	set_target_value(StartValue)
	set_value(StartValue)
	TormentScore = 0
	TormentLevel = 0
	RankName = "0"
	RankTime = 0
	TempScore = 0
	ScoreValues = []
	ScoreValues.resize(ScoreKeys.size())
	print("Torment Rank ready")

func get_torment_value():
	return RankValue

func get_torment_target_value():
	return RankTargetValue

func get_torment_rank():
	return float(RankIndex) + RankProgress


# this gets the harder to cheat torment score
func get_torment_score() -> int:
	var score : int = 1
	for i in range(ScoreKeys.size()):
		if ScoreValues[i] > 0:
			score *= ScoreKeys[i] * ScoreValues[i]
	if score <= 1 or not validate_torment_score(score):
		return 0
	return score

func increase_torment_score():
	var score : int = get_torment_score() + TempScore
	for i in range(1, ScoreKeys.size()):
		if score % ScoreKeys[i] == 0:
			ScoreValues[i] = 1
			score /= ScoreKeys[i]
		else:
			ScoreValues[i] = 0
	ScoreValues[0] = score
	TormentScore += TempScore
	TempScore = 0

func validate_torment_score(score:int) -> bool:
	for i in range(1, ScoreKeys.size()):
		if score % ScoreKeys[i] == 0 && ScoreValues[i] != 1:
			return false
		elif score % ScoreKeys[i] != 0 && ScoreValues[i] == 1:
			return false
		if score % ScoreKeys[i] == 0:
			score /= ScoreKeys[i]
	return true



func setTormentLevel(newTormentLevel:int):
	TormentLevel = newTormentLevel
	emit_signal("TormentLevelChanged", TormentLevel)

#==============================================================================#
#						TORMENT RANK HELPER FUNCTIONS						   #
#==============================================================================#
func set_target_value(new_value):
	if not enable_torment_rank:	return
	RankTargetValue = clamp(new_value, 0.0, RankMaximum)

func increase_target_value(new_value):
	if not enable_torment_rank:	return
	RankTargetValue = clamp(RankTargetValue + new_value, 0.0, RankMaximum)

func increase_score(addition_score):
	if enable_torment_rank:
		TempScore += int(float(addition_score) * (1.0 + RankMultiplier))
	else:
		TempScore += addition_score

func set_value(new_value):
	RankValue = clamp(new_value, 0.0, RankMaximum)
	for index in range(RankLimits.size()-1, -1, -1):
		if RankValue >= RankLimits[index] * RankMaximum:
			RankIndex = index
			RankName = RankNames[index]
			if index < RankLimits.size()-1:
				RankProgress = (RankValue - RankLimits[index] * RankMaximum) / (RankLimits[index+1] * RankMaximum - RankLimits[index] * RankMaximum)
			else:
				RankProgress = (RankValue - RankLimits[index] * RankMaximum) / (RankMaximum - RankLimits[index] * RankMaximum)
			RankMultiplier = min(5.0, float(RankIndex) + RankProgress)
			if roundi(RankMultiplier*100) > roundi(HighestRankMultiplier*100):
				Global.QuestPool.notify_agony_reached(RankMultiplier, TimeProgress)
			HighestRankMultiplier = max(RankMultiplier, HighestRankMultiplier)
			break


#==============================================================================#
#						TORMENT RANK EVENT CALLBACKS						   #
#==============================================================================#

func _process(delta):
	RankTime += delta
	TimeProgress = (RankTime / TimeLength)
	#if enable_torment_rank:
		#var decay = pow((RankTargetValue / DecayDivisor), DecayPower) * DecayBase + DecayFixed
		#increase_target_value(-delta * decay)
	set_value(RankValue + (RankTargetValue-RankValue) * TargetToRealValueSpeedFactor * delta)
	if TempScore > 0:
		increase_torment_score()

func _on_player_cheated_death():
	if not enable_torment_rank:	return
	set_target_value(RankTargetValue*0.666)


#==============================================================================#
#							RANK MODIFIER ACCESSORS							   #
#==============================================================================#
func get_modifier_accessor(accessorName:String) -> Callable:
	if has_method(accessorName):
		return Callable(self, accessorName)
	return Callable()


func get_rank_xp_modifier() -> float:
	var modifier = 1 + XpOffset
	modifier += TimeProgress * XpTimeMod
	modifier += RankMultiplier * XpRankMod
	modifier += float(TormentLevel) * XpLevelMod
	return modifier


func get_torment_difficulty() -> float:
	var modifier = 1 + DifficultyOffset
	modifier += TimeProgress * DifficultyTimeMod
	modifier += RankMultiplier * DifficultyRankMod
	modifier += float(TormentLevel) * DifficultyLevelMod
	return modifier


# set torment speed by passed time
func get_rank_speed_modifier() -> float:
	var modifier = 1 + SpeedOffset
	modifier += TimeProgress * SpeedTimeMod
	modifier += RankMultiplier * SpeedRankMod
	modifier += float(TormentLevel) * SpeedLevelMod
	return modifier

func get_rank_health_modifier() -> float:
	var modifier = 1 + HealthOffset
	modifier += TimeProgress * HealthTimeMod
	modifier += RankMultiplier * HealthRankMod
	modifier += float(TormentLevel) * HealthLevelMod
	return modifier

func get_rank_boss_modifier() -> float:
	var modifier = 1 + BossOffset
	modifier += TimeProgress * BossTimeMod
	modifier += RankMultiplier * BossRankMod
	modifier += float(TormentLevel) * BossLevelMod
	return modifier

func get_rank_boss_health_modifier() -> float:
	var modifier = 1 + BossHealthOffset
	modifier += TimeProgress * BossHealthTimeMod
	modifier += RankMultiplier * BossHealthRankMod
	modifier += float(TormentLevel) * BossHealthLevelMod
	return modifier

func get_rank_damage_modifier() -> float:
	var modifier = 1 + DamageOffset
	modifier += TimeProgress * DamageTimeMod
	modifier += RankMultiplier * DamageRankMod
	modifier += float(TormentLevel) * DamageLevelMod
	return modifier

func get_rank_defense_modifier() -> int:
	var modifier = DefenseOffset
	modifier += TimeProgress * DefenseTimeMod
	modifier += RankMultiplier * DefenseRankMod
	modifier += float(TormentLevel) * DefenseLevelMod
	return floori(modifier)

func get_spawn_count_target_modifier() -> float:
	var modifier = 1 + CapOffset
	modifier += TimeProgress * CapTimeMod
	modifier += RankMultiplier * CapRankMod
	modifier += float(TormentLevel) * CapLevelMod
	return modifier

func get_spawn_spawn_interval_modifier() -> float:
	var modifier = 1 + IntervalOffset
	modifier += TimeProgress * IntervalTimeMod
	modifier += RankMultiplier * IntervalRankMod
	modifier += float(TormentLevel) * IntervalLevelMod
	return modifier

func get_spawns_per_interval_modifier() -> float:
	var modifier = 1 + IntervalOffset
	modifier += TimeProgress * IntervalTimeMod
	modifier += RankMultiplier * IntervalRankMod
	modifier += float(TormentLevel) * IntervalLevelMod
	return modifier

func get_gold_multiplier() -> float:
	var modifier = 1 + GoldOffset
	modifier += TimeProgress * GoldTimeMod
	modifier += RankMultiplier * GoldRankMod
	modifier += float(TormentLevel) * GoldLevelMod
	return modifier

