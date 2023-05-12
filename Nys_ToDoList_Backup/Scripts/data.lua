-- Namespace
local _, addonTable = ...

local data = addonTable.data
local list = addonTable.list
local utils = addonTable.utils

--/*******************/ Saved Data /*************************/--

--[[
	backupTable =
	{
		name = "",
		addonVersion = "", -- Nys_ToDoList addon version
		data = NysToDoListDB
	}
]]

---@class backupType
data.backupType = {
	autoDaily = "autoDaily",
	autoWeekly = "autoWeekly",
	autoPreImport = "autoPreImport",
	autoPreApplyBackup = "autoPreApplyBackup",
	manual = "manual"
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
			-- [backupType] = {
				-- [1] = backupTable
			-- }
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

--/*******************/ Backups /*************************/--

function data:CreateNewBackup()
	local backup = {
		name = tostring(date()),
		addonVersion = tostring(select(2, pcall(function() return NysTDL.core.toc.version end))),
		data = utils:Deepcopy(NysToDoListDB)
	}

	return backup
end

function data:WriteBackupToSlot(backupType, backupSlot, forced)
	forced = forced or false
	if not data.backupType[backupType] then -- TODO do everywhere or nowhere?
		print("backupType Error")
		return
	end
	if backupSlot < 1 or backupSlot > data.backupCount[backupType] then
		print("backupSlot Error")
		return
	end

	if not data.db.backups[backupType] then
		data.db.backups[backupType] = {}
	end

	local createBackup = function()
		data.db.backups[backupType][backupSlot] = data:CreateNewBackup()
		collectgarbage()
		list:Refresh()
	end

	local backup = data:ReadBackupFromSlot(backupType, backupSlot)
	if backup and not forced then
		data:CreateStaticPopup(
			"OVERWRITE backup \""..backup.name.."\" for "..NysTDL.core.toc.title.." now?\n(you cannot undo this action)",
			createBackup
		)
	else
		createBackup()
	end
end

function data:ReadBackupFromSlot(backupType, backupSlot)
	if data.db.backups[backupType] then
		local backup = data.db.backups[backupType][backupSlot]
		if type(backup) == "table"
		and type(backup.name) == "string"
		and type(backup.addonVersion) == "string"
		and type(backup.data) == "table"
		and type(backup.data.global) == "table"
		and backup.data.global.latestVersion == backup.addonVersion then
			return backup
		end
	end

	return nil
end

function data:ApplyBackupFromSlot(backupType, backupSlot)
	local backup = data:ReadBackupFromSlot(backupType, backupSlot)
	if backup then
		data:CreateStaticPopup(
			"APPLY backup \""..backup.name.."\" for "..NysTDL.core.toc.title.." now?\n**This action will reload your UI**",
			function()
				data:WriteBackupToSlot(data.backupType.autoPreApplyBackup, 1, true)
				NysToDoListDB = backup.data
				ReloadUI()
			end
		)
	end
end

function data:DeleteBackupFromSlot(backupType, backupSlot)
	local backup = data:ReadBackupFromSlot(backupType, backupSlot)
	if backup then
		data:CreateStaticPopup(
			"DELETE backup \""..backup.name.."\" for "..NysTDL.core.toc.title.." now?\n(you cannot undo this action)",
			function()
				data.db.backups[backupType][backupSlot] = nil
				collectgarbage()
				list:Refresh()
			end
		)
	end
end

function data:CreateStaticPopup(text, onAccept)
	local disabled = false
	StaticPopupDialogs["NysTDLBackup_StaticPopupDialog"] = {
		text = tostring(text),
		button1 = YES,
		button2 = NO,
		OnAccept = function()
			if disabled then return end
			if type(onAccept) == "function" then
				onAccept()
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		showAlert = true,
		preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
		OnHide = function()
			disabled = true
		end
	}
	StaticPopup_Show("NysTDLBackup_StaticPopupDialog")
end
