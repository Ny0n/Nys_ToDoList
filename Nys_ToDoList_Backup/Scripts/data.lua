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
