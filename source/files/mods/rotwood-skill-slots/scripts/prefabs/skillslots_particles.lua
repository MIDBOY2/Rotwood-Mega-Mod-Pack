-- Skill Slots: Explosive Dive's pink crit trail, the particle effect its primed
-- arrow flies with. The game's focus arrow sparks (bow_arrow_trail_focus) in
-- crit pink, added to the game's particle list and made by the game's particle
-- maker (prefabs/particles_autogen.lua's MakeAutogenParticles, the one every
-- particle effect comes from). skillslots/finishskills.lua uses it.

local TAG = "[Skill Slots]"

local MakeAutogenParticles = rawget(_G, "MakeAutogenParticles")
if MakeAutogenParticles == nil then
	print(TAG .. " Explosive Dive: no pink trail (the game's particle maker MakeAutogenParticles is gone)")
	return
end

local okf, Finish = pcall(require, "skillslots.finishskills")
local okd, PData = pcall(require, "prefabs.particles_autogen_data")
local params = okf and okd and Finish.CritTrailParams(PData) or nil
if params == nil then
	print(TAG .. " Explosive Dive: no pink trail (the game's focus arrow trail is gone)")
	return
end

PData[Finish.CRIT_TRAIL] = params
return MakeAutogenParticles(Finish.CRIT_TRAIL, params)
