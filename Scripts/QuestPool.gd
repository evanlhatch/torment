@tool
extends Node
class_name QuestPool

const MainQuests = [
	"q_Caverns_Survive_1",
	"q_Main_GoldCollected_1",
	"q_Caverns_Boss_1",
	"q_Ember_Wellkeeper_1",
	"q_Ember_Wellkeeper_2",
	"q_Ember_Kills_1",
	"q_Sworsdman_Damage_1",
	"q_Archer_Crits_1",
	"q_Exterminator_BurnDamage_1",
	"q_Caverns_Boss_3",
	"q_Ember_Boss_2",
	"q_Viaduct_Cupbearer_1",
	"q_Viaduct_Boss_1",
	"q_Ember_Boss_3",
	"q_Viaduct_Kills_3",
	"q_Caverns_Lord_1",
	"q_Ember_Lord_1",
	"q_Viaduct_Lord_1"
]

func get_next_main_quest():
	for n in MainQuests.size():
		if not is_quest_complete(MainQuests[n]):
			var nextMainQuest = get_quest(MainQuests[n])
			if nextMainQuest != null:
				return nextMainQuest
	return null

# This dictionary is used to unlock quest boards upon completion of the appropriate quest.
# The key is the quest_id of the required quest, the value is the name of the unlocked board.
# (Notice: quest boards are sometimes also referred to as "Quest Groups" in the code!)
@export var QuestBoardUnlocks : Dictionary = {}

@export var QuestsScenesFolders : Array[String]= [
]

@export var IsDemoPool : bool = false
@export var FetchQuestScenes : bool:
	set(_value):
		fetch_quests()
		notify_property_list_changed()

@export var ApplyDataFromConfigs : bool = true
@export var QuestDataFolder : String = "GameElements/Quests/QuestData"
@export var IconBasePath : String = "res://Sprites/Icons/Quests/"
@export var FallbackIcon : String = "res://Sprites/Icons/Quests/questicon_029.png"

@export var QuestScenePaths : Array[String] = []

@export var OutputQuestList : bool:
	set(_value):
		output_quests()

# extend this enum only at the end!
enum QuestBoardEnum {
	CHAPTER_1,
	CHAPTER_2,
	SWORDSMAN,
	ARCHER,
	EXTERMINATOR,
	SHIELDMAIDEN,
	MAIN,
	CHAPTER_3,
	CLERIC,
	WARLOCK,
	SORCERESS,
	CHAPTER_4,
	NORSEMAN,
	BEASTHUNTRESS
}

# extend this enum only at the end!
enum CharacterEnum {
	ANY,
	SWORDSMAN,
	ARCHER,
	EXTERMINATOR,
	SHIELDMAIDEN,
	CLERIC,
	WARLOCK,
	SORCERESS,
	NORSEMAN,
	BEASTHUNTRESS
}

# extend this enum only at the end!
enum WorldEnum {
	ANY,
	HAUNTED_CAVERNS,
	EMBER_GROUNDS,
	FORGOTTEN_VIADUCT,
	FROZEN_DEPTHS
}

# extend this dictionary only at the end! Entries must match QuestBoardEnum!
@onready var QuestBoards = [
	{
		"sorting_id": 0,
		"board_name": "QuestsChapter1",
		"ui_title": "[color=#aaa]Chapter I:[/color] Haunted Caverns",
		"hidden_title": "[color=#777]Chapter I locked[/color]"
	},
	{
		"sorting_id": 1,
		"board_name": "QuestsChapter2",
		"ui_title": "[color=#aaa]Chapter II:[/color] Ember Grounds",
		"hidden_title": "[color=#777]Chapter II locked[/color]"
	},
	{
		"sorting_id": 4,
		"board_name": "QuestsSwordman",
		"ui_title": "[color=#aaa]Story:[/color] Path of the Sword",
		"hidden_title": "[color=#777]Story I locked[/color]"
	},
	{
		"sorting_id": 5,
		"board_name": "QuestsArcher",
		"ui_title": "[color=#aaa]Story:[/color] Swift as an Arrow",
		"hidden_title": "[color=#777]Story II locked[/color]"
	},
	{
		"sorting_id": 6,
		"board_name": "QuestsExterminator",
		"ui_title": "[color=#aaa]Story:[/color] Scorched Earth",
		"hidden_title": "[color=#777]Story III locked[/color]"
	},
	{
		"sorting_id": 9,
		"board_name": "QuestsShieldMaiden",
		"ui_title": "[color=#aaa]Story:[/color] Steady Shield",
		"hidden_title": "[color=#777]Story IV locked[/color]"
	},
	{
		"sorting_id": 13,
		"board_name": "QuestsMain",
		"ui_title": "Milestones",
		"hidden_title": "[color=#777]Milestones not available[/color]"
	},
	{
		"sorting_id": 2,
		"board_name": "QuestsChapter3",
		"ui_title": "[color=#aaa]Chapter III:[/color] Forgotten Viaduct",
		"hidden_title": "[color=#777]Story IV locked[/color]"
	},
	{
		"sorting_id": 7,
		"board_name": "QuestsCleric",
		"ui_title": "[color=#aaa]Story:[/color] Unholy Crusade",
		"hidden_title": "[color=#777]Story IV locked[/color]"
	},
	{
		"sorting_id": 8,
		"board_name": "QuestsWarlock",
		"ui_title": "[color=#aaa]Story:[/color] Demonic Pact",
		"hidden_title": "[color=#777]Story IV locked[/color]"
	},
	{
		"sorting_id": 10,
		"board_name": "QuestsSorceress",
		"ui_title": "[color=#aaa]Story:[/color] Lightning Storm",
		"hidden_title": "[color=#777]Story IV locked[/color]"
	},
	{
		"sorting_id": 3,
		"board_name": "QuestsChapter4",
		"ui_title": "[color=#aaa]Chapter IV:[/color] Frozen Depths",
		"hidden_title": "[color=#777]Chapter IV locked[/color]"
	},
	{
		"sorting_id": 12,
		"board_name": "QuestsNorseman",
		"ui_title": "[color=#aaa]Story:[/color] Cold Fury",
		"hidden_title": "[color=#777]Story IX locked[/color]"
	},
	{
		"sorting_id": 11,
		"board_name": "QuestsBeastHuntress",
		"ui_title": "[color=#aaa]Story:[/color] Beast Tracker",
		"hidden_title": "[color=#777]Story VIII locked[/color]"
	}
]
@onready var _unlocked_quest_boards : Array[QuestBoardEnum] = []
@onready var _quests_completed_during_run : Array[Node] = []

var _quest_id_lookup = {}
var QuestProfileData
var CharacterName : String

signal QuestCompleted(quest_node)
signal QuestBoardUnlocked(quest_board_name:QuestBoardEnum)

func fetch_quests():
	if QuestScenePaths == null: QuestScenePaths = []

	var s : String = ""
	var data = QuestDatabase.new()
	if ApplyDataFromConfigs:
		data.load_from_path(QuestDataFolder)

	QuestScenePaths.clear()
	for d in QuestsScenesFolders:
		var dir = DirAccess.open(d)
		if dir:
			dir.list_dir_begin()
			while true:
				var file_name = dir.get_next()
				if file_name == "": break
				elif !file_name.begins_with(".") and file_name.find(".tscn") >= 0:
					if IsDemoPool:
						var node : Node = load(d + "/" +file_name).instantiate()
						if not node.is_in_group("DemoQuest"): continue
					QuestScenePaths.append(d + "/" +file_name)
					if ApplyDataFromConfigs:
						update_quest_data(data, file_name, d + "/" +file_name)
			dir.list_dir_end()
		else:
			printerr("Could not open folder: %s" % d)

func update_quest_data(data : QuestDatabase, file_name : String, full_path : String):
	var item = data.get_item(file_name)
	if item != null:
		var node : Node = load(full_path).instantiate()
		for key in item.keys():
			if key == "Icon":
				var img = load(IconBasePath+item[key])
				if img == null:
					img = load(FallbackIcon)
				if img != null:
					node.set(key, img)
				continue
			node.set(key, item[key])
		var scene = PackedScene.new()
		var result = scene.pack(node)
		if result == OK:
			ResourceSaver.save(scene, full_path)
		else:
			printerr("Could not save scene: %s" % full_path)

func output_quests():
	var s : String = ""
	for d in QuestsScenesFolders:
		var dir = DirAccess.open(d)
		if dir:
			dir.list_dir_begin()
			while true:
				var file_name = dir.get_next()
				if file_name == "": break
				elif !file_name.begins_with(".") and file_name.find(".tscn") >= 0:
					var node : Node = load(d + "/" +file_name).instantiate()
					s += node.ID + "\t" + node.Icon.resource_path + "\t" + node.Name + "\t" + node.Description + "\t" + QuestBoardEnum.keys()[node.QuestBoard] + "\t" + CharacterEnum.keys()[node.RequiredCharacter] + "\t" + WorldEnum.keys()[node.RequiredWorld] + "\n"
					node.queue_free()
			dir.list_dir_end()
	print(s)


func _ready():
	load_quests()
	for unlockedBoardName in Global.PlayerProfile.QuestBoards:
		for index in len(QuestBoards):
			if QuestBoards[index].board_name == unlockedBoardName:
				_unlocked_quest_boards.append(index as QuestBoardEnum)

func queue_resource_load():
	for questScenePath in QuestScenePaths:
		ResourceLoaderQueue.queueResource(questScenePath)

func instantiate_item_children():
	for questScenePath in QuestScenePaths:
		var questResource = ResourceLoaderQueue.getCachedResource(questScenePath)
		var quest = questResource.instantiate()
		var quest_data = get_quest_profile_data(quest.ID)
		if quest_data: quest.set_data(quest_data)
		add_child(quest)
		quest.QuestProgressed.connect(set_quest_profile_data)
		quest.QuestHiddenStateChanged.connect(set_quest_profile_data)
		quest.QuestCompleted.connect(_on_quest_completed)
	Global.WorldReady.connect(_on_world_ready)

func _on_world_ready():
	_quests_completed_during_run.clear()
	CharacterName = Global.World.Player.name
	print(CharacterName)

func load_quests():
	if Global.PlayerProfile.has("Quests"):
		QuestProfileData = Global.PlayerProfile["Quests"]
		for i in len(QuestProfileData):
			_quest_id_lookup[QuestProfileData[i]["ID"]] = i
	else:
		QuestProfileData = []


func save_quests():
	Global.PlayerProfile["Quests"] = QuestProfileData
	Global.schedulePlayerProfileSaving()


func is_quest_complete(_quest_id:String) -> bool:
	if Global.PlayerProfile.has("Quests"):
		for q in Global.PlayerProfile.Quests:
			if q.ID == _quest_id and q.completed: return true
	return false


func count_quest_completed() -> int:
	var count : int = 0
	for q in get_children():
		if q.is_completed(): count += 1
	return count


func is_unlock_key_set(unlock_key:String) -> bool:
	if Global.PlayerProfile.has("Unlocked"):
		return Global.PlayerProfile.Unlocked.has(unlock_key)
	return false


func set_unlock_key(unlock_key:String):
	if Global.PlayerProfile.has("Unlocked"):
		if not Global.PlayerProfile.Unlocked.has(unlock_key):
			Global.PlayerProfile.Unlocked.append(unlock_key)
	Global.savePlayerProfile(true)


func get_quest_profile_data(_quest_id:String):
	for q in QuestProfileData:
		if q["ID"] == _quest_id:
			return q
	return null



func set_quest_profile_data(quest:Node):
	if _quest_id_lookup.has(quest.ID):
		var index = _quest_id_lookup[quest.ID]
		# overwrite existing quest data
		QuestProfileData[index]["count"] = quest._count
		QuestProfileData[index]["hidden"] = quest.IsHidden
		QuestProfileData[index]["completed"] = quest.is_completed()
		return
	# save new quest data
	var questData = {
		"ID" : quest.ID,
		"count" : quest._count,
		"hidden" : quest.IsHidden,
		"completed" : quest.is_completed()
	}
	QuestProfileData.append(questData)
	_quest_id_lookup[quest.ID] = len(QuestProfileData) - 1
	save_quests()


func _on_quest_completed(quest:Node, pay_reward:bool = true):
	QuestCompleted.emit(quest)
	_quests_completed_during_run.append(quest)
	Global.set_achievement(quest.ID)
	if quest.RewardInSameRun and Global.is_world_ready():
		Global.World.Tags.setTagActive(quest.ID)
	if pay_reward and quest.GoldReward > 0: Global.earnGold(quest.GoldReward, false)
	# unhide all adjacent quests
	var quests_in_same_board = get_all_quests_in_board(quest.QuestBoard)
	quest.set_hidden(false)
	for q in quests_in_same_board:
		if ((q.Column == quest.Column and abs(quest.Row - q.Row) < 2) or
			(q.Row == quest.Row and abs(quest.Column - q.Column) < 2)):
			q.set_hidden(false)

	# unlock quest board if applicable
		if QuestBoardUnlocks.keys().has(quest.ID):
			if not QuestBoardEnum.has(QuestBoardUnlocks[quest.ID]):
				printerr("QuestBoardUnlocks key %s does not exist in QuestBoardEnum" % QuestBoardUnlocks[quest.ID])
				return
			unlock_quest_board(QuestBoardEnum.get(QuestBoardUnlocks[quest.ID]))


func is_quest_board_available(quest_board_enum:QuestBoardEnum) -> bool:
	return _unlocked_quest_boards.has(quest_board_enum)


func get_all_quests_in_board(quest_board_enum:QuestBoardEnum) -> Array[Node]:
	var result : Array[Node] = []
	for q in get_children():
		if q.QuestBoard == quest_board_enum:
			result.append(q)
	return result

func get_all_quests() -> Array[Node]:
	var result : Array[Node] = []
	for q in get_children():
		result.append(q)
	return result

func get_quest(quest_id:String) -> Node:
	for q in get_children():
		if q.ID == quest_id:
			return q
	return null

func unlock_quest_board(quest_board_enum:QuestBoardEnum):
	var board_name = QuestBoards[quest_board_enum].board_name
	if not Global.PlayerProfile.QuestBoards.has(board_name):
		Global.PlayerProfile.QuestBoards.append(board_name)
		Global.savePlayerProfile(true)
		_unlocked_quest_boards.append(quest_board_enum)
		QuestBoardUnlocked.emit(quest_board_enum)

func get_character_name_from_enum(character_enum):
	match(character_enum):
		CharacterEnum.ANY: return "any"
		CharacterEnum.SWORDSMAN: return "Swordsman"
		CharacterEnum.ARCHER: return "Archer"
		CharacterEnum.EXTERMINATOR: return "Exterminator"
		CharacterEnum.SHIELDMAIDEN: return "Shield Maiden"
		CharacterEnum.CLERIC: return "Cleric"
		CharacterEnum.WARLOCK: return "Warlock"
		CharacterEnum.SORCERESS: return "Sorceress"
		CharacterEnum.NORSEMAN: return "Norseman"
		CharacterEnum.BEASTHUNTRESS: return "Beast Huntress"
	return ""


#==============================================================================#
#						QUEST NOTIFICATION FUNCTIONS						   #
#==============================================================================#

# Parameter modes define, how quests increment their count and check for completion conditions.
# -- 0: Signal Emit Count: The quest counts the number of times the given signal has been emitted.
# -- 1: Signal Param: The quest increments the count by the first parameter (assuming it is int)
#		of the received signal.
# -- 2: Signal Param Field: The quest assumes the first parameter is a Node or dictionary.
#		It uses 'ParamFieldName' to access a field on the parameter (if possible)
#		and adds the field's value to the count.
# -- 3: String Param Condition: The quest increments count if the first parameter of the incoming
#		signal is a string that matches 'ParamFieldName'.
# -- 4: Count When Two Params: The quest will increment count if both incoming signal parameters
#		satisfy the conditions set in the "Two Parameter" count settings
#		(assuming both parameters are int). See Param1Check and Param2Check.
# -- 5: Count When Name Param: The quest assumes the first parameter is a Node or dictionary.
#		It tries to access a 'Name' field on the parameter and increments count if the content
#		of the 'Name' field matches ParamFieldName.

signal AbilityAcquired(new_ability, _param2)
signal BlessingPurchased(blessing, _param2)
signal BossKilled(boss_name, _param2)
signal LordKilled(boss_name, _param2)
signal CriticalHit(damage, _param2)
signal DestructableKilled(destructable, _param2)
signal EnemyKilled(enemy, _param2)
signal GoldCollected(gold_amount, _param2)
signal HallsEntered(param, _param2)
signal ItemFound(new_item, _param2)
signal ItemRetreived(item, _param2)
signal ItemBought(item, _param2)
signal ScrollFound(scroll, _param2)
signal LevelUp(level, _param2)
signal MinutePassed(minute, _param2)
signal PlayerBlocked(player, _param2)
signal PlayerDealtDamage(damage, _param2)
signal PotionCollected(potion, _param2)
signal TraitAcquired(new_trait, _param2)
signal EliteKilled(elite_name, _param2)
signal GenericProgress(progress_name, _param2)
signal EffectApplied(effect_name, _param2)
signal HealthRegenerated(health_amount, _param2)
signal HealthRecovered(health_amount, _param2)
signal DamageTaken(damage_amount, _param2)
signal HitTaken(damage_amount, _param2)
signal PlayerWalked(time_taken, _param2)
signal PlayerSpeed(speed, _param2)
signal PlayerUndamaged(duration, _param2)
signal EffectKill(damage_category, _param2)
signal FireDamage(amount, _param2)
signal LightningDamage(amount, _param2)
signal MagicDamage(amount, _param2)
signal SummonDamage(amount, _param2)
signal PhysicalDamage(amount, _param2)
signal IceDamage(amount, _param2)
signal BurnDamage(amount, _param2)
signal ElectrifyDamage(amount, _param2)
signal FrostDamage(amount, _param2)
signal FrostKill(amount, _param2)
signal EnemiesBurning(number, _param2)
signal EnemiesHitByAttack(number, _param2)
signal EffectStacks(number, param2)
signal MaxHealthChanged(health_amount, _param2)
signal DefenseChanged(defense_amount, _param2)
signal CurrentMaxHealth(health_amount, _param2)
signal DamageBlocked(damage_amount, _param2)
signal StageFinished(survive_time, _param2)
signal TagUnlocked(tag_name, _param2)
signal ItemsTotalStash(amount, _param2)
signal ItemsTotalRetrieved(amount, _param2)
signal DamageFromStats(amount, _param2)
signal AgonyReached(agony_value, time)

func notify_enemy_killed(enemy): EnemyKilled.emit(enemy, 0)
func notify_minute_passed(minute): MinutePassed.emit(minute, 0)
func notify_item_found(new_item): ItemFound.emit(new_item, 0)
func notify_item_retreived(new_item): ItemRetreived.emit(new_item, 0)
func notify_item_bought(new_item): ItemBought.emit(new_item, 0)
func notify_scroll_found(scroll): ScrollFound.emit(scroll, 0)
func notify_trait_acquired(new_trait_name): TraitAcquired.emit(new_trait_name, 0)
func notify_ability_acquired(new_ability): AbilityAcquired.emit(new_ability, 0)
func notify_level_up(level): LevelUp.emit(level, 0)
func notify_blessing_purchased(blessing_name, unlock_level): BlessingPurchased.emit(blessing_name, unlock_level)
func notify_player_blocked(player): PlayerBlocked.emit(player, 0)
func notify_player_dealt_damage(damage, weapon_index): PlayerDealtDamage.emit(damage, weapon_index)
func notify_player_dealt_crit(damage, weapon_index): CriticalHit.emit(damage, weapon_index)
func notify_destructable_killed(destructable): DestructableKilled.emit(destructable, 0)
func notify_potion_collected(potion): PotionCollected.emit(potion, 0)
func notify_generic_progress(progress_name): GenericProgress.emit(progress_name, 0)
func notify_effect_applied(effect_name): EffectApplied.emit(effect_name, 0)
func notify_health_regenerated(health_amount): HealthRegenerated.emit(health_amount, 0)
func notify_health_recovered(health_amount): HealthRecovered.emit(health_amount, 0)
func notify_damage_taken(damage_amount): DamageTaken.emit(damage_amount, 0)
func notify_on_hit_taken(hits, blocked): HitTaken.emit(hits, blocked) #can be used to also count blocked hits
func notify_player_walked(time_taken): PlayerWalked.emit(time_taken, 0)
func notify_player_speed(new_speed): PlayerSpeed.emit( new_speed, 0)
func notify_player_undamaged(duration): PlayerUndamaged.emit(duration, 0)
func notify_effect_kill(damage_category): EffectKill.emit(damage_category, 0)
func notify_fire_damage(amount): FireDamage.emit(amount, 0)
func notify_lightning_damage(amount): LightningDamage.emit(amount, 0)
func notify_physical_damage(amount): PhysicalDamage.emit(amount, 0)
func notify_ice_damage(amount): IceDamage.emit(amount, 0)
func notify_magic_damage(amount): MagicDamage.emit(amount, 0)
func notify_summon_damage(amount): SummonDamage.emit(amount, 0)
func notify_burn_damage(amount): BurnDamage.emit(amount, 0)
func notify_electrify_damage(amount): ElectrifyDamage.emit(amount, 0)
func notify_frost_damage(amount): FrostDamage.emit(amount, 0)
func notify_frost_kill(): FrostKill.emit(1, 0)
func notify_enemies_burning(number): EnemiesBurning.emit(number, 0)
func notify_enemies_hit_by_attack(number, weapon_index): EnemiesHitByAttack.emit(number, weapon_index)
func notify_effect_stacks(amount, weapon_index): EffectStacks.emit(amount, weapon_index)
func notify_max_health_changed(change_amount, new_amount): MaxHealthChanged.emit(change_amount, new_amount)
func notify_defense_changed(change_amount, new_amount): DefenseChanged.emit(change_amount, new_amount)
func notify_current_max_health(health_amount): CurrentMaxHealth.emit(health_amount, 0)
func notify_damage_blocked(block_amount): DamageBlocked.emit(block_amount, 0)
func notify_stage_finished(survive_time): StageFinished.emit(survive_time, 0)
func notify_tag_unlocked(tag_name): TagUnlocked.emit(tag_name, 0)
func notify_total_stash(amount): ItemsTotalStash.emit(amount, 0)
func notify_total_retrieved(amount): ItemsTotalRetrieved.emit(amount, 0)
func notify_damage_from_stats(damage, weapon_index): DamageFromStats.emit(damage, weapon_index)
func notify_agony_reached(agony_value, time): AgonyReached.emit(agony_value, time)

func notify_halls_entered(param):
	await get_tree().create_timer(1.0).timeout
	HallsEntered.emit(param, 0)

func notify_gold_collected(gold_amount): GoldCollected.emit(gold_amount, 0)
func notify_boss_kill(boss_name): BossKilled.emit(boss_name, 0)
func notify_lord_kill(boss_name): LordKilled.emit(boss_name, 0)
func notify_elite_killed(elite_name): EliteKilled.emit(elite_name, 0)
