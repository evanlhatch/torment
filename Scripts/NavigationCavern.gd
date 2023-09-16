@tool
extends Node2D

class_name NavigationCavern

@export var Radius : float = 10 :
	set(value):
		if value != Radius:
			Radius = value
			queue_redraw()
@export var Connections : Array[NavigationCavernConnection] :
	set(value):
		Connections = value
		for connection in Connections:
			if connection == null:
				continue
			if connection.changed.is_connected(connectionsChanged):
				continue
			connection.changed.connect(connectionsChanged)
		connectionsChanged()
		queue_redraw()


var _editorLastFramePosition : Vector2
var _editorConnectionsInitialized : bool = false

var _boundingRadius : float
var _wrap_width : float
var _wrap_height : float

func get_class_name() -> String:
	return "NavigationCavern"

func _ready():
	if Engine.is_editor_hint():
		return

	process_mode = Node.PROCESS_MODE_DISABLED
	var parent : Node = get_parent()
	while parent != null:
		if "PatchWidth" in parent:
			_wrap_width = float(parent.PatchWidth)
			_wrap_height = float(parent.PatchHeight)
			break
		parent = parent.get_parent()
	var max_corridor_length : float
	for connection in Connections:
		if not connection.ToCavernRuntimeNode == null:
			printerr("Double connection resource in %s detected! Path: %s" % [get_path(), connection.ToCavern])
		connection.ToCavernRuntimeNode = get_node(connection.ToCavern)
		var wrapped_target_position : Vector2 = connection.ToCavernRuntimeNode.global_position
		var myPosDebug : Vector2 = global_position
		if global_position.x - wrapped_target_position.x < -_wrap_width/2:
			wrapped_target_position.x -= _wrap_width * 2
		elif global_position.x - wrapped_target_position.x > _wrap_width/2:
			wrapped_target_position.x += _wrap_width * 2
		if global_position.y - wrapped_target_position.y < -_wrap_height/2:
			wrapped_target_position.y -= _wrap_height * 2
		elif global_position.y - wrapped_target_position.y > _wrap_height/2:
			wrapped_target_position.y += _wrap_height * 2
		var dir : Vector2 = wrapped_target_position - global_position
		var dist : float = dir.length()
		dir /= dist
		var corridor_length : float = dist - Radius - connection.ToCavernRuntimeNode.Radius

		connection.RuntimeCorridorStartOffset = dir * Radius
		connection.RuntimeCorridorDir = dir
		connection.RuntimeCorridorLine = dir * (corridor_length / 2.0)
		max_corridor_length = maxf(max_corridor_length, corridor_length)
	_boundingRadius = Radius + max_corridor_length / 2.0


func connectionsChanged():
	if not is_inside_tree():
		return
	var nodes_to_check : Array[Node] = get_tree().edited_scene_root.get_children()

	# first check for problematic connections!
	var connections_hashset : Dictionary
	for connection in Connections:
		if connection == null or connection.ToCavern.is_empty():
			continue
		var connected_node : NavigationCavern = get_node(connection.ToCavern)
		if connected_node == self:
			printerr("Can't connect NavigationCavern to itself!!")
			connection.ToCavern = NodePath()
			return
		if connections_hashset.has(connected_node):
			printerr("Can't connect to a NavigationCavern multiple times!!")
			connection.ToCavern = NodePath()
			return
		connections_hashset[connected_node] = true

	var check_index : int = 0
	while check_index < nodes_to_check.size():
		var checknode : Node = nodes_to_check[check_index]
		if checknode != self and checknode.has_method("get_class_name") and checknode.get_class_name() == "NavigationCavern":
			var shouldConnectionExist : bool = false
			var connectionWidth : float
			for connection in Connections:
				if connection == null:
					continue
				if not connection.ToCavern.is_empty() and get_node(connection.ToCavern) == checknode:
					shouldConnectionExist = true
					connectionWidth = connection.CorridorWidth
					break
			for otherConnection in checknode.Connections:
				if otherConnection == null:
					continue
				if not otherConnection.ToCavern.is_empty() and checknode.get_node(otherConnection.ToCavern) == self:
					if shouldConnectionExist:
						if otherConnection.CorridorWidth != connectionWidth:
							otherConnection.CorridorWidth = connectionWidth
						shouldConnectionExist = false
					else:
						checknode.Connections.erase(otherConnection)
					break
			if shouldConnectionExist:
				var newconnection : NavigationCavernConnection = NavigationCavernConnection.new()
				newconnection.CorridorWidth = connectionWidth
				newconnection.ToCavern = checknode.get_path_to(self)
				newconnection.changed.connect(checknode.connectionsChanged)
				checknode.Connections.append(newconnection)
		nodes_to_check.append_array(checknode.get_children())
		check_index += 1
	queue_redraw()


func _draw():
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, Radius, Color(0.541176, 0.168627, 0.886275, 0.5))
		for connection in Connections:
			if connection == null:
				continue
			if connection.ToCavern.is_empty():
				continue
			var other_cavern : NavigationCavern = get_node(connection.ToCavern)
			var connection_dir : Vector2 = other_cavern.global_position - global_position
			var center_dist : float = connection_dir.length()
			connection_dir /= center_dist
			var linelength : float = (center_dist - Radius - other_cavern.Radius) / 2.0
			if linelength < 400:
				draw_line(connection_dir * Radius, connection_dir * (Radius + linelength), Color(0.168627, 0.541176, 0.886275, 0.5), connection.CorridorWidth)


func _process(delta):
	if Engine.is_editor_hint():
		if _editorLastFramePosition != global_position:
			queue_redraw()
			for connection in Connections:
				if connection == null:
					continue
				if connection.ToCavern.is_empty():
					continue
				get_node(connection.ToCavern).queue_redraw()
		_editorLastFramePosition = global_position
		if not _editorConnectionsInitialized:
			for connection in Connections:
				if connection.changed.is_connected(connectionsChanged):
					continue
				connection.changed.connect(connectionsChanged)
			_editorConnectionsInitialized = true


func is_in_bounding_sphere(global_point:Vector2) -> bool:
	return Geometry2D.is_point_in_circle(global_point, global_position, _boundingRadius)

func is_inside_cavern(global_point:Vector2) -> bool:
	return Geometry2D.is_point_in_circle(global_point, global_position, Radius)

func get_inside_corridor(global_point:Vector2) -> NavigationCavernConnection:
	var local_point: Vector2 = global_point - global_position
	for connection in Connections:
		# this is pretty much Geometry2D.get_closest_point_to_segment, but we don't want ANY result
		# when the point is in front of or behind the segment!
		var paramT : float = connection.RuntimeCorridorLine.dot(
			local_point - connection.RuntimeCorridorStartOffset) / connection.RuntimeCorridorLine.length_squared()
		if paramT < 0 or paramT > 1:
			continue
		var nearest_point_to_corridor_line : Vector2 = connection.RuntimeCorridorStartOffset + paramT * connection.RuntimeCorridorLine
		if nearest_point_to_corridor_line.distance_squared_to(local_point) > (connection.CorridorWidth / 2.0) * (connection.CorridorWidth / 2.0):
			continue
		return connection
	return null

func get_connection_to_cavern(cavern:NavigationCavern) -> NavigationCavernConnection:
	for connection in Connections:
		if connection.ToCavernRuntimeNode == cavern:
			return connection
	return null

func get_distanceSQ_to_center_wrapped(world_pos:Vector2) -> float:
	var ownPosWrapped : Vector2 = Vector2(fposmod(global_position.x, _wrap_width), fposmod(global_position.y, _wrap_height))
	world_pos.x = fposmod(world_pos.x, _wrap_width)
	world_pos.y = fposmod(world_pos.y, _wrap_width)
	return ownPosWrapped.distance_squared_to(world_pos)

func get_unwrapped_center(world_pos:Vector2) -> Vector2:
	var world_pos_wrapped : Vector2 = Vector2(fposmod(world_pos.x, _wrap_width), fposmod(world_pos.y, _wrap_height))
	var wrapping_offset : Vector2 = world_pos - world_pos_wrapped
	var ownPosWrapped : Vector2 = Vector2(fposmod(global_position.x, _wrap_width), fposmod(global_position.y, _wrap_height))
	return ownPosWrapped + wrapping_offset
