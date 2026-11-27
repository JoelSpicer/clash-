extends RefCounted
class_name CombatGlossary

const KEYWORD_DEFS: Dictionary = {
	"Block": "Reduce incoming damage by X",
	"Cost": "Lose X stamina",
	"Counter": "You must have used an action with Create Opening X or higher in the previous clash",
	"Create Opening": "Your opponent's next action cannot have a Cost trait higher than X",
	"Damage": "Reduce your opponent's health by X",
	"Defence": "Can only be used on the defensive. This action gains the Recover 1 trait.",
	"Feint": "In addition to the action's listed traits, it gains all the traits of another action that you can use. That action can be chosen after actions are revealed",
	"Dodge": "You ignore the effects of your opponent's action if its total stamina cost is X or below",
	"Fall Back": "Lose X momentum",
	"Guard Break": "Ignore the 'Block X' trait of your opponent's action",
	"Heal": "Gain X HP",
	"Injure": "Your opponent must lose 1 HP every clash after this until you use an action with the Recover X, Heal X or Fall Back X traits, or the combat ends",
	"Momentum": "Gain X momentum",
	"Multi": "After this action, you may use any other action that has a Cost trait of X or below, and that does not have the Multi X trait. This action interacts with your opponent's previous action. If your opponent's action would end your combo, you do not get to use this trait. In addition, moves with this trait can be used to start a combo",
	"Offence": "Can only be used on the offensive. If you are reduced to 0 SP, your combo ends",
	"Opener": "Only actions with this trait can be used to start a combo",
	"Opportunity": "Increase your next action's momentum by X, and reduce its stamina cost by X",
	"Parry": "Your action steals the Momentum X trait of your opponent's action. If this causes the momentum tracker to move in your direction, your opponent's action has no effect on you, and your opponent's next action must have the Opener trait",
	"Recover": "Gain X stamina",
	"Repeat": "Execute this action up to X total times in a single clash, paying its stamina cost for each hit while you have enough SP. Each hit interacts with your opponent's action (Block applies per hit; Parry only steals 1 hit's momentum), and Opportunity applies only to the first hit.",
	"Retaliate": "Your opponent takes the same damage as they deal to you in the current clash (reduced by their Block or Dodge)",
	"Reversal": "If the momentum tracker moves closer to your side from this clash, the current combo ends and you take the offence, even if you do not have the momentum advantage. This applies even in the initial clash",
	"Super": "This action can only be used when the momentum tracker has reached the end of your side. You can only use an action with this trait once per combat",
	"Sweep": "This action affects all opponents you are in combat with",
	"Tiring": "Cause the opponent to lose X Stamina (drains HP from Heavy fighters if they are out of SP)"
}
