-- Save States: the menu, a panel in the game's own debug UI (ImGui).
-- It costs nothing while it's closed.
local SS = require "savestates.main"
local D = require "savestates.data"

local Menu = {}

Menu.L = nil
Menu.ui = nil -- the panel's ui while it's open (to tell typing apart from keys)
Menu.node = nil
Menu.SHOW = 150 -- rows of each history list at a time

local function When(t)
	if type(t) ~= "number" then
		return "?"
	end
	return os.date("%m-%d %H:%M", t)
end

local function Line(m)
	if m == nil then
		return "empty"
	end
	local pin = Menu.L.store.pins[m.id] and " [pinned]" or ""
	local note = m.note and (" - " .. m.note) or ""
	return string.format("#%d %s  %s%s%s", m.id, When(m.time), tostring(m.summary or ""), note, pin)
end

function Menu.Make(DebugNodes)
	local L = Menu.L
	local Node = Class(DebugNodes.DebugNode, function(self)
		DebugNodes.DebugNode._ctor(self, "Save States")
		self.sel = nil
		self.note = ""
		self.confirm_delete = false
		self.show = { manual = Menu.SHOW, auto = Menu.SHOW }
	end)
	Node.PANEL_WIDTH = 820
	Node.PANEL_HEIGHT = 640

	function Node:Select(id)
		self.sel = id
		local m = L.store.meta[id]
		self.note = m and m.note or ""
		self.confirm_delete = false
	end

	function Node:RenderPanel(ui, panel)
		Menu.ui = ui
		local store = L.store
		local keys = SS.settings.keys
		ui:Text(string.format("Save %s   Load: Rebuild %s, Replicate %s   Latest auto: %s / %s",
			SS.KeyText(keys.save), SS.KeyText(keys.rebuild), SS.KeyText(keys.replicate),
			SS.KeyText(keys.latest_rebuild), SS.KeyText(keys.latest_replicate)))
		ui:Text("Rebuild: your own gear, the saved run. Replicate: the saved gear too (given if you don't own it).")
		if not store.loaded then
			ui:Text("The save list is loading...")
			return
		end
		if L.busy then
			ui:Text("A load is in progress...")
		end
		ui:Separator()

		-- the selected entry
		local sel = self.sel ~= nil and store.meta[self.sel] or nil
		if sel ~= nil then
			ui:Text("Selected: " .. Line(sel))
			if ui:Button("Load: Rebuild##sel", nil, nil, L.busy) then
				L.LoadId(sel.id, "rebuild", "#" .. sel.id)
			end
			ui:SameLineWithSpace()
			if ui:Button("Load: Replicate##sel", nil, nil, L.busy) then
				L.LoadId(sel.id, "replicate", "#" .. sel.id)
			end
			ui:SameLineWithSpace()
			if ui:Button((store.pins[sel.id] and "Unpin" or "Pin") .. "##sel") then
				store:SetPin(sel.id, not store.pins[sel.id])
			end
			ui:SameLineWithSpace()
			if not self.confirm_delete then
				if ui:Button("Delete##sel") then
					self.confirm_delete = true
				end
			else
				if ui:Button("Really delete?##sel") then
					store:Delete(sel.id)
					self.sel = nil
				end
				ui:SameLineWithSpace()
				if ui:Button("Keep##sel") then
					self.confirm_delete = false
				end
			end
			ui:Text("Copy to slot:")
			for s = 1, store.SLOTS do
				ui:SameLineWithSpace()
				if ui:Button(tostring(s % 10) .. "##copy" .. s) then
					store:CopyToSlot(sel.id, s)
				end
			end
			local changed, text = ui:InputText("Note##sel", self.note or "")
			if changed then
				self.note = text
			end
			ui:SameLineWithSpace()
			if ui:Button("Save note##sel") then
				store:SetNote(sel.id, self.note ~= "" and self.note or nil)
			end
			ui:Separator()
		end

		-- the slots
		if ui:CollapsingHeader("Slots") then
			for s = 0, store.SLOTS do
				local id = store:SlotId(s)
				local m = id ~= nil and store.meta[id] or nil
				local name = s == 0 and "Slot 0 (auto)" or ("Slot " .. s)
				ui:Text(name .. ": " .. Line(m))
				if m ~= nil then
					ui:SameLineWithSpace()
					if ui:Button("Select##slot" .. s) then
						self:Select(id)
					end
					ui:SameLineWithSpace()
					if ui:Button("Rebuild##slot" .. s, nil, nil, L.busy) then
						L.LoadSlot(s, "rebuild")
					end
					ui:SameLineWithSpace()
					if ui:Button("Replicate##slot" .. s, nil, nil, L.busy) then
						L.LoadSlot(s, "replicate")
					end
				end
				if s > 0 then
					ui:SameLineWithSpace()
					if ui:Button("Save here##slot" .. s, nil, nil, L.busy) then
						L.Save(s)
					end
				end
			end
		end

		for _, which in ipairs({ "manual", "auto" }) do
			local list = store:List(which)
			local title = (which == "manual" and "Manual history" or "Auto history (rooms, and your state before each load)")
				.. string.format(" (%d)##%s", #list, which)
			if ui:CollapsingHeader(title) then
				local n = math.min(#list, self.show[which])
				for i = 1, n do
					local m = list[i]
					if ui:Button("Select##" .. which .. m.id) then
						self:Select(m.id)
					end
					ui:SameLineWithSpace()
					ui:Text(Line(m))
				end
				if #list > n then
					if ui:Button("Show more##" .. which) then
						self.show[which] = self.show[which] + Menu.SHOW
					end
				end
			end
		end
	end

	DebugNodes.SaveStatesMenu = Node
	Menu.node = Node
	return Node
end

-- open / close
function Menu.Toggle(G)
	if Menu.node == nil or not rawget(G, "CAN_USE_DBUI") then
		SS.Note("No menu", "it needs the game's debug UI; in the console, ss_help() does its jobs")
		return
	end
	local DebugNodes = require "dbui.debug_nodes"
	local ok, err = pcall(DebugNodes.ShowDebugPanel, Menu.node, true)
	if not ok then
		SS.Note("No menu", tostring(err))
	end
end

-- typing in the menu's note (or another ImGui text box)
function Menu.Typing()
	local ui = Menu.ui
	if ui ~= nil and ui.WantTextInput ~= nil then
		local ok, v = pcall(ui.WantTextInput)
		return ok and v == true
	end
	return false
end

return Menu
