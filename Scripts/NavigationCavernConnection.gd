@tool
extends Resource

class_name NavigationCavernConnection

@export var ToCavern : NodePath :
	set(value):
		ToCavern = value
		emit_changed()
	
@export var CorridorWidth : float :
	set(value):
		CorridorWidth = value
		emit_changed()

var ToCavernRuntimeNode : NavigationCavern
var RuntimeCorridorStartOffset : Vector2
var RuntimeCorridorLine : Vector2
var RuntimeCorridorDir : Vector2
