extends Node2D

@export var StartScale : Vector2
@export var TargetScale : Vector2
@export var TweenDuration : float = 1.5
@export var TweenDelay : float = 0.5
@export var AttackSignalProvider : Node

func _ready() -> void:
	if AttackSignalProvider != null:
		AttackSignalProvider.connect("AttackTriggered", _on_attack)

func _on_attack(_index) -> void:
	scale = StartScale
	await get_tree().create_timer(TweenDelay).timeout
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(self, "scale", TargetScale, TweenDuration).from(StartScale)
