-- Hammer Charge settings. Edit, save, restart the game.
--
-- The Sedament hammer's weapon power ("Light Attacks are Chargeable, and do
-- more Damage") goes on every hammer: hold light attack (X) to charge it like
-- the heavy. A full charge (second tier) is a focus hit that knocks down, with
-- the game's bonus damage for that power: +300% at weapon level 1, +325% at
-- level 2, +350% at level 3 (the hammer's own level decides).
-- The hammer's own weapon power stays too. The Sedament hammer works as before
-- (it isn't given the power twice).

return {
	enabled = true,

	-- A full charge's extra damage, in percent, at weapon level 1 / 2 / 3, for
	-- the hammers this mod gives the power to (the Sedament hammer keeps the
	-- game's +300 / 325 / 350%). A full charged light is a focus hit: Light
	-- Attack 1 / 2 / 3 do 1.25 / 1.5 / 1.75 of your weapon damage as focus, so
	-- +140% makes them 3.0 / 3.6 / 4.2 (the fully charged heavy: 4.58 focus).
	bonus = { 140, 150, 160 },
}
