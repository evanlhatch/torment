extends Resource

class_name ChampionModifierResource

@export var Modifies : String
@export var AdditiveMod : float
@export var MultiplierMod : float

func ApplyToGameObject(gameobject:GameObject, difficulty:float):
	var modifier = Modifier.create(Modifies, gameobject)
	modifier.setAdditiveMod(AdditiveMod * difficulty)
	modifier.setMultiplierMod(MultiplierMod * difficulty)
	gameobject.triggerModifierUpdated(Modifies)
	gameobject.set_meta("champion_rand_mod_%s"%Modifies, modifier)
