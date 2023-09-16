@tool
extends Node

@export var Icon : Texture
@export var Name : String = ""
@export var ID : String = ""
@export var UnlockedByQuestID : String = ""
@export_multiline var Description : String = ""
@export var ValueFormat : String = "+%1.0f%s"
@export var ValueSuffix : String = "%"
@export var ActivateTagsWhenUnlocked : Array[String] = []

@export var NumberOfLevels : int :
	set(value):
		LevelModifierScenes.resize(value)
		LevelModifierValues.resize(value)
		LevelModifierCosts.resize(value)
		notify_property_list_changed()
	get: return LevelModifierScenes.size()
@export var LevelModifierScenes : Array[PackedScene] = []
@export var LevelModifierValues : Array[float] = []
@export var LevelModifierCosts : Array[int] = []

var _currentUnlockLevel : int = 0

signal blessing_changed

func isUnlocked() -> bool:
	return UnlockedByQuestID == "" or Global.QuestPool.is_quest_complete(UnlockedByQuestID)

func loadBlessingUnlockLevel():
	_currentUnlockLevel = 0
	if Global.PlayerProfile.has("Blessings") && Global.PlayerProfile["Blessings"].has(ID):
		_currentUnlockLevel = Global.PlayerProfile["Blessings"][ID]

func unlockNextLevel() -> bool:
	if _currentUnlockLevel >= LevelModifierScenes.size():
		return false
	if !Global.payGold(LevelModifierCosts[_currentUnlockLevel], false):
		return false
	_currentUnlockLevel += 1
	Global.QuestPool.notify_blessing_purchased(Name, _currentUnlockLevel)
	Global.PlayerProfile["Blessings"][ID] = _currentUnlockLevel
	Global.schedulePlayerProfileSaving()
	blessing_changed.emit()
	return true

func refundOneLevel() -> bool:
	if _currentUnlockLevel == 0: return false
	Global.earnGold(LevelModifierCosts[_currentUnlockLevel - 1], false)
	_currentUnlockLevel -= 1
	Global.PlayerProfile["Blessings"][ID] = _currentUnlockLevel
	Global.schedulePlayerProfileSaving()
	blessing_changed.emit()
	return true

func refund():
	var goldSpent = getGoldSpent()
	if goldSpent > 0:
		Global.earnGold(goldSpent, false)
		_currentUnlockLevel = 0
		Global.PlayerProfile["Blessings"][ID] = _currentUnlockLevel
		blessing_changed.emit()

func getCurrentLevel() -> int:
	return _currentUnlockLevel

func getCurrentUnlockCost() -> int:
	if _currentUnlockLevel >= LevelModifierCosts.size():
		return -1
	return LevelModifierCosts[_currentUnlockLevel]

func getCurrentBonusString() -> String:
	var bonus : float = 0.0
	for i in _currentUnlockLevel:
		bonus += LevelModifierValues[i]
	return ValueFormat % [bonus, ValueSuffix]

func getGoldSpent() -> int:
	var gold_spent : int = 0
	if _currentUnlockLevel > 0:
		for i in range(1, _currentUnlockLevel + 1):
			gold_spent += LevelModifierCosts[i - 1]
	return gold_spent

func applyBlessing(characterGameObject:GameObject) -> void:
	if _currentUnlockLevel <= 0:
		return
	for i in range(_currentUnlockLevel):
		var modifier = LevelModifierScenes[i].instantiate()
		if modifier is EffectBase:
			characterGameObject.add_effect(modifier, null)
		else:
			characterGameObject.add_child(modifier)

	if ActivateTagsWhenUnlocked != null and ActivateTagsWhenUnlocked.size() > 0:
		if not Global.is_world_ready():
			await Global.WorldReady
		Global.World.Tags.setTagsActive(ActivateTagsWhenUnlocked)

