extends Node

@export var Icon : Texture
@export var Name : String
@export var ID : String
@export var QuestBoard : QuestPool.QuestBoardEnum
@export var IsHidden : bool
@export var RewardInSameRun : bool = false
@export_multiline var Description : String
@export var RequiredCharacter : QuestPool.CharacterEnum
@export var RequiredWorld : QuestPool.WorldEnum

## This is only a string used to display what this quest unlocks.
@export var Unlocks : String = ""
@export var GoldReward : int = 0

@export_group("Count Settings")
@export var CompletionCount : int
@export var CountIsPersistent : bool = false
@export var CountOnSignal : String

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
# -- 6: Add When Two Params: The quest assumes the first parameter is a number.
#		When both conditions are true, add the first variable to the total count.
@export_enum("Signal Emit Count", "Signal Param", "Signal Param Field", "String Param Condition", "Count When Two Params", "Count Node in Group", "Add When Two Params", "Set To Signal Param") var ParameterMode : int
@export var ParamFieldName : String = ""
@export var AvoidTime : int = 0

@export_group("Count Settings - Two Parameters")
@export_enum("==", ">=", ">", "<=", "<", "!=") var Param1CheckType : int = 0
@export var Param1Check : float
@export_enum("==", ">=", ">", "<=", "<", "!=") var Param2CheckType : int = 0
@export var Param2Check : int

@export_group("Board Settings")
@export var Row : int
@export var Column : int

signal QuestProgressed(quest)
signal QuestCompleted(quest)
signal QuestHiddenStateChanged(quest)

var _count : int
var _avoid_fail_count : int = 0
var _character_check : QuestPool.CharacterEnum
var _world_check : QuestPool.WorldEnum

func _ready():
	await Global.awaitInitialization()

	Global.connect("WorldReady", _on_world_ready)
	if is_completed(): return
	Global.QuestPool.connect(CountOnSignal, _on_count_signal)
	if AvoidTime > 0:
		Global.QuestPool.connect("MinutePassed", _on_avoid_progress)

func _on_world_ready():
	if ID and is_completed():
		# every quest simply activates its ID as a tag!
		Global.World.Tags.setTagActive(ID)

	if is_completed(): return
	if not CountIsPersistent: _count = 0
	_avoid_fail_count = 0

	_world_check = Global.World.WorldIdentifier
	if Global.World.Player != null and not Global.World.Player.is_queued_for_deletion():
		match(Global.World.Player.name):
			"Swordsman": _character_check = QuestPool.CharacterEnum.SWORDSMAN
			"Archer": _character_check = QuestPool.CharacterEnum.ARCHER
			"Exterminator": _character_check = QuestPool.CharacterEnum.EXTERMINATOR
			"ShieldMaiden": _character_check = QuestPool.CharacterEnum.SHIELDMAIDEN
			"Cleric": _character_check = QuestPool.CharacterEnum.CLERIC
			"Warlock": _character_check = QuestPool.CharacterEnum.WARLOCK
			"Sorceress": _character_check = QuestPool.CharacterEnum.SORCERESS
			"Norseman": _character_check = QuestPool.CharacterEnum.NORSEMAN
			"BeastHuntress": _character_check = QuestPool.CharacterEnum.BEASTHUNTRESS
			_: _character_check = QuestPool.CharacterEnum.ANY


func is_completed():
	if AvoidTime > 0: return _count >= AvoidTime
	return _count >= CompletionCount


func _on_count_signal(parameter1, parameter2):
	if is_completed(): return
	if _avoid_fail_count >= CompletionCount: return
	if not Global.QuestPool.is_quest_board_available(QuestBoard): return

	if (RequiredWorld != QuestPool.WorldEnum.ANY and
		RequiredWorld != _world_check):
		return

	if (RequiredCharacter != QuestPool.CharacterEnum.ANY and
		RequiredCharacter != _character_check):
		return

	var count_before = _count
	var _change = 0
	match(ParameterMode):
		0: _change += 1
		1: _change += parameter1
		2:
			if parameter1.has(ParamFieldName):
				_change += parameter1[ParamFieldName]
		3:
			if parameter1 == ParamFieldName:
				_change += 1
		4:
			var check1 : bool = false
			var check2 : bool = false
			if typeof(parameter1) == TYPE_INT or typeof(parameter1) == TYPE_FLOAT:
				match(Param1CheckType):
					0: check1 = parameter1 == Param1Check
					1: check1 = parameter1 >= Param1Check
					2: check1 = parameter1 > Param1Check
					3: check1 = parameter1 <= Param1Check
					4: check1 = parameter1 < Param1Check
					5: check1 = parameter1 != Param1Check
			elif typeof(parameter1) == TYPE_STRING:
				if ParamFieldName == null or ParamFieldName == "" or parameter1 == ParamFieldName:
					check1 = true
			else:
				check1 = true
			match(Param2CheckType):
				0: check2 = parameter2 == Param2Check
				1: check2 = parameter2 >= Param2Check
				2: check2 = parameter2 > Param2Check
				3: check2 = parameter2 <= Param2Check
				4: check2 = parameter2 < Param2Check
				5: check2 = parameter2 != Param2Check
			if check1 and check2: _change += 1
		5:
			if parameter1.is_in_group(ParamFieldName):
				_change += 1
		6:
			var check1 : bool = false
			var check2 : bool = false
			if typeof(parameter1) == TYPE_INT or typeof(parameter1) == TYPE_FLOAT:
				match(Param1CheckType):
					0: check1 = parameter1 == Param1Check
					1: check1 = parameter1 >= Param1Check
					2: check1 = parameter1 > Param1Check
					3: check1 = parameter1 <= Param1Check
					4: check1 = parameter1 < Param1Check
					5: check1 = parameter1 != Param1Check
			else: return
			match(Param2CheckType):
				0: check2 = parameter2 == Param2Check
				1: check2 = parameter2 >= Param2Check
				2: check2 = parameter2 > Param2Check
				3: check2 = parameter2 <= Param2Check
				4: check2 = parameter2 < Param2Check
				5: check2 = parameter2 != Param2Check
			if check1 and check2: _change += parameter1
		7:
			if AvoidTime > 0:
				_avoid_fail_count += parameter1
				return
			else:
				_count = parameter1
				QuestProgressed.emit(self)
				if _count >= CompletionCount: QuestCompleted.emit(self, true)

	if _change == 0: return
	if AvoidTime > 0:
		_avoid_fail_count += _change
		return
	_count += _change
	QuestProgressed.emit(self)
	if _count >= CompletionCount: QuestCompleted.emit(self, true)


func _on_avoid_progress(_minute:int, _param):
	if is_completed(): return
	if not Global.QuestPool.is_quest_board_available(QuestBoard): return

	if (RequiredWorld != QuestPool.WorldEnum.ANY and
		RequiredWorld != _world_check):
		return

	if (RequiredCharacter != QuestPool.CharacterEnum.ANY and
		RequiredCharacter != _character_check):
		return
	if _avoid_fail_count >= CompletionCount: return
	_count += 1
	QuestProgressed.emit(self)
	if _count >= AvoidTime: QuestCompleted.emit(self, true)



func set_data(quest_data):
	if quest_data["ID"] != ID: return
	if CountIsPersistent:
		_count = quest_data["count"]
	if quest_data["completed"]:
		if AvoidTime > 0:
			_count = AvoidTime
		else:
			_count = CompletionCount
	IsHidden = quest_data["hidden"]


func set_hidden(hidden:bool):
	IsHidden = hidden
	QuestHiddenStateChanged.emit(self)
