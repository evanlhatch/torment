extends GameObjectComponent


@export var InputDeadZone : float = 0.15
@export var MouseMoveThreshold :  float = 32.0

var input_direction : Vector2
signal input_dir_changed(dir_vector:Vector2)
var targetDirectionSetter : Node
var _bulletEmitter = []
var autoEmitToggle : bool

var stick_aim_input_dir : Vector2
var last_non_zero_aim_input : Vector2
var mouse_aim : bool = false
var current_mouse_aim_dir : Vector2
var auto_aim : bool = false
var override_auto_aim : bool = false
var auto_aim_input_dir : Vector2
var range_provider : Node
var mouse_only_mode : bool = false
var hold_only_movement_mode : bool = false

signal AutoAimChanged(autoAim:bool)
signal AutoAttackChanged(autoAttack:bool)

func _ready():
	connectToNewParentGameObject()
	mouse_only_mode = Global.CurrentSettings["mouse_only"]
	hold_only_movement_mode = Global.CurrentSettings["hold_only"]
	Global.MouseMovementChanged.connect(_on_mouse_movement_changed)
	print("--------- CONNECTED CONTROLLERS -----------")
	for jp in Input.get_connected_joypads():
		print("%d: %s" % [jp, Input.get_joy_name(jp)])
	print("-------------------------------------------")

func connectToNewParentGameObject():
	if _gameObject:
		# disconnect old first
		_gameObject.disconnectFromSignal("Killed", onDeath)
		_bulletEmitter.clear()
	# get new parent gameObject and get all the stuff
	initGameObjectComponent()
	if !_gameObject:
		return
	
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	_gameObject.getChildNodesWithMethod("set_emitting", _bulletEmitter)
	_gameObject.connectToSignal("Killed", onDeath)
	range_provider = _gameObject.getChildNodeWithMethod("get_totalRange")

func onDeath(_killedBy:Node):
	targetDirectionSetter.set_targetDirection(Vector2.ZERO)
	for emitter in _bulletEmitter:
		emitter.set_emitting(false)
	set_process(false)

func _on_mouse_movement_changed(mouse_move_only:bool, hold_move_only:bool):
	mouse_only_mode = mouse_move_only
	hold_only_movement_mode = hold_move_only

func _input(event):
	if event is InputEventMouseMotion:
		if event.velocity.length_squared() > MouseMoveThreshold:
			mouse_aim = true

# Mouse clicks for attack input must be handled separately or else
# clicks on buttons and UI elements will be treated as as attack actions.
# This happens mainly when the player clicks on the Menu button during a run.
var mouse_button_down:bool
func _unhandled_input(event):
	if event is InputEventMouseButton and not mouse_only_mode:
		if event.pressed and not mouse_button_down:
			for emitter in _bulletEmitter:
				emitter.set_emitting(true)
		elif not event.pressed and mouse_button_down:
			for emitter in _bulletEmitter:
				emitter.set_emitting(autoEmitToggle)
		mouse_button_down = event.pressed
	
	if event is InputEventMouseButton and mouse_only_mode and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_button_down = event.pressed
		if hold_only_movement_mode and targetDirectionSetter != null and not event.pressed:
			targetDirectionSetter.set_targetDirection(Vector2.ZERO)


func _process(_delta):
	if !_gameObject: return
	if (GameState.CurrentState != GameState.States.Overworld and
		GameState.CurrentState != GameState.States.InGame):
		if input_direction.length() >= 0.1:
			input_direction = Vector2.ZERO
			emit_signal("input_dir_changed", input_direction)
			targetDirectionSetter.set_targetDirection(input_direction)
		return
	
	var new_input_dir = Vector2.ZERO
	new_input_dir += Input.get_vector("left", "right", "up", "down", InputDeadZone)
	# Workaround:
	# treat analog gamepad input as fallback, so PS4 gamepads don't interfere with keyboard input.
	if new_input_dir == Vector2.ZERO:
		new_input_dir += Input.get_vector("left_analog", "right_analog", "up_analog", "down_analog", InputDeadZone)
	
	if new_input_dir.length() < InputDeadZone:
		new_input_dir = Vector2.ZERO
	elif mouse_only_mode:
		# pressing movement keys should cancel the current mouse movement...
		if targetDirectionSetter != null and _positionProvider != null:
			if hold_only_movement_mode and mouse_button_down:
				targetDirectionSetter.set_targetDirection(Vector2.ZERO)
			else:
				targetDirectionSetter.set_targetWorldPos(Vector2.ZERO)
		mouse_button_down = false
	
	new_input_dir = new_input_dir.normalized()
	if new_input_dir != input_direction:
		input_direction = new_input_dir
		emit_signal("input_dir_changed", input_direction)
		targetDirectionSetter.set_targetDirection(input_direction)

	if not get_tree().paused:
		if mouse_only_mode and mouse_button_down:
			if targetDirectionSetter != null and _positionProvider != null:
				if hold_only_movement_mode:
					targetDirectionSetter.set_targetDirection((_positionProvider.get_global_mouse_position() - _positionProvider.get_worldPosition()).normalized())
				else:
					targetDirectionSetter.set_targetWorldPos(_positionProvider.get_global_mouse_position())
		
		if Input.is_action_just_pressed("AutoFire") and not mouse_only_mode:
			autoEmitToggle = not autoEmitToggle
			AutoAttackChanged.emit(autoEmitToggle)
			for emitter in _bulletEmitter:
				emitter.set_emitting(autoEmitToggle)
		elif Input.is_action_just_pressed("MouseOnly_AutoFire") and mouse_only_mode:
			autoEmitToggle = not autoEmitToggle
			AutoAttackChanged.emit(autoEmitToggle)
			if mouse_button_down:
				for emitter in _bulletEmitter:
					emitter.set_emitting(autoEmitToggle)
		
		if Input.is_action_just_pressed("AutoAim") and not mouse_only_mode:
			auto_aim = not auto_aim
			AutoAimChanged.emit(auto_aim)
			#if not auto_aim:
			#	autoEmitToggle = false
			#	AutoAttackChanged.emit(autoEmitToggle)
			#	for emitter in _bulletEmitter: emitter.set_emitting(false)
		
		handle_aiming()
		if auto_aim:
			if not override_auto_aim: handle_auto_aim()
			else:
				if check_fire_input(1):
					for emitter in _bulletEmitter: emitter.set_emitting(true)
				elif check_fire_input(3) and not check_fire_input(2):
					for emitter in _bulletEmitter: emitter.set_emitting(autoEmitToggle)
	
		else:
			if check_fire_input(1):
				for emitter in _bulletEmitter: emitter.set_emitting(not autoEmitToggle)
			elif check_fire_input(3) and not check_fire_input(2):
				for emitter in _bulletEmitter: emitter.set_emitting(autoEmitToggle)


func check_fire_input(check_type:int) -> bool:
	
	if not mouse_only_mode:
		match(check_type):
			1: return Input.is_action_just_pressed("Fire") or Input.is_action_just_pressed("fire_up") or Input.is_action_just_pressed("fire_down") or Input.is_action_just_pressed("fire_left") or Input.is_action_just_pressed("fire_right")
			2: return Input.is_action_pressed("Fire") or Input.is_action_pressed("fire_up") or Input.is_action_pressed("fire_down") or Input.is_action_pressed("fire_left") or Input.is_action_pressed("fire_right")
			3: return Input.is_action_just_released("Fire") or Input.is_action_just_released("fire_up") or Input.is_action_just_released("fire_down") or Input.is_action_just_released("fire_left") or Input.is_action_just_released("fire_right")
	else:
		match(check_type):
			1: return Input.is_action_just_pressed("MouseOnly_Fire")
			2: return Input.is_action_pressed("MouseOnly_Fire")
			3: return Input.is_action_just_released("MouseOnly_Fire")
	return false


func handle_aiming():
	override_auto_aim = false
	var aim_input_dir = Vector2.ZERO
	aim_input_dir += Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", InputDeadZone)
	if aim_input_dir.length() >= InputDeadZone:
		stick_aim_input_dir = aim_input_dir.normalized()
		override_auto_aim = true
		mouse_aim = false
	else:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not mouse_only_mode: override_auto_aim = true
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and mouse_only_mode: override_auto_aim = true
		current_mouse_aim_dir = (_positionProvider.get_global_mouse_position() - _positionProvider.get_worldPosition()).normalized()


func handle_auto_aim():
	if not Global.is_world_ready():
		return
	var maxRange : float = 500
	if range_provider != null:
		maxRange = float(range_provider.get_totalRange())

	# breakables are broken quickly and can be very important, so they will be checked first
	var breakableHits := Global.World.Locators.get_gameobjects_in_circle(
		"Breakables", get_gameobjectWorldPosition(), minf(100, maxRange))
	
	if breakableHits.size() > 0:
		var otherPositionProvider = breakableHits[0].getChildNodeWithMethod("get_worldPosition")
		var otherPosition : Vector2 = otherPositionProvider.get_worldPosition()
		var dirToOtherPosition : Vector2 = otherPosition - get_gameobjectWorldPosition()
		auto_aim_input_dir = dirToOtherPosition.normalized()
		for emitter in _bulletEmitter:
			emitter.set_emitting(autoEmitToggle)
		return

	var checkRadius : float = 100
	while true:
		if checkRadius+100 > maxRange: checkRadius = maxRange
		
		var hits := Global.World.Locators.get_gameobjects_in_circle(
			"Enemies", get_gameobjectWorldPosition(), checkRadius)
			
		var closest_distance_sq : float = 99999999
		for hitGO in hits:
			var otherPositionProvider = hitGO.getChildNodeWithMethod("get_worldPosition")
			if otherPositionProvider == null:
				continue
			var otherPosition : Vector2 = otherPositionProvider.get_worldPosition()
			var dirToOtherPosition : Vector2 = otherPosition - get_gameobjectWorldPosition()
			var distToOtherPositionSq = dirToOtherPosition.length_squared()
			if distToOtherPositionSq < closest_distance_sq:
				auto_aim_input_dir = dirToOtherPosition.normalized()
				closest_distance_sq = distToOtherPositionSq
		if closest_distance_sq < 99999999:
			for emitter in _bulletEmitter:
				emitter.set_emitting(autoEmitToggle)
			return

		checkRadius += 100
		if checkRadius > maxRange:
			for emitter in _bulletEmitter:
				emitter.set_emitting(Input.is_action_pressed("Fire") or autoEmitToggle)
			break


func get_inputWalkDir() -> Vector2:
	return input_direction

func get_aimDirection() -> Vector2:
	if auto_aim and not override_auto_aim:
		if auto_aim_input_dir.length_squared() == 0: return Vector2.DOWN
		return auto_aim_input_dir
	if not mouse_aim:
		if stick_aim_input_dir.length_squared() == 0: return Vector2.DOWN
		return stick_aim_input_dir
	elif _positionProvider:
		return current_mouse_aim_dir
	if input_direction.length_squared() == 0: return Vector2.DOWN
	return input_direction

func get_facingDirection() -> Vector2:
	return get_aimDirection()
