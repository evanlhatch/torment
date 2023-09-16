extends Node

@export var WaitForTagToAppear : String = "cupbearer_free"
@export var MarkerToRemove : Node

func _ready():
	if not WaitForTagToAppear.is_empty():
		while not Global.World.Tags.isTagActive(WaitForTagToAppear):
			await Global.World.Tags.TagsUpdated

	if is_instance_valid(MarkerToRemove): MarkerToRemove.queue_free()

	$"../Sprite_Idle".visible = false
	var drinking_sprite = $"../Sprite_Drink"
	drinking_sprite.visible = true
	drinking_sprite.play("drink")
	await drinking_sprite.animation_finished
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(
		drinking_sprite.get_material(), "shader_parameter/flash_modifier", 1.0, 0.4).from(0.0)
	tween.tween_property(
		drinking_sprite, "scale", Vector2(.02, 4.0), 0.4).from(Vector2.ONE)
	await tween.finished
	$"../SelfLight".energy = 1.0
	drinking_sprite.visible = false

