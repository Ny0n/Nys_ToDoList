-- Namespace
local _, addonTable = ...

local data = addonTable.data
local utils = addonTable.utils

--/*******************/ Saved Data /*************************/--

--[[
	backupTable =
	{
		name = "",
		addonVersion = "", -- Nys_ToDoList addon version
		type = "", -- enum ? (autoDaily | autoWeekly | autoPreImport | autoPreApplyBackup | manual)
		data = NysToDoListDB
	}
]]

---@class backupType
data.backupType = {
	["autoDaily"] = 1,
	["autoWeekly"] = 2,
	["autoPreImport"] = 3,
	["autoPreApplyBackup"] = 4,
	["manual"] = 5
}

data.backupCount = {
	[data.backupType.autoDaily] = 4,
	[data.backupType.autoWeekly] = 4,
	[data.backupType.autoPreImport] = 2,
	[data.backupType.autoPreApplyBackup] = 1,
	[data.backupType.manual] = 5,
}

--/*******************/ Functions /*************************/--

function data:GetDefaults()
	-- globally saved
	local defaults = {
		lastAutoDaily = date("*t"),
		lastAutoWeekly = date("*t"),
		backups = {
			-- [1] = backupTable
		}
	}

	return defaults
end

function data:Initialize()
	NysToDoListBackupDB = NysToDoListBackupDB or {}
	data.db = utils:Deepcopy(NysToDoListBackupDB)
	for k,v in pairs(data:GetDefaults()) do
		if data.db[k] == nil then
			data.db[k] = v
		end
	end

	NysToDoListBackupDB = utils:Deepcopy(data.db) -- always do this when we change the data
end

function data:Uninitialize()
	NysToDoListBackupDB = data.db or NysToDoListBackupDB -- back to the global env to be saved
end

function data:GetBackup(backupID)
	return data.db.backups[backupID]
end
