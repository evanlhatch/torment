extends GameObjectComponentArea2D

@export var SetTagOnTouch : String = ""
@export var ShowTextOnTouch : String = ""
@export var ShowTextColor : Color = Color.WHITE
@export var DisconnectAfterFirstTouch : bool = true
@export var DestroyOnTouch : bool = false

signal Touched


func _ready():
	initGameObjectComponent()
	connect("body_entered", _on_body_entered)


func _on_body_entered(_body:Node2D):
	emit_signal("Touched")
	if not SetTagOnTouch.is_empty():
		Global.World.Tags.setTagActive(SetTagOnTouch)
	if not ShowTextOnTouch.is_empty():
		Fx.show_text_indicator(
			global_position + Vector2.UP * 20.0, ShowTextOnTouch, -1, 1.5, ShowTextColor)
	if DisconnectAfterFirstTouch:
		disconnect("body_entered", _on_body_entered)
	if DestroyOnTouch:
		_gameObject.queue_free()


func get_worldPosition():
	return global_position
