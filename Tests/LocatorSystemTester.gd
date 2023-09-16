@tool
extends Node2D

@export var Radius : float = 10:
	set(_value):
		Radius = _value
		queue_redraw()

@export var Motion : Vector2 = Vector2(50, 0):
	set(_value):
		Motion = _value
		queue_redraw()
		
@export var LocatorPoolName : String = "Test"

var _locatorsystem : LocatorSystem = LocatorSystem.new()

func _draw():
	var circleColor = Color.DARK_SEA_GREEN
	if _tempLocatorArray != null and _tempLocatorArray.size() > 0:
		circleColor = Color.CRIMSON
	draw_circle(Vector2.ZERO, Radius, circleColor)
	if Motion != Vector2.ZERO:
		draw_circle(Motion, Radius, circleColor)
		draw_line(Vector2.ZERO, Motion, Color.BLUE)

func _ready():
	for child in get_children():
		var locatorChild = child as Locator
		if locatorChild != null:
			_locatorsystem.locator_entered_tree(locatorChild)

var _tempLocatorArray : Array[Locator] = []
func _process(delta):
	if _tempLocatorArray == null: _tempLocatorArray = []
	_tempLocatorArray.clear()
	if Motion == Vector2.ZERO:
		_tempLocatorArray = _locatorsystem.get_locators_in_circle(LocatorPoolName, global_position, Radius)
	else:
		_tempLocatorArray = _locatorsystem.get_locators_in_circle_motion(LocatorPoolName, global_position, Radius, Motion)
	#print("numlocators: %d"%_tempLocatorArray.size())
	queue_redraw()
