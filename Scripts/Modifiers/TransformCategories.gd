extends GameObjectComponent

@export var OnlyWithExistingDamageCategory : String = "DefaultWeapon"
@export var AddModifierCategories : Array[String]
@export var RemoveModifierCategories : Array[String]
@export var AddDamageCategories : Array[String]
@export var RemoveDamageCategories : Array[String]

func _ready():
	initGameObjectComponent()
	if _gameObject == null:
		return
		
	# we don't want to remove categories that another transformer
	# has added...
	var otherTransformers : Array = []
	_gameObject.getChildNodesWithMethod("Transformer_GetAddedDamageCategories", otherTransformers)
	for otherTransformer in otherTransformers:
		if otherTransformer == self:
			continue
		for otherAddedDamageCat in otherTransformer.Transformer_GetAddedDamageCategories():
			RemoveDamageCategories.erase(otherAddedDamageCat)
		for otherAddedModifierCat in otherTransformer.Transformer_GetAddedModifierCategories():
			RemoveModifierCategories.erase(otherAddedModifierCat)
		
	var transformComponents : Array = []
	_gameObject.getChildNodesWithMethod("transformCategories", transformComponents)
	for comp in transformComponents:
		comp.transformCategories(
			OnlyWithExistingDamageCategory,
			AddModifierCategories,
			RemoveModifierCategories,
			AddDamageCategories,
			RemoveDamageCategories)
	
	# listen to newly added components, so that those can be transformed as well
	_gameObject.child_entered_tree.connect(componentWasAddedToGameObject)
	# also listen to newly spawned summons:
	_gameObject.connectToSignal("SummonWasSummoned", summonWasSummoned)

func summonWasSummoned(summonGameObject:GameObject):
	var transformComponents : Array = []
	summonGameObject.getChildNodesWithMethod("transformCategories", transformComponents)
	for comp in transformComponents:
		comp.transformCategories(
			OnlyWithExistingDamageCategory,
			AddModifierCategories,
			RemoveModifierCategories,
			AddDamageCategories,
			RemoveDamageCategories)

func componentWasAddedToGameObject(component:Node):
	if component.has_method("transformCategories"):
		component.transformCategories(
			OnlyWithExistingDamageCategory,
			AddModifierCategories,
			RemoveModifierCategories,
			AddDamageCategories,
			RemoveDamageCategories)

func Transformer_GetAddedDamageCategories() -> Array[String]:
	return AddDamageCategories

func Transformer_GetAddedModifierCategories() -> Array[String]:
	return AddModifierCategories
