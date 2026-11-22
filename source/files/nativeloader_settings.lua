-- Native Loader settings (optional file: without it these defaults apply).
-- Data only: no code runs from here. Lives next to nativeloader.lua in the mods folder.
return {
	enabled = true,       -- false: load no mods at all (the game runs unmodified)
	disabled_mods = {},   -- mod folders to leave out, e.g. { "rotwood-stick-aim", "rotwood-perf-probe" }
	fast_require = false, -- experimental: game scripts are found without first looking in every mod folder
	                      -- (a mod can then no longer replace a game script by having a file with the same path)
	notices = true,       -- the message at the main menu when a mod failed to load / the mods are off
	verbose = false,      -- more lines in client_log.txt (every folder looked at, modimport, post-init counts)
}
