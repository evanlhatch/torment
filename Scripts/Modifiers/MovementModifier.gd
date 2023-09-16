extends GameObjectComponent

@export var AddSpeed : float = 0
@export var AddSpeedPercent : float = 0.5
@export var AddMass : float = 0
@export var AddMassPercent : float = 2
@export var RemoveAfterTime : float = -1
@export var ModifierCategories : Array[String]

@export var ChangeEveryXLevels : int = 0
@export var ChangeMultiplier : float = 0
@export var ChangeAdditive : float = 0

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _movementSpeedMod : Modifier
var _massMod : Modifier
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

	_movementSpeedMod = Modifier.create("MovementSpeed", _gameObject)
	_movementSpeedMod.setName(Name)
	_movementSpeedMod.setAdditiveMod(AddSpeed)
	_movementSpeedMod.setMultiplierMod(AddSpeedPercent)
	_movementSpeedMod.allowCategories(ModifierCategories)
	_massMod = Modifier.create("Mass", _gameObject)
	_massMod.setName(Name)
	_massMod.setAdditiveMod(AddMass)
	_massMod.setMultiplierMod(AddMassPercent)
	_massMod.allowCategories(ModifierCategories)
	_gameObject.triggerModifierUpdated("MovementSpeed")
	_gameObject.triggerModifierUpdated("Mass")


func on_level_up():
	_remainingLevelsToChange -= 1
	if _remainingLevelsToChange <= 0:
		_remainingLevelsToChange = ChangeEveryXLevels
		_movementSpeedMod.setMultiplierMod(_movementSpeedMod.getMultiplierMod() + ChangeMultiplier)
		_movementSpeedMod.setAdditiveMod(_movementSpeedMod.getAdditiveMod() + ChangeAdditive)
		_gameObject.triggerModifierUpdated("MovementSpeed")

func _exit_tree():
	_movementSpeedMod = null
	_massMod = null
	_gameObject = null

func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()

func set_movement_percent_bonus(movement_bounus:float):
	if not is_instance_valid(_gameObject): return
	AddSpeedPercent = movement_bounus
	_movementSpeedMod.setMultiplierMod(AddSpeedPercent)
	_gameObject.triggerModifierUpdated("MovementSpeed")

