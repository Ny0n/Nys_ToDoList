-- Namespace
local addonName, addonTable = ...

addonTable.core = {}
addonTable.data = {}
addonTable.list = {}
addonTable.options = {}
addonTable.utils = {}

local core = addonTable.core
local data = addonTable.data
local list = addonTable.list
local options = addonTable.options
local utils = addonTable.utils

NysTDLBackup = {}

-- we get the locales from Nys_ToDoList if the addon is loaded
core.L = setmetatable({}, {
	__index = function(_, key)
		if type(NysTDL) == "table"
		and type(NysTDL.libs) == "table"
		and type(NysTDL.libs.L) == "table"
		then
			return NysTDL.libs.L[key]
		else
			return key
		end
	end,
})

local L = core.L

--/***************************************************************************/--

-- data (from toc file)
core.toc = {}
core.toc.title = C_AddOns.GetAddOnMetadata(addonName, "Title")
core.toc.version = C_AddOns.GetAddOnMetadata(addonName, "Version")

core.toc.isDev = ""
--@do-not-package@
core.toc.isDev = " WIP"
--@end-do-not-package@

-- Variables
core.addonName = addonName
core.simpleAddonName = string.gsub(core.toc.title, "Ny's ", "")

-- Easy access to know if we are currently running on retail or not
core.isRetail = (LE_EXPANSION_LEVEL_CURRENT or 0) >= 9

core.backupLoaded = false
core.listLoaded = false

--/*******************/ Events /*************************/--

core.loadFrame = CreateFrame("Frame")

function core:OnEvent(event, ...)
	core[event](core, event, ...)
end

core.loadFrame:SetScript("OnEvent", core.OnEvent)
core.loadFrame:RegisterEvent("ADDON_LOADED")
core.loadFrame:RegisterEvent("PLAYER_LOGIN")

--/*******************/ Functions /*************************/--

function core:ADDON_LOADED(event, addonName)
	-- Always happens before Nys_ToDoList's ADDON_LOADED event, because we are a dependency

	if C_AddOns.IsAddOnLoaded("Nys_ToDoList_Backup") then
		core.backupLoaded = true
	end

	if C_AddOns.IsAddOnLoaded("Nys_ToDoList") then
		core.listLoaded = true
	end

	core.loadFrame:UnregisterEvent(event)
	core.loadFrame:RegisterEvent("PLAYER_LOGOUT")

	data:Initialize()

	list:Initialize()

	pcall(function() options:Initialize() end) -- optionnal, don't crash the whole addon if there's ever a problem in the options
end

function core:PLAYER_LOGIN(event)
	data:CheckForAutomaticSaves()
	core.loadFrame:UnregisterEvent(event)
end

function core:PLAYER_LOGOUT(event)
	data:Uninitialize()
	core.loadFrame:UnregisterEvent(event)
end
