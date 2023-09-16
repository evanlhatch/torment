extends GameObjectComponent

@export var Ray : RayCast2D
@export var ExcludedArea : Node

var selected_object : Node
var velocity_provider : Node
var _is_in_player_control : bool
var _mouse_movement_block_timer : float

func _ready():
	initGameObjectComponent()
	_is_in_player_control = false
	_gameObject.connectToSignal("PlayerControlChanged", _on_player_control_changed)
	velocity_provider = _gameObject.getChildNodeWithMethod("get_targetVelocity")
	Ray.add_exception(ExcludedArea)

func _process(delta):
	if (GameState.CurrentState != GameState.States.Overworld or
		not _is_in_player_control):
		return
	
	# ignore any input if the mouse is moving
	if Input.get_last_mouse_velocity().length_squared() > 16.0:
		_mouse_movement_block_timer = 0.5
	if _mouse_movement_block_timer >= 0.0:
		_mouse_movement_block_timer -= delta
		if selected_object != null:
			selected_object.emit_signal("mouse_exited")
			selected_object = null
		return
	
	# update ray direction
	var velocity =  velocity_provider.get_targetVelocity()
	if velocity.length_squared() > 0.1:
		Ray.target_position = velocity.normalized() * 48.0

	if Ray.is_colliding():
		var hit_object = Ray.get_collider()
		if hit_object != selected_object:
			if selected_object != null:
				selected_object.emit_signal("mouse_exited")
			selected_object = hit_object
			selected_object.emit_signal("mouse_entered")
		if Input.is_action_just_pressed("confirm"):
			handle_confirm(hit_object)

	elif selected_object != null:
		selected_object.emit_signal("mouse_exited")
		selected_object = null

func _on_player_control_changed(is_in_player_control:bool):
	_is_in_player_control = is_in_player_control
	if selected_object != null:
		selected_object.emit_signal("mouse_exited")
		selected_object = null

func handle_confirm(hit_object:Node):
	await get_tree().process_frame
	var siblings = hit_object.get_parent().get_children()
	var menu_selection = null
	for s in siblings:
		if s.has_method("select_menu"):
			menu_selection = s
			break
	if menu_selection != null:
		selected_object.emit_signal("mouse_exited")
		selected_object = null
		menu_selection.select_menu()
	else:
		var hit_gameObject = Global.get_gameObject_in_parents(hit_object)
		if hit_gameObject != null:
			var selectionComponent = hit_gameObject.getChildNodeWithSignal("CharacterSelected")
			if selectionComponent != null:
				selectionComponent.emit_signal("CharacterSelected", hit_gameObject)
