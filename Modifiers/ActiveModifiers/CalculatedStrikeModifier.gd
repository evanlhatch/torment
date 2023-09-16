extends GameObjectComponent2D

@export var AddDamagePercentagePerEntry : float = 0.15
@export var IntervalLength : float = 1.0
@export var ModifierCap : int = 10
@export var ChargeDelay : float = 0.2

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _buff_timer : float
var _reset_delay_timer : Timer

var buff_count : int
var _damageModifier : Modifier

func _enter_tree():
	if _reset_delay_timer == null:
		_reset_delay_timer = Timer.new()
		add_child(_reset_delay_timer)
	initGameObjectComponent()
	if _gameObject:
		buff_count = 0
		_buff_timer = ChargeDelay
		_gameObject.connectToSignal("AttackTriggered", reset_buff)
		_damageModifier = Modifier.create("Damage", _gameObject)
		_damageModifier.setName(Name)
		updateModifier()


func _exit_tree():
	if _gameObject != null && !_gameObject.is_queued_for_deletion():
		reset_buff(0)
		_gameObject.disconnectFromSignal("AttackTriggered", reset_buff)
	_gameObject = null


func _process(delta):
#ifdef PROFILING
#	updateCalculatedStrike(delta)
#
#func updateCalculatedStrike(delta):
#endif
	if _gameObject == null: return
	_buff_timer -= delta
	if _buff_timer <= 0:
		_buff_timer += IntervalLength
		if buff_count < ModifierCap:
			buff_count += 1
			updateModifier()


func reset_buff(_attack_index:int):
	#_reset_delay_timer.start(ResetDelay)
	#await _reset_delay_timer.timeout
	_buff_timer = ChargeDelay
	buff_count = 0
	updateModifier()


func updateModifier():
	var mul_mod : float = AddDamagePercentagePerEntry * float(buff_count)
	_damageModifier.setMultiplierMod(mul_mod)
	_gameObject.triggerModifierUpdated("Damage")
	if mul_mod > 0:
		_mod_value_str = "%s%%" % round(AddDamagePercentagePerEntry * float(buff_count) * 100)
	else:
		_mod_value_str = ""

func get_modifier_count() -> int:
	return int(round(AddDamagePercentagePerEntry * float(buff_count) * 100))

@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export_multiline var TooltipText : String = ""
var _mod_value_str : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_active() -> bool:
	return buff_count > 0

func get_modifierInfoArea_valuestr() -> String:
	return _mod_value_str

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText

func get_modifierInfoArea_name() -> String:
	return Name


func get_modifierInfoArea_cooldownfactor() -> float:
	if buff_count > 0: return 0
	return _buff_timer / ChargeDelay