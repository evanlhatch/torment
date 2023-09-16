extends GameObjectComponent

@export var ProbabilityToApply : float = 1
@export var GoldAmount : int = 1

func _ready():
	initGameObjectComponent()
	_gameObject.connectToSignal("Collected", addGold)

func addGold(toNode:GameObject):
	if ProbabilityToApply >= 1 or randf() < ProbabilityToApply:
		if toNode == Global.World.Player:
			Global.World.addGold(GoldAmount)
			if toNode != null:
				var posProvider = toNode.getChildNodeWithMethod("get_worldPosition")
				if posProvider != null:
					Fx.show_text_indicator(
						posProvider.get_worldPosition() + Vector2.UP * 32.0,
						str(GoldAmount),
						5, 2.0, Color.YELLOW)
