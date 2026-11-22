-- Camp Brother: what Gishins says. Edit, save, restart the game.
--
-- Written the game's way (strings/writing_dialogue.txt): "agent:" is Gishins, each line
-- is one speech box, a line starting with ! is the animation he plays at the start of
-- the next box (the game's emotes: greet, over_here, point, clap, gesture, think,
-- agree, laugh, shrug, shocked, ...). {name.potion} / {name_multiple.potion} are the
-- game's own names (strings/strings_names.lua); <#RED>...</> is the game's red for
-- the things that matter. Keep the player's lines short and without colour.
return {
	-- his name over the speech box and on the interact prompt
	NAME = "Gishins",

	-- what he says when you press interact (Chit Chat). One of these, picked at random
	-- each time: the same words, a different "hey" animation.
	TALK = {
		[[
			agent:
				!greet
				Are you in the market for <#RED>{name_multiple.potion}</>?
		]],
		[[
			agent:
				!over_here
				Are you in the market for <#RED>{name_multiple.potion}</>?
		]],
		[[
			agent:
				!point
				Are you in the market for <#RED>{name_multiple.potion}</>?
		]],
		[[
			agent:
				!clap
				Are you in the market for <#RED>{name_multiple.potion}</>?
		]],
	},

	-- option 1
	QUESTION_1 = "What can you tell me about different kinds of {name_multiple.potion}?",
	ANSWER_1 = [[
		agent:
			!clap
			Ah, a cussstomer with taste! There are three <#RED>{name_multiple.potion}</> worth carrying, friend.
			!gesture
			<#RED>Soothing Spirits</> is the old family classic. One big, sturdy bottle that <#RED>Heals</> a whole lot in one long swig.
			!think
			<#RED>Bubbling Brew</> comes in little flasks: two quick sips a fill. Each one <#RED>Heals</> a bit less, but you're back on your feet in a blink.
			!point
			And <#RED>Misting Mixture</> <#RED>Heals</> just a touch at first... then it keeps on mending you, every second, for a good while after.
			!agree
			Big gulp, quick sips or the slow mend. Pick the one that suits your hunting.
	]],
	-- said after ANSWER_1 when Tonic Swap's Potion Table is in the game
	ANSWER_1_TABLE = [[
		agent:
			!gesture
			You can choose yours at a <#RED>Potion Table</>. Free of charge, unlike <i>some</i> brothers I could mention.
	]],

	-- option 2
	QUESTION_2 = "What are Potion Tonics?",
	ANSWER_2 = [[
		agent:
			!think
			Tonics? Most folks around here call 'em <#RED>{name_multiple.tonic}</>.
			!gesture
			<#RED>{name_multiple.tonic}</> go right into your <#RED>{name.potion}</>. Take a swig and you get the <#RED>Heal</> <i>and</i> the tonic's kick on top.
			!point
			Every one's brewed from something you hunt. <#RED>{name.bulbug} Boba</> fortifies body and sssoul with a <#RED>Shield</>.
			!shrug
			<#RED>Coffee Jelly</> comes from a <#RED>{name.zucco}</>, so... well. Gotta go fast.
			!shocked
			<#RED>Spicy Pumpkin Seeds</> are flavoured with pure, distilled <#RED>{name.yammo}</> rage. Mind your tongue!
			!laugh
			And <#RED>Small Beans</>? Some <#RED>Pearls</> make you larger. Those ones make you small.
			!agree
			Only one rides in your <#RED>{name.potion}</> at a time, so pick the one the fight calls for.
	]],
	-- said after ANSWER_2 when Tonic Swap's Potion Table is in the game
	ANSWER_2_TABLE = [[
		agent:
			!point
			Choose which ones you carry at a <#RED>Potion Table</>, then flick between 'em mid-hunt.
	]],

	-- option 3 is the game's own "Sorry, I've gotta run!" (STRINGS.TALK.OPT_LEAVE)
}
