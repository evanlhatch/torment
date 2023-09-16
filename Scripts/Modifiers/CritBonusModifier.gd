extends GameObjectComponent

@export var AddCritBonus : float = 20
@export var AddCritBonusPercent : float = 0.0
@export var RemoveAfterTime : float = -1

@export var ChangeEveryXLevels : int = 0
@export var ChangeMultiplier : float = 0
@export var ChangeAdditive : float = 0
@export var ModifierCategories : Array[String]

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _critBonusModifier : Modifier
var _remainingLevelsToChange : int = 0

func _enter_tree():
	initGameObjectComponent()

	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	process_mode = PROCESS_MODE_INHERIT if RemoveAfterTime > 0 or get_child_count() > 0 else PROCESS_MODE_DISABLED

	if ChangeEveryXLevels > 0:
		await Global.awaitWorldReady()
		Global.World.ExperienceThresholdReached.connect(on_level_up)
		_remainingLevelsToChange = ChangeEveryXLevels
	
	_critBonusModifier = Modifier.create("CritBonus", _gameObject)
	_critBonusModifier.setName(Name)
	_critBonusModifier.setAdditiveMod(AddCritBonus)
	_critBonusModifier.setMultiplierMod(AddCritBonusPercent)
	_critBonusModifier.allowCategories(ModifierCategories)
	_gameObject.triggerModifierUpdated("CritBonus")


func on_level_up():
	_remainingLevelsToChange -= 1
	if _remainingLevelsToChange <= 0:
		_remainingLevelsToChange = ChangeEveryXLevels
		_critBonusModifier.setMultiplierMod(_critBonusModifier.getMultiplierMod() + ChangeMultiplier)
		_critBonusModifier.setAdditiveMod(_critBonusModifier.getAdditiveMod() + ChangeAdditive)
		_gameObject.triggerModifierUpdated("CritBonus")

func _exit_tree():
	_critBonusModifier = null
	_gameObject = null

func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()
