extends GameObjectComponent

@export var AddValue : int = 0
@export var AddValuePercent : float = 0.0
@export var RemoveAfterTime : float = -1

@export var ChangeEveryXLevels : int = 0
@export var ChangeMultiplier : float = 0
@export var ChangeAdditive : float = 0

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _blockChanceModifier : Modifier
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
	
	_blockChanceModifier = Modifier.create("BlockValue", _gameObject)
	_blockChanceModifier.setName(Name)
	_blockChanceModifier.setAdditiveMod(AddValue)
	_blockChanceModifier.setMultiplierMod(AddValuePercent)
	_gameObject.triggerModifierUpdated("BlockValue")


func on_level_up():
	_remainingLevelsToChange -= 1
	if _remainingLevelsToChange <= 0:
		_remainingLevelsToChange = ChangeEveryXLevels
		_blockChanceModifier.setMultiplierMod(_blockChanceModifier.getMultiplierMod() + ChangeMultiplier)
		_blockChanceModifier.setAdditiveMod(_blockChanceModifier.getAdditiveMod() + ChangeAdditive)
		_gameObject.triggerModifierUpdated("BlockValue")

func _exit_tree():
	_blockChanceModifier = null
	_gameObject = null

func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()
