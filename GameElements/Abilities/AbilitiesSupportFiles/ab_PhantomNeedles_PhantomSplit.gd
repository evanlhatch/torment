extends Node

@export var BaseAbilityWeaponIndex : int = 1010
@export var BulletModifierScript : GDScript
@export var SplitAngleDegrees : float = 45
@export var SpeedReductionPercent : float = 0.7
@export var BaseDamageAdd : int = 15

func AquireAbility(modifiedTarget:Node) -> Array[Node]:
    var baseNeedlesAbility : Ability = Global.World.AbilityPool.find_ability_with_weapon_index(BaseAbilityWeaponIndex)
    if baseNeedlesAbility == null:
        printerr("ab_PhantomNeedles_PhantomSplit couldn't find its base ability on the player!")
        return []
    for bestMod in baseNeedlesAbility.bestowed_modifiers:
        if bestMod.has_method("emit_with_passed_time"):
            # this is the emitter of the phantomneedles. we'll add our modifier to
            # the bullet prototype gameobject.
            var modifier = BulletModifierScript.new()
            modifier._splitAngle = deg_to_rad(SplitAngleDegrees)
            modifier._speedMult = SpeedReductionPercent
            bestMod._bulletPrototype.add_child(modifier)
            var applyDamageOnHit = bestMod._bulletPrototype.getChildNodeWithProperty("DamageAmount")
            applyDamageOnHit.DamageAmount += BaseDamageAdd
            return []

    printerr("ab_PhantomNeedles_PhantomSplit could not find the bestowed needle emitter!")
    return []
