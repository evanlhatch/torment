extends GameObjectComponent2D

@export var AddDamagePerEntry : float = 0.05
@export var IntervalLength : float = 1.0
@export var ModifierCap : float = 0.5
@export var MovementThreshold : float = 8.0

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _previousPosition : Vector2
var _distanceMoved : float
var _buff_timer : float

var previous_buff_count : int
var buff_count : int
var damageMod : Modifier

func _enter_tree():
	initGameObjectComponent()
	if _gameObject:
		_previousPosition = _positionProvider.get_worldPosition()
		damageMod = Modifier.create("Damage", _gameObject)
		damageMod.setName(Name)
		updateModifier()


func _exit_tree():
	if _gameObject != null && !_gameObject.is_queued_for_deletion():
		_positionProvider = null
	_gameObject = null


func _process(delta):
#ifdef PROFILING
#	updateAimingStance(delta)
#
#func updateAimingStance(delta):
#endif
	if _gameObject == null or _positionProvider == null: return
	
	_buff_timer += delta
	if _buff_timer >= IntervalLength:
		_buff_timer -= IntervalLength
		buff_count = clamp(buff_count + 1, 0, Global.MAX_VALUE)
		updateModifier()
		previous_buff_count = buff_count
	
	var new_position = _positionProvider.get_worldPosition()
	_distanceMoved += _previousPosition.distance_to(new_position)
	if _distanceMoved >= MovementThreshold:
		_buff_timer = 0.0
		_distanceMoved = 0.0
		reset_buff()
	_previousPosition = new_position


func reset_buff():
	buff_count = 0
	if previous_buff_count != buff_count:
		previous_buff_count = buff_count
		updateModifier()


func updateModifier():
	var multMod : float = clamp(AddDamagePerEntry * float(buff_count), 0.0, ModifierCap)
	damageMod.setMultiplierMod(multMod)
	_gameObject.triggerModifierUpdated("Damage")
	ModInfoStr = str(ceili(multMod * 100.0)) + "%"

func get_modifier_count() -> int:
	return int(ceil(damageMod.getMultiplierMod() * 100.0))

@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export_multiline var TooltipText : String = ""
var ModInfoStr : String = "0"

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_active() -> bool:
	return buff_count > 0

func get_modifierInfoArea_valuestr() -> String:
	return ModInfoStr

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText

func get_modifierInfoArea_name() -> String:
	return Name

