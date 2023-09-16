extends Resource

class_name ChampionAbilityResource

@export var AddSceneAsChild : PackedScene
@export var AttachToPositionProvider : bool = false

func AddAbilityToGameObject(gameobject:GameObject):
	var instance : Node = AddSceneAsChild.instantiate()
	if AttachToPositionProvider:
		var positionProvider = gameobject.getChildNodeWithMethod("get_worldPosition")
		if positionProvider != null:
			positionProvider.add_child(instance)
			return
	gameobject.add_child(instance)
