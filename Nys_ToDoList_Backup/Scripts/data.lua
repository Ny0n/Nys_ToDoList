-- Namespace
local _, addonTable = ...

local data = addonTable.data
local list = addonTable.list
local utils = addonTable.utils

--/*******************/ Saved Data /*************************/--

local private = {}

--[[
	defaults = {
		selectedProfile = profileID,
		profilesOrdered = { profileID, ... }, -- ipairs
		profiles = { -- pairs
			[profileID] = { -- profileTable
				name = "foo",
				savedVarsOrdered = { "bar", ... }, -- ipairs
				character =  false | utils:GetCurrentPlayerName(),
				autoSaveInfos = {
					lastDaily = date("*t").yday,
					lastWeekly = date("*t").yday,
				},
				backups = { -- pairs
					[backupType] = { -- ipairs
						[backupSlot] = { -- backupTable
							name = "",
							addonVersion = "", -- TODO only for this backup addon version?
							savedVarsOrdered = utils:Deepcopy(profiles[profileID].savedVarsOrdered), -- ipairs
							savedVars = { -- pairs
								["savedVar"] = utils:Deepcopy(savedVar),
								...
							}
						}
					},
					...
				}
			},
			...
		},
	}

	data:CreateNewProfile(name, isChar, savedVarNames):profileID, profileTable
	data:CreateNewBackup(profileID):backupTable

	-- TODO redo data:GetDefaults()
	-- TODO rajouter partout profileID (ou tenter avec une table ?)
	-- TODO enlever "autoPreApplyBackup" ? (ou passer en "custom" ? idk)
	-- TODO fonctions pour profile (delete / rename / changeVars, reorder)
	-- TODO foreach pour profiles / autre?
]]

---@class backupTypes
data.backupTypes = {
	autoDaily = "autoDaily",
	autoWeekly = "autoWeekly",
	autoPreImport = "autoPreImport",
	autoPreApplyBackup = "autoPreApplyBackup",
	manual = "manual"
}

-- order of backup types
data.backupTypesOrdered = {
	data.backupTypes.manual,
	data.backupTypes.autoDaily,
	data.backupTypes.autoWeekly,
	data.backupTypes.autoPreImport,
	data.backupTypes.autoPreApplyBackup
}

data.backupCounts = {
	[data.backupTypes.autoDaily] = 4,
	[data.backupTypes.autoWeekly] = 4,
	[data.backupTypes.autoPreImport] = 2,
	[data.backupTypes.autoPreApplyBackup] = 1,
	[data.backupTypes.manual] = 5,
}

--/*******************/ Initialization /*************************/--

function private:GetDefaults()
	-- globally saved
	local defaults = {
		currentProfile = nil,
		profilesOrdered = { },
		profiles = { },
	}

	return defaults
end

function private:ApplyDefaults(db, defaults)
	if type(db) ~= "table" or type(defaults) ~= "table" then
		error("Error: ApplyDefaults args")
		return
	end

	for k,v in pairs(defaults) do
		if type(db[k]) ~= type(v) then
			db[k] = utils:Deepcopy(v)
			if type(db[k]) =="table" then
				private:ApplyDefaults(db[k], v)
			end
		end
	end
end

function private:VerifyIntegrity()
	-- // check the profiles & backups to make sure the Ordered tables and their data counterpart are correct

	local ordered

	-- // profiles

	-- verify that each profile found in data.db.profilesOrdered exists in data.db.profiles,
	-- and if not, remove it from data.db.profilesOrdered
	ordered = data.db.profilesOrdered
	for i = #ordered, 1, -1 do
		if type(data.db.profiles[ordered[i]]) ~= "table" then
			data.db.profiles[ordered[i]] = nil
			table.remove(ordered, i)
		end
	end

	-- verify that each profile found in data.db.profiles exists in data.db.profilesOrdered,
	-- and if not, add it to data.db.profilesOrdered
	ordered = data.db.profilesOrdered
	for profileID in pairs(data.db.profiles) do
		if not utils:HasValue(ordered, profileID) then
			table.insert(ordered, profileID)
		end
	end

	-- // backups

	-- verify that each savedVars found in profiles.backups. exists in data.db.profiles,
	-- and if not, remove it from data.db.profilesOrdered

end

function data:Initialize()
	NysToDoListBackupDB = NysToDoListBackupDB or {}
	data.db = utils:Deepcopy(NysToDoListBackupDB)
	private:ApplyDefaults(data.db, private:GetDefaults())
	private:VerifyIntegrity()
	data:OnDBUpdate()
end

function data:Uninitialize()
	NysToDoListBackupDB = data.db or NysToDoListBackupDB -- back to the global env to be saved
end

function data:OnDBUpdate()
	-- when the local DB changes, wy apply those changes to the globally saved variable
	-- (for added security in case the client crashes)
	NysToDoListBackupDB = utils:Deepcopy(data.db)
end

--/*******************/ Data Access /*************************/--

function data:GetValidProfile(profileID)
	return type(profileID) == "string" and utils:HasValue(data.db.profilesOrdered, profileID) and type(data.db.profiles[profileID]) == "table" and data.db.profiles[profileID]
end

function data:IsProfileRelevant(profileID)
	local profileTable = data:GetValidProfile(profileID)
	return profileTable and type(profileTable.character) == "string" and profileTable.character == utils:GetCurrentPlayerName()
end

function data:IsValidBackupType(backupType)
	return type(backupType) == "string" and not not data.backupTypes[backupType]
end

function data:IsValidBackupSlot(backupType, backupSlot)
	return data:IsValidBackupType(backupType) and type(backupSlot) == "number" and backupSlot > 0 and backupSlot <= data.backupCounts[backupType]
end

function data:GetValidProfileBackupType(profileID, backupType)
	local profileTable = data:GetValidProfile(profileID)
	return profileTable and data:IsValidBackupType(backupType) and type(profileTable.backups[backupType]) =="table" and profileTable.backups[backupType]
end

function data:GetValidBackup(profileID, backupType, backupSlot)
	local profileBackupTypeTable = data:GetValidProfileBackupType(profileID, backupType)
	return profileBackupTypeTable and data:IsValidBackupSlot(backupType, backupSlot) and type(profileBackupTypeTable[backupSlot]) == "table" and profileBackupTypeTable[backupSlot]
end

function data:ForEachProfile(callback)
	--[[
		--- if callback is a function ---

		callback(profileID, profileTable) -- /!\ only calls for valid profiles /!\

		--- if callback is not function ---

		for profileID, profileTable in data:ForEachProfile() do
			-- /!\ only loops through valid profiles /!\
		end
	]]

	if type(callback) == "function" then
		for profileID, profileTable in ipairs(data.db.profilesOrdered) do
			if not not data:GetValidProfile(profileID) then
				callback(profileID, profileTable)
			end
		end

		return
	end

	local index, profileID
	return function() -- iterator
		repeat
			index, profileID = next(data.db.profilesOrdered, index)
			local redo = not not data:GetValidProfile(profileID)
		until not redo

		return index, profileID
	end
end

function data:ForEachBackupSlot(callback)
	--[[
		--- if callback is a function ---

		callback(backupType, backupSlot) -- ordered for all backupType and backupSlot

		--- if callback is not function ---

		for backupType, backupSlot in data:ForEachBackupSlot() do
			 -- ordered for all backupType and backupSlot
		end
	]]

	if type(callback) == "function" then
		for _, backupType in ipairs(data.backupTypeOrdered) do
			for backupSlot = 1, data.backupCounts[backupType], 1 do
				callback(backupType, backupSlot)
			end
		end

		return
	end

	local indexType, backupType, backupSlot
	return function() -- iterator
		repeat
			if not backupSlot then
				indexType = (indexType or 0) + 1
				backupType = data.backupTypeOrdered[indexType]
				if not data:IsValidBackupType(backupType) then
					return
				end
			end

			backupSlot = (backupSlot or 0) + 1
			if not data:IsValidBackupSlot(backupType, backupSlot) then
				backupSlot = nil
			end
		until backupType and backupSlot

		return backupType, backupSlot
	end
end

--/*******************/ Backups /*************************/--

function data:CheckForAutomaticSaves()
	if type(data.db.autoSaveInfos) ~= "table" then data.db.autoSaveInfos = {} end
	local infos = data.db.autoSaveInfos

	if type(infos.lastAutoDaily) ~= "number" then infos.lastAutoDaily = 0 end
	if type(infos.lastAutoWeekly) ~= "number" then infos.lastAutoWeekly = 0 end

	local yday = date("*t").yday

	if yday >= ((infos.lastAutoDaily + 1) % 365) then
		data:ScrollBackups(data.backupType.autoDaily, 1)
		data:WriteBackupToSlot(data.backupType.autoDaily, 1, true)
		infos.lastAutoDaily = yday
	end

	if yday >= ((infos.lastAutoWeekly + 7) % 365) then
		data:ScrollBackups(data.backupType.autoWeekly, 1)
		data:WriteBackupToSlot(data.backupType.autoWeekly, 1, true)
		infos.lastAutoWeekly = yday
	end
end

function data:CreateNewProfile(name, isChar, savedVarNames)
	if type(name) ~= "string" or not string.match(name, "%S") then
		print("Error: Invalid name for profile")
		return
	end
	if type(isChar) ~= "boolean" then
		print("Error: Invalid isChar for profile")
		return
	end
	if type(savedVarNames) ~= "table" or #savedVarNames < 1 then
		print("Error: Invalid savedVarNames for profile")
		return
	end
	for _,varName in ipairs(savedVarNames) do
		if not utils:IsValidVariableName(varName) then
			print("Error: Invalid savedVarNames for profile")
			return
		end
	end

	local profile = {
		name = name,
		character = isChar and utils:GetCurrentPlayerName(),
		savedVars = savedVarNames
	}

	return profile
end

function data:CreateNewBackup()
	local backup = {
		name = tostring(date()),
		addonVersion = tostring(select(2, pcall(function() return NysTDL.core.toc.version end))),
		data = utils:Deepcopy(NysToDoListDB)
	}

	return backup
end

function data:ScrollBackups(backupType, slotScrollCount)
	slotScrollCount = slotScrollCount or 1
	if not data.backupType[backupType] then -- TODO do everywhere or nowhere?
		print("backupType Error")
		return
	end

	if not data.db.backups[backupType] then
		data.db.backups[backupType] = {}
	end

	for i=1, slotScrollCount, 1 do
		for slot=data.backupCount[backupType], 1, -1 do
			data.db.backups[backupType][slot] = data.db.backups[backupType][slot-1]
		end
	end
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
