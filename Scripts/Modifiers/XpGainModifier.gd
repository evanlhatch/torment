extends GameObjectComponent

@export var AddXp : int = 0
@export var AddXpPercent : float = 0.10
@export var RemoveAfterTime : float = -1

@export var ChangeEveryXLevels : int = 0
@export var OnlyForNewLevels : bool = true
@export var ChangeMultiplier : float = 0
@export var ChangeAdditive : float = 0

@export var MinLevelMultiplier : float = 0

var _remainingLevelsToChange : int = 0

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _xpGainModifier : Modifier

func _enter_tree():
	initGameObjectComponent()

	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	process_mode = PROCESS_MODE_INHERIT if RemoveAfterTime > 0 or get_child_count() > 0 else PROCESS_MODE_DISABLED
	
	_xpGainModifier = Modifier.create("XpGain", _gameObject)
	_xpGainModifier.setName(Name)
	_xpGainModifier.setAdditiveMod(AddXp)
	_xpGainModifier.setMultiplierMod(AddXpPercent)

	if ChangeEveryXLevels > 0:
		await Global.awaitWorldReady()
		Global.World.ExperienceThresholdReached.connect(on_level_up)
		_remainingLevelsToChange = ChangeEveryXLevels
		if not OnlyForNewLevels:
			_xpGainModifier.setMultiplierMod(maxf(MinLevelMultiplier, AddXpPercent + Global.World.Level * ChangeMultiplier / ChangeEveryXLevels))
			_xpGainModifier.setAdditiveMod(AddXp + Global.World.Level * ChangeAdditive / ChangeEveryXLevels)
	
	_gameObject.triggerModifierUpdated("XpGain")


func on_level_up(trigger_update : bool = true):
	_remainingLevelsToChange -= 1
	if _remainingLevelsToChange <= 0:
		_remainingLevelsToChange = ChangeEveryXLevels
		_xpGainModifier.setMultiplierMod(maxf(MinLevelMultiplier, _xpGainModifier.getMultiplierMod() + ChangeMultiplier))
		_xpGainModifier.setAdditiveMod(_xpGainModifier.getAdditiveMod() + ChangeAdditive)
		_gameObject.triggerModifierUpdated("XpGain")
	
func _exit_tree():
	_xpGainModifier = null
	_gameObject = null

func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()
