extends Node

@export var SelectableNodePaths : Array[NodePath]

enum InteractionMode {
	Mouse,
	GamepadSelect
}

var selectable_nodes
var neighbor_relations : Dictionary
var current_selection: Node
var current_mode : InteractionMode

func _ready():
	# wait one frame until everything in the scene is at its right place
	await get_tree().process_frame
	selectable_nodes = []
	neighbor_relations = {}
	for p in SelectableNodePaths:
		var node = get_node(p)
		selectable_nodes.append(node)
		neighbor_relations[node] = {
			"left": null,
			"right" : null,
			"top" : null,
			"bottom": null
		}
	for n in selectable_nodes:
		collect_neighbors_for_node(n)
		
	set_interaction_mode(InteractionMode.Mouse)
	get_parent().PlayerCharacterSelected.connect(on_player_character_selected)


func _process(_delta):
	if current_mode == InteractionMode.GamepadSelect:
		if Input.is_action_just_pressed("up"):
			select_node(neighbor_relations[current_selection].top)
		elif Input.is_action_just_pressed("down"):
			select_node(neighbor_relations[current_selection].bottom)
		elif Input.is_action_just_pressed("left"):
			select_node(neighbor_relations[current_selection].left)
		elif Input.is_action_just_pressed("right"):
			select_node(neighbor_relations[current_selection].right)
		# analog input
		if Input.is_action_just_pressed("up_analog"):
			select_node(neighbor_relations[current_selection].top)
		elif Input.is_action_just_pressed("down_analog"):
			select_node(neighbor_relations[current_selection].bottom)
		elif Input.is_action_just_pressed("left_analog"):
			select_node(neighbor_relations[current_selection].left)
		elif Input.is_action_just_pressed("right_analog"):
			select_node(neighbor_relations[current_selection].right)
		
		
		if Input.is_action_just_pressed("confirm"):
			activate_node(current_selection)
	elif (
		current_mode == InteractionMode.Mouse and (
		Input.is_action_just_pressed("up") or Input.is_action_just_pressed("up_analog") or
		Input.is_action_just_pressed("down") or Input.is_action_just_pressed("down_analog") or
		Input.is_action_just_pressed("left") or Input.is_action_just_pressed("left_analog") or
		Input.is_action_just_pressed("right") or Input.is_action_just_pressed("right_analog"))):
		set_interaction_mode(InteractionMode.GamepadSelect)

	if (Input.get_last_mouse_velocity().length_squared() > 64.0 or
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		set_interaction_mode(InteractionMode.Mouse)


func set_interaction_mode(interaction_mode:InteractionMode):
	if interaction_mode == current_mode:
		return
	match(interaction_mode):
		InteractionMode.Mouse:
			current_selection = null
			deselect_all()
		InteractionMode.GamepadSelect:
			if current_selection == null:
				select_node(selectable_nodes[0])
	current_mode = interaction_mode


func select_node(node:Node):
	if node == null or not node.visible: return
	deselect_all()
	var selector = node.getChildNodeWithMethod("_on_mouse_exited")
	if selector != null: selector._on_mouse_entered()
	var hoverText = node.getChildNodeWithSignal("HoverTextEntered")
	if hoverText != null: hoverText.HoverTextEntered.emit(hoverText.HoverText)
	current_selection = node


func deselect_all():
	var hoverTextReset : bool = false
	for n in selectable_nodes:
		var selector = n.getChildNodeWithMethod("_on_mouse_exited")
		if selector != null:
			selector._on_mouse_exited()
		if not hoverTextReset:
			var hoverText = n.getChildNodeWithSignal("HoverTextExited")
			if hoverText != null:
				hoverText.HoverTextExited.emit(hoverText.HoverText)
				hoverTextReset = true


func activate_node(node:Node):
	await get_tree().process_frame
	if node == null or not node.visible: return
	var hoverText = node.getChildNodeWithSignal("HoverTextExited")
	if hoverText != null: hoverText.HoverTextExited.emit(hoverText.HoverText)
	var selectionComponent = node.getChildNodeWithSignal("CharacterSelected")
	if selectionComponent != null:
		selectionComponent.emit_signal("CharacterSelected", node)


func on_player_character_selected():
	# after the first character has been selected, we don't need this input handler any more
	queue_free()


func collect_neighbors_for_node(node:Node):
	var closest_left = 99999999
	var closest_right = 99999999
	var closest_top = 99999999
	var closest_bottom = 99999999
	for n in selectable_nodes:
		if not n.visible or n == node: continue
		
		var dir : Vector2 = (n.global_position - node.global_position)

		#right neighbor
		if (dir.x > 0.0):
			if dir.length_squared() < closest_right:
				neighbor_relations[node].right = n
				closest_right = dir.length_squared()
		# left neighbor
		elif (dir.x < 0.0):
			if dir.length_squared() < closest_left:
				neighbor_relations[node].left = n
				closest_left = dir.length_squared()
		# top neighbor
		elif (dir.y < 0.0) and (absf(dir.y) > absf(dir.x)):
			if dir.length_squared() < closest_top:
				neighbor_relations[node].top = n
				closest_top = dir.length_squared()
		# top neighbor
		elif (dir.y > 0.0) and (absf(dir.y) > absf(dir.x)):
			if dir.length_squared() < closest_bottom:
				neighbor_relations[node].bottom = n
				closest_bottom = dir.length_squared()
