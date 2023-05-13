-- Namespace
local addonName, addonTable = ...

addonTable.core = {}
addonTable.data = {}
addonTable.list = {}
addonTable.utils = {}

local core = addonTable.core
local data = addonTable.data
local list = addonTable.list
local utils = addonTable.utils

NysTDLBackup = {}

--/***************************************************************************/--

-- data (from toc file)
core.toc = {}
core.toc.title = GetAddOnMetadata(addonName, "Title")
core.toc.version = GetAddOnMetadata(addonName, "Version")

-- Variables
core.addonName = addonName
core.simpleAddonName = string.gsub(core.toc.title, "Ny's ", "")

-- Easy access to know if we are currently running on retail or not
core.isRetail = (LE_EXPANSION_LEVEL_CURRENT or 0) >= 9

--/*******************/ Events /*************************/--

core.loadFrame = CreateFrame("Frame")

function core:OnEvent(event, ...)
	core[event](core, event, ...)
end

core.loadFrame:SetScript("OnEvent", core.OnEvent)
core.loadFrame:RegisterEvent("ADDON_LOADED")
core.loadFrame:RegisterEvent("PLAYER_LOGOUT")

--/*******************/ Functions /*************************/--

function core:ADDON_LOADED(event, addOnName)
	if addOnName ~= core.addonName then
		return
	end

	core.loadFrame:UnregisterEvent(event)

	print("Backup ADDON_LOADED")
	print("backup: \""..tostring(NysToDoListBackupDB).."\"")

	data:Initialize()

	list:CreateBackupFrame()

	data:CheckForAutomaticSaves()

	print(core.toc.title..": Addon loaded (v"..core.toc.version..")") -- TODO to be removed
end

function core:PLAYER_LOGOUT(event)
	core.loadFrame:UnregisterEvent(event)

	data:Uninitialize()

	print("Backup PLAYER_LOGOUT")
	print("backup: \""..tostring(NysToDoListBackupDB).."\"")
end
