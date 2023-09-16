extends GameObjectComponent

@export var AddDefense : int = 0
@export var AddDefensePercent : float = 0.5
@export var RemoveAfterTime : float = -1

@export var ChangeEveryXLevels : int = 0
@export var ChangeMultiplier : float = 0
@export var ChangeAdditive : float = 0

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _defenseModifier : Modifier
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

	_defenseModifier = Modifier.create("Defense", _gameObject)
	_defenseModifier.setName(Name)
	_defenseModifier.setAdditiveMod(AddDefense)
	_defenseModifier.setMultiplierMod(AddDefensePercent)
	_gameObject.triggerModifierUpdated("Defense")


func on_level_up():
	_remainingLevelsToChange -= 1
	if _remainingLevelsToChange <= 0:
		_remainingLevelsToChange = ChangeEveryXLevels
		_defenseModifier.setMultiplierMod(_defenseModifier.getMultiplierMod() + ChangeMultiplier)
		_defenseModifier.setAdditiveMod(_defenseModifier.getAdditiveMod() + ChangeAdditive)
		_gameObject.triggerModifierUpdated("HealthRDefenseegen")

func _exit_tree():
	_defenseModifier = null
	_gameObject = null


func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()
