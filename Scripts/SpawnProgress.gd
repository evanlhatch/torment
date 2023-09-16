extends Node2D

@export var SpawnProgressData : Resource

@export_category("Champions")
@export var BaseChampionTime : float = 150
@export var TimeReductionPerAgony : float = 15
@export var PossibleChampions : Array[ChampionResource]
@export var PossibleChampionModifier : Array[ChampionModifierResource]
@export var PossibleChampionAbilities : Array[ChampionAbilityResource]
@export var PossibleChampionAdds : Array[ChampionAddResource]
@export var PossibleChampionRewards : Array[ChampionRewardResource]

var passedIndices : Array[int]
@onready var WaveSpawnerScript : GDScript  = load("res://Scripts/Spawning/WaveSpawner.gd")
var timeUntilNextChampion : float = 90
var allEdges : Array[int] = [0,1,2,3]

func _ready():
	if not Global.is_world_ready():
		await Global.WorldReady

	if !SpawnProgressData:
		printerr("SpawnProgress Node has no LevelProgression resource set! Aborting!")
		return

	Global.World.connect("SecondPassed", _on_second_passed)


func _on_second_passed(currentTime:float):
	for entryIndex in len(SpawnProgressData.Entries):
		if passedIndices.has(entryIndex):
			continue
		var entry : LevelProgressionSpawnEntry = SpawnProgressData.Entries[entryIndex]
		if entry.Start >= currentTime:
			passedIndices.append(entryIndex)
			var spawner = WaveSpawnerScript.new()
			spawner.SpawnScene = entry.SpawnedScene

			spawner.SpawnInterval = entry.SpawnInterval
			spawner.SpawnIntervalUsesRank = entry.ApplyTormentToSpawnInterval

			spawner.NumberOfSpawnsPerInterval = entry.SpawnsPerInterval
			spawner.SpawnNumberPerIntervalUsesRank = entry.ApplyTormentToSpawnsPerInterval

			spawner.SpawnTargetCount = entry.CountTarget
			spawner.SpawnTargetUsesRank = entry.ApplyTormentToCountTarget

			spawner.Lifetime = entry.Start - entry.End
			spawner.MakeSpawnedDisposableOnExit = entry.DisposableOnExit
			spawner.DestroyWhenTargetCountReached = entry.DestroyOnTargetCount

			spawner.MinRank = entry.MinRank
			spawner.MaxRank = entry.MaxRank

			spawner.set_spawn_flags(entry.SpawnFlags)

			Global.attach_toWorld(spawner)

	timeUntilNextChampion -= 1
	if timeUntilNextChampion <= 0:
		spawn_champion()
		var agony = Global.World.TormentRank.RankMultiplier * 0.2
		timeUntilNextChampion += BaseChampionTime - agony * TimeReductionPerAgony


func spawn_champion():
	if Global.World.TormentRank == null or not Global.World.TormentRank.enable_torment_rank:
		return

	var difficulty : float = Global.World.TormentRank.get_torment_difficulty()
	var agony = Global.World.TormentRank.RankMultiplier * 0.2
	var champion : GameObject = pick_champion(difficulty)
	Global.World.OffscreenPositioner.position_node_offscreen(champion, allEdges)
	PossibleChampionModifier.pick_random().ApplyToGameObject(champion, difficulty)
	PossibleChampionAbilities.pick_random().AddAbilityToGameObject(champion)
	pick_add(champion.global_position, difficulty)
	pick_champion_reward(champion, agony)

func pick_champion(difficulty:float) -> GameObject:
	for champion in PossibleChampions:
		if champion.choose_this_champion(difficulty):
			return champion.SpawnChampion(difficulty)
	return PossibleChampions.back().SpawnChampion(difficulty)

func pick_add(champion_pos:Vector2, difficulty:float):
	for monster in PossibleChampionAdds:
		if monster.choose_this_monster(difficulty):
			return monster.SpawnAdds(champion_pos, difficulty)
	return PossibleChampionAdds.back().SpawnAdds(champion_pos, difficulty)

func pick_champion_reward(champion:GameObject, agony:float):
	for reward in PossibleChampionRewards:
		if reward.choose_this_reward(agony):
			reward.AddSpawnOnDeathToGameObject(champion)
			return
	PossibleChampionRewards.back().AddSpawnOnDeathToGameObject(champion)