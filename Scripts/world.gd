extends Node2D
class_name World

@export var PlayerScene : PackedScene
@export var MonsterTeleporterScene : PackedScene
@export var WorldIdentifier : QuestPool.WorldEnum

@export_group("XP Settings")
@export var BaseXP : int = -3
@export var LinearXP : int = 4
@export var Exponent_A : float = 0.95
@export var Factor_A : float = -5.0
@export var Exponent_B : float = 1.04
@export var Factor_B : float = 10.0
@export var XPGainBuffScene : PackedScene

@export_group("Gold Settings")
@export var GoldPerSecond : float = 1.0
@export var GoldScoreBase : float = -300.0
@export var GoldScoreExponent : float = 2.8
@export var GoldScoreFactor : float = 5.0

@export_group("World Settings")
@export var WorldStrengthStart : int = 500
@export var WorldStrengthFinal : int = 19000

@export_group("Music Settings")
@export var StageMusic : AudioStreamOggVorbis

@export_group("Tag Settings")
@export var TagProcesses : Array[Resource]

@export_group("Additional Resources")
@export var ClassMarks : ClassMarkCollection = preload("res://GameElements/ClassMarks/Collection/ClassMarks.tres")

@export_group("Directional Light Settings")
@export var LightColorA : Color
@export var LightDirectionA : Vector3
@export var LightColorB : Color
@export var LightDirectionB : Vector3
@export var PlayerLightEnergy : float = 6.0
@export var PlayerSelfLightEnergy : float = 6.0

var WorldName : String
var Player : GameObject
var TraitPool : Node
var AbilityPool : Node
var ItemPool : Node
var GameTime : float
var Pickups : Node
var Tags : TagManager
var Locators : LocatorSystem
var TwoDMoverSys : TwoDMoverSystem = TwoDMoverSystem.new()
var MonsterInputSys : MonsterInputSystem = MonsterInputSystem.new()
var AreaOfEffectSys : AreaOfEffectSystem = AreaOfEffectSystem.new()
var FastRaybasedMoverSys : FastRaybasedMoverSystem = FastRaybasedMoverSystem.new()
var Collectables : CollectableManager = CollectableManager.new()
var NavigationCaverns : NavigationCavernsSystem = NavigationCavernsSystem.new()
var OffscreenPositioner : Node

var Level : int
var Experience : int
var ExperienceRest : float
var ExperienceOverflow : float
var Gold : int
var KillCount : int
var DamageDealt : int
var DamageReceived : int
var SurvivalTime : float
var RemainingTraitRerollPotions : int = 0
var RemainingTraitBanishPotions : int   = 0
var RemainingTraitDoublePotions : int   = 0
var RemainingTraitMemorizePotions : int = 0
var RemainingAbilityRerollPotions : int = 0
var RemainingItemChestRerollPotions : int = 0
var BottleSpawnedInThisWorld : bool = false

# Partially player-controlled level difficulty
# The TormentRank is a deliberately obscure value which is dynamically increased
# based on player performance. Makes the game harder if the player performs better
# and can be used to trigger semi-secret events during a run.
var TormentRank : Node

@onready var ExperienceThresholdPrev : int = 0
@onready var GainExperience : bool = true
@onready var ExperienceThreshold : int = 7
@onready var PreviousMinute : float = 0.0
var ExperienceMultiplier : float = 1

const DEFAULT_GAME_TIME : float = 1800.0
const GAME_END_TIME : float = 0.1

# for finale testing
# const GAME_END_TIME : float = 1790.0

var game_time_on_last_update : float = -1
var current_world_time : float = 0
var current_world_progress : float = 0

var LordEnemy : GameObject
var IngredientSpawners : Array[Node]

signal PlayerDied
signal BulletSpawnedEvent(bulletObject:GameObject, sourceObject:GameObject)
signal DamageEvent(targetObject:GameObject, sourceObject:GameObject, damageAmount:int, totalDamage:int)
signal DeathEvent(deadObject:GameObject, killedBy:GameObject)
signal SecondPassed(currentTime:float)
signal ExperienceChanged(currentExperience:int, rangeStart:int, rangeEnd:int)
signal ExperienceThresholdReached
signal GoldChanged(currentGold:int)
signal KillCountChanged(currentKillCount:int)
signal AbilityAcquired(abilityNode:Node)
signal AbilityRemoved(abilityNode:Node)
signal FinaleReached
signal LordAppeared(lord:GameObject)
signal EnemyAppeared(spawnedEnemy:GameObject)

func initialize(traitPool:Node, abilityPool:Node, itemPool:Node, use_torment_rank:bool = false):
	# initialize seed for randomization
	var time = Time.get_time_dict_from_system()
	seed(time.hour + time.minute * 10 + time.second * 100)

	TormentRank = $TormentRank
	TormentRank.TimeLength = DEFAULT_GAME_TIME
	TormentRank.enable_torment_rank = use_torment_rank
	print("Agony: %s" % str(use_torment_rank))
	ExperienceThreshold = getLevelUpExperience(1)

	Tags = TagManager.new()
	Locators = LocatorSystem.new()
	for child in get_children():
		if child.has_method("position_node_offscreen"):
			OffscreenPositioner = child
			break
	if OffscreenPositioner == null:
		printerr("Every world needs an OffscreenPositioner in its children!")

	GameState.connect("StateChanged", on_game_state_changed)
	if Global.ChosenPlayerCharacterScene:
		Player = Global.ChosenPlayerCharacterScene.instantiate()
	else:
		Player = PlayerScene.instantiate()

	var playerPositionProvider:Node = Player.getChildNodeWithMethod("get_worldPosition")
	playerPositionProvider.add_child(MonsterTeleporterScene.instantiate())

	# spawn position of the player is 0,0!
	add_child(Player)

	Stats.ResetStats(Player)

	# apply blessings
	for blessing in Global.ShrineBlessingPool.Blessings:
		blessing.applyBlessing(Player)

	# TEMP | TODO -> add xp gain from completed quests as modifier
	var modifier = XPGainBuffScene.instantiate()
	modifier.AddXpPercent = 0.003 * float(Global.QuestPool.count_quest_completed())
	if modifier is EffectBase:
		Player.add_effect(modifier, null)
	else:
		Player.add_child(modifier)

	TraitPool = traitPool
	add_child(TraitPool)
	AbilityPool = abilityPool
	add_child(AbilityPool)
	ItemPool = itemPool
	if use_torment_rank:
		# chance for uncommon items in normal chests
		ItemPool.RarityChances[Item.ItemRarity.Uncommon] = 0.5
	add_child(ItemPool)

	Pickups = $PickupDistribution

	RemainingTraitRerollPotions = Global.PlayerProfile.NumTraitRerollPotions
	RemainingTraitBanishPotions = Global.PlayerProfile.NumTraitBanishPotions
	RemainingTraitDoublePotions = Global.PlayerProfile.NumTraitDoublePotions
	RemainingTraitMemorizePotions = Global.PlayerProfile.NumTraitMemorizePotions
	RemainingAbilityRerollPotions = Global.PlayerProfile.NumAbilityRerollPotions
	RemainingItemChestRerollPotions = Global.PlayerProfile.NumItemChestRerollPotions

	GameTime = DEFAULT_GAME_TIME

	Global.World = self

	NavigationCaverns.init()

	Global.emit_signal("WorldReady")

	# initialize XP view
	addExperience(0)
	equip_player()
	if OS.has_feature("demo"):
		Tags.setTagActive("DEMO")
	if ProjectSettings.get_setting("halls_of_torment/development/enable_na_unlocks"):
		Tags.setTagActive("_NA")
	if ProjectSettings.get_setting("halls_of_torment/development/enable_developer_unlocks"):
		Tags.setTagActive("DEVELOPER")


	# set global directional light shader parameters
	RenderingServer.global_shader_parameter_set("LIGHT_COLOR_A", LightColorA)
	RenderingServer.global_shader_parameter_set("LIGHT_COLOR_B", LightColorB)
	RenderingServer.global_shader_parameter_set("LIGHT_DIR_A", LightDirectionA)
	RenderingServer.global_shader_parameter_set("LIGHT_DIR_B", LightDirectionB)

	if TagProcesses != null:
		for tp in TagProcesses:
			Tags.TagsUpdated.connect(tp.trigger_tag_process)

	await get_tree().create_timer(3).timeout
	Global.QuestPool.notify_halls_entered(null)
	Global.WellItemsPool.notify_item_counts()

func _exit_tree():
	Collectables.uninitialize()

func on_game_state_changed(newState:GameState.States, _oldState:GameState.States):
	if newState == GameState.States.Overworld:
		reset()

func equip_player():
	for item_key in Global.PlayerProfile.Equipped.keys():
		var item_id = Global.PlayerProfile.Equipped[item_key]
		if item_key == "Mark":
			Tags.setTagActive(item_id)
			var mark = ClassMarks.get_mark_via_activatedTag(item_id)
			if mark != null:
				for modifier in mark.Modifiers:
					var m = modifier.instantiate()
					Player.add_child(m)
			continue
		if item_id == null or item_id.is_empty(): continue
		var item = ItemPool.find_item_with_id(item_id)
		if item != null:
			ItemPool.equip_item(item, Player)
	# since this is the start of the level, we apply all the
	# max health modifier of the items!
	var playerHealthComp = Player.getChildNodeWithMethod("resetToMaxHealth")
	if playerHealthComp != null:
		playerHealthComp.resetToMaxHealth()
		playerHealthComp.force_health_update_signals()

func set_game_time(newGameTime:float):
	GameTime = newGameTime
	decrement_game_time(0.0)

func is_game_time_out() -> bool:
	return GameTime <= GAME_END_TIME

func TriggerDamageEvent(
	damagedObject:GameObject,
	damagingObject:GameObject,
	actualDamage:int,
	totalDamage:int,
	critical:bool,
	weapon_index:int) -> void:

	var actualDamageSource = damagingObject
	if damagingObject != null:
		var rootSourceProvider = damagingObject.getChildNodeWithMethod("get_rootSourceGameObject")
		if rootSourceProvider != null:
			actualDamageSource = rootSourceProvider.get_rootSourceGameObject()
	if actualDamageSource != null and actualDamageSource.is_in_group("FromPlayer"):
		DamageDealt += actualDamage
		Global.QuestPool.notify_player_dealt_damage(totalDamage, weapon_index)
		if critical: Global.QuestPool.notify_player_dealt_crit(totalDamage, weapon_index)

	if damagedObject.is_in_group("Player"):
		DamageReceived += actualDamage
	DamageEvent.emit(damagedObject, actualDamageSource, actualDamage, totalDamage)


func TriggerDeathEvent(deadObject:GameObject, killerObject:GameObject) -> void:
	var actualKiller = killerObject
	if actualKiller != null:
		var rootSourceProvider = actualKiller.getChildNodeWithMethod("get_rootSourceGameObject")
		if rootSourceProvider != null:
			actualKiller = rootSourceProvider.get_rootSourceGameObject()

	if actualKiller != null and killerObject.is_in_group("FromPlayer"):
		addToKillCount(1)
	if deadObject.is_in_group("Player"):
		print("Player was killed by %s"%str(killerObject))
		SurvivalTime = DEFAULT_GAME_TIME - GameTime
		emit_signal("PlayerDied")
		GameState.SetState(GameState.States.PlayerDied)
	DeathEvent.emit(deadObject, killerObject)
	if deadObject != Global.World.Player:
		Global.QuestPool.notify_enemy_killed(deadObject)


func _process(delta):
	current_world_time += delta
	current_world_progress = current_world_time / DEFAULT_GAME_TIME
	decrement_game_time(delta)

	if NavigationCaverns.world_has_navigation_caverns():
		var screenspace2worldspace = get_canvas_transform().affine_inverse()
		var viewportSize = get_viewport().get_visible_rect().size
		var middleScreenPos = screenspace2worldspace * (viewportSize / 2.0)
		NavigationCaverns.updateCurrentCavernScreenView(middleScreenPos, 1300, 1000)
		NavigationCaverns.update()

	MonsterInputSys.updateMonsterInput(delta)
	TwoDMoverSys.update2DMover(delta)
	FastRaybasedMoverSys.updateRayMover(delta)
	AreaOfEffectSys.updateAreaOfEffect(delta)
	Locators.update()
	Stats.UpdateStats(delta)
	Collectables.updateCollectableManager(delta)


func decrement_game_time(delta):
	if GameState.CurrentState == GameState.States.PlayerDied: return
	GameTime = clamp(GameTime - delta, 0, Global.MAX_VALUE)
	if abs(GameTime - game_time_on_last_update) >= 1 || (GameTime <= GAME_END_TIME && !_finale_triggered):
		game_time_on_last_update = GameTime
		SecondPassed.emit(GameTime)

		var survival_time = DEFAULT_GAME_TIME - GameTime
		var minutes_survived = (survival_time - fmod(survival_time, 60.0)) / 60.0
		if minutes_survived > PreviousMinute:
			Global.QuestPool.notify_minute_passed(minutes_survived)
			PreviousMinute = minutes_survived

	if GameTime <= GAME_END_TIME:
		trigger_finale()


var _finale_triggered : bool
func trigger_finale():
	if not _finale_triggered:
		_finale_triggered = true
		SurvivalTime = DEFAULT_GAME_TIME
		FinaleReached.emit()

		var tree = get_tree()

		var kill_batch_count : int = 0
		for c in get_children():
			if c == Player: continue
			if c != null and not c.is_queued_for_deletion() and c is GameObject:
				var health = c.getChildNodeWithMethod("instakill")
				if health != null:
					health.instakill()
					kill_batch_count += 1
					if kill_batch_count == 10:
						kill_batch_count = 0
						await tree.process_frame

func notify_lord_appearance(lord:GameObject):
	LordEnemy = lord
	LordAppeared.emit(LordEnemy)


var NoModifierCategories : Array[String] = []
func addExperience(xpAmount:int, no_modifier:bool = false):
	if not GainExperience: return
	if Player == null or Player.is_queued_for_deletion(): return

	var actualXpAmount : float = xpAmount
	if not no_modifier:
		actualXpAmount = Player.calculateModifiedValue("XpGain", float(xpAmount), NoModifierCategories) * ExperienceMultiplier
	ExperienceRest += fmod(actualXpAmount, 1.0)
	if ExperienceRest >= 1.0:
		actualXpAmount += floor(ExperienceRest)
		ExperienceRest = fmod(ExperienceRest, 1.0)

	Logging.log_pickup("XP", actualXpAmount)
	Experience += int(floor(actualXpAmount))
	if Experience >= ExperienceThreshold:
		Level += 1
		ExperienceThresholdPrev = ExperienceThreshold
		ExperienceThreshold += getLevelUpExperience(Level + 1)
		emit_signal("ExperienceThresholdReached")
		Logging.log_levelup(Level)
		Global.QuestPool.notify_level_up(Level)
	emit_signal("ExperienceChanged",
		Experience,
		ExperienceThresholdPrev,
		ExperienceThreshold)

func getLevelUpExperience(targetLevel:int):
		var part_a : float = pow(Exponent_A, targetLevel) * Factor_A * targetLevel
		var part_b : float = pow(Exponent_B, targetLevel) * Factor_B * targetLevel
		return floor(BaseXP + LinearXP * targetLevel + part_a + part_b)

func addGold(goldAmount:int):
	if Player == null or Player.is_queued_for_deletion(): return

	var modifiedGoldAmount = ceil(Player.calculateModifiedValue("GoldGain", float(goldAmount), NoModifierCategories) - 0.001)
	Logging.log_pickup("GOLD", modifiedGoldAmount)
	Gold += modifiedGoldAmount
	emit_signal("GoldChanged", Gold)
	Global.QuestPool.notify_gold_collected(modifiedGoldAmount)


func getWorldStrength() -> int:
	return lerp(WorldStrengthStart, WorldStrengthFinal, current_world_progress)


func getGoldByPlaytime() -> int:
	return ceili(SurvivalTime * GoldPerSecond)


func getGoldByScore() -> int:
	return max(0,ceili(pow(float(get_real_torment_score()), 1/GoldScoreExponent) * GoldScoreFactor + GoldScoreBase))


func addToKillCount(killCount:int):
	KillCount += killCount
	emit_signal("KillCountChanged", KillCount)

func reset():
	Level = 1
	Experience = 0
	ExperienceThreshold = getLevelUpExperience(1)
	addExperience(0)

	Gold = 0
	addGold(0)

	KillCount = 0
	addToKillCount(0)

	set_game_time(DEFAULT_GAME_TIME)

	DamageDealt = 0
	DamageReceived = 0
	SurvivalTime = 0

func get_player_position() -> Vector2:
	if Player != null:
		var player_position_provider = Player.getChildNodeWithMethod("get_worldPosition")
		if player_position_provider != null:
			return player_position_provider.get_worldPosition()
	return Vector2.ZERO


func get_torment_rank() -> float:
	if TormentRank != null:
		return TormentRank.RankIndex
	return 0.0

func get_torment_rank_value() -> int:
	if TormentRank != null:
		return TormentRank.RankValue
	return 0

# use this for display, cheap
func get_torment_score() -> int:
	if TormentRank != null:
		return TormentRank.TormentScore
	return 0

# use this for important stuff like gold calculation and leaderboard
func get_real_torment_score() -> int:
	if TormentRank != null:
		return TormentRank.get_torment_score()
	return 0

func get_torment_rank_name() -> String:
	if TormentRank != null && TormentRank.RankName != null:
		return TormentRank.RankName
	return "NA"

func get_torment_rank_progress() -> float:
	if TormentRank != null:
		if TormentRank.RankIndex < 5:
			return TormentRank.RankProgress
	return 1.0

const WEAPON_INDEX_NAMES = {
   1: "Zweihänder",
   2: "Bow",
   3: "Flame Caster",
   4: "Holy Sceptre",
   5: "Ravaging Spectres",
   6: "Chain Lightning",
   7: "War Hammer",
   8: "Shield",
   9: "Dual Axes",
   10: "Frost Nova",
   11: "Frost Spear",
   12: "Hound",
   99: "Burn Damage",
   98: "Electrify Damage",
   97: "Frost Damage",
   89: "Fragile Effect",
   88: "Affliction Effect",
   87: "Slow Effect",
   70: "Token of Pain"
}

func get_name_from_weapon_index(weaponIndex:int) -> String:
	if WEAPON_INDEX_NAMES.has(weaponIndex):
		return WEAPON_INDEX_NAMES[weaponIndex]
	if weaponIndex >= 1000:
		return AbilityPool.get_ability_name_from_weapon_index(weaponIndex)
	if weaponIndex >= 100:
		return ItemPool.get_item_name_from_weapon_index(weaponIndex)
	if weaponIndex == 0:
		return "Not Player"
	return "Missing Index"

# hardcoded icons for things that aren't items or abilities:
var WEAPON_INDEX_ICONS = {
   1: load("res://Sprites/Icons/MiscDamage/misc_weapon_sword.png"),  # "Swordsman Weapon",
   2: load("res://Sprites/Icons/MiscDamage/misc_weapon_archer.png"), # "Archer Weapon",
   3: load("res://Sprites/Icons/MiscDamage/misc_weapon_exterminator.png"), # "Exterminator Weapon",
   4: load("res://Sprites/Icons/MiscDamage/misc_weapon_cleric.png"), # "Cleric Weapon",
   5: load("res://Sprites/Icons/MiscDamage/misc_weapon_warlock.png"), # "Warlock Weapon",
   6: load("res://Sprites/Icons/MiscDamage/misc_weapon_sorceress.png"), # "Sorceress Weapon",
   7: load("res://Sprites/Icons/MiscDamage/misc_weapon_shieldmaiden.png"), # "Shieldmaiden Weapon",
   8: load("res://Sprites/Icons/MiscDamage/misc_shield_bash.png"), # "Shieldmaiden Shield",
   9: load("res://Sprites/Icons/MiscDamage/misc_weapon_norseman.png"), # "Norseman Weapon",
   10: load("res://Sprites/Icons/MiscDamage/misc_frost_nova.png"), # "Norseman Nova",
   11: load("res://Sprites/Icons/MiscDamage/misc_weapon_beasthuntress.png"), # "Beast Huntress Weapon",
   12: load("res://Sprites/Icons/MiscDamage/misc_hound_damage.png"), # "Beast Huntress Pet",
   99: load("res://Sprites/Icons/MiscDamage/misc_burn_damage.png"), # "Burn Damage",
   98: load("res://Sprites/Icons/MiscDamage/misc_electrify_damage.png"), # "Electrify Damage",
   97: load("res://Sprites/Icons/MiscDamage/misc_frost_damage.png"), # "Frost Damage",
   89: load("res://FX/fragile.png"), # "Fragile Effect",
   88: load("res://FX/affliction.png"), # "Affliction Effect",
   87: load("res://FX/slow.png"), # "Slow Effect"
   70: load("res://Sprites/Icons/MiscDamage/misc_token_of_pain.png") # Token of Pain
}

func get_icon_from_weapon_index(weaponIndex:int) -> Texture2D:
	if WEAPON_INDEX_ICONS.has(weaponIndex):
		return WEAPON_INDEX_ICONS[weaponIndex]
	if weaponIndex >= 1000:
		return AbilityPool.get_ability_icon_from_weapon_index(weaponIndex)
	if weaponIndex >= 100:
		return ItemPool.get_item_icon_from_weapon_index(weaponIndex)

	return null
