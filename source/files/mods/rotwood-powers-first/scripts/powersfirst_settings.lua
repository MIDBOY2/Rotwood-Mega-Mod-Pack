-- Powers First settings. Restart the game after changing this file.
return {
	-- false = the mod is off (the game's own behaviour)
	enabled = true,

	-- false = everyone waits until every player has picked (power choosing is over for the room).
	-- true  = a player who has picked can use NPCs and the rest again while the others still pick;
	--         only the powers that player can still take keep them switched off for them.
	only_own_powers = false,

	-- true = also switched off while the power crystal is waiting to be hit (before the powers come out)
	include_crystal = false,

	-- things never switched off, by prefab name (players, so you can revive them, and the powers
	-- themselves never are). Example: allow = { "healing_fountain" },
	allow = {},
}
