-- Fast Load: hidden-HUD fix (a game bug, Rotwood build 760548).
--
-- The extra lives counter on the player HUD (widgets/ftf/extraliveswidget.lua,
-- shown when you have the Extra Lives talent) refreshes every frame, and its
-- "was I hidden?" check is IsVisible(), which is false whenever any parent is
-- hidden. The game hides the whole HUD while a town menu is open (every
-- MultiPanelScreen: the skill menu, the forge, the armoury...), on the pause
-- screen and on the dungeon selection screen. Then every frame it sets its
-- text again, lays itself out and pushes "refresh_hud", which lays out the
-- whole player HUD again (PlayerStatusWidget:_Layout): measured in the game
-- (Perf Probe, 2026-11-11) at about 4 MB of garbage and 200-240 ms of every
-- second with the skill menu open, so the frame rate jumps around and the Lua
-- collector stutters.
-- The fix: while the counter is shown but the HUD above it is hidden, its
-- refresh does nothing (nothing on it can be seen). The game's own refresh
-- runs as before the moment the HUD is back (a new lives count still shows).
local HudFix = {}

HudFix.installed = false

function HudFix.Refresh(orig)
	return function(self, ...)
		local parent = self.parent
		if self.shown and parent ~= nil and not parent:IsVisible() then
			return
		end
		return orig(self, ...)
	end
end

function HudFix.Install(require)
	local ok, ELW = pcall(require, "widgets/ftf/extraliveswidget")
	if not ok or type(ELW) ~= "table" or type(ELW.Refresh) ~= "function" or type(ELW.OnUpdate) ~= "function" then
		return false, "the game's extra lives counter wasn't found"
	end
	if rawget(ELW, "fastload_hudfix") then
		return true
	end
	ELW.Refresh = HudFix.Refresh(ELW.Refresh)
	rawset(ELW, "fastload_hudfix", true)
	HudFix.installed = true
	return true
end

return HudFix
