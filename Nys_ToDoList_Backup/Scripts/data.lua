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
					[backupType] = { -- numbered indexes but can have empty slots (never ipairs/pairs on this table directly, use numbered iterations)
						[backupSlot] = { -- backupTable
							name = "",
							date = tostring(date()),
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

	-- TODO redo data:GetDefaults()
	-- TODO rajouter partout profileID (ou tenter avec une table ?)
	-- TODO enlever "autoPreApplyBackup" ? (ou passer en "custom" ? idk)
	-- TODO fonctions pour profile (delete / rename / changeVars, reorder)
	-- TODO foreach pour profiles / autre?

	-- TODO profile management
	-- TODO list re-adaptation
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

data.backupTypesDisplayNames = {
	[data.backupTypes.autoDaily] = "Automatic (Daily)",
	[data.backupTypes.autoWeekly] = "Automatic (Weekly)",
	[data.backupTypes.autoPreImport] = "Automatic (Before Import)",
	[data.backupTypes.autoPreApplyBackup] = "Before last backup",
	[data.backupTypes.manual] = "Manual",
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
		error("Error: private:ApplyDefaults #1") -- TODO recheck if error() or print()
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
	return type(profileID) == "string"
		and utils:HasValue(data.db.profilesOrdered, profileID)
		and type(data.db.profiles[profileID]) == "table"
		and data.db.profiles[profileID]
end

function data:IsProfileRelevant(profileID)
	local profileTable = data:GetValidProfile(profileID)
	return profileTable
		and type(profileTable.character) == "string"
		and profileTable.character == utils:GetCurrentPlayerName()
end

function data:IsValidBackupType(backupType)
	return type(backupType) == "string"
		and not not data.backupTypes[backupType]
end

function data:IsValidBackupSlot(backupType, backupSlot)
	return data:IsValidBackupType(backupType)
		and type(backupSlot) == "number"
		and backupSlot > 0
		and backupSlot <= data.backupCounts[backupType]
end

function data:GetValidProfileBackupType(profileID, backupType)
	local profileTable = data:GetValidProfile(profileID)
	return profileTable
		and data:IsValidBackupType(backupType)
		and type(profileTable.backups[backupType]) =="table"
		and profileTable.backups[backupType]
end

function data:IsValidBackupTable(backupTable)
	-- @see private:CreateNewBackup
	return type(backupTable) == "table"
		and type(backupTable.name) == "string"
		and type(backupTable.addonVersion) == "string" -- TDLATER
		and type(backupTable.savedVarsOrdered) == "table"
		and #backupTable.savedVarsOrdered > 0
		and type(backupTable.savedVars) == "table"
		and next(backupTable.savedVars) ~= nil
end

function data:GetValidBackup(profileID, backupType, backupSlot)
	local profileBackupTypeTable = data:GetValidProfileBackupType(profileID, backupType)
	return profileBackupTypeTable and data:IsValidBackupSlot(backupType, backupSlot) and data:IsValidBackupTable(profileBackupTypeTable[backupSlot]) and profileBackupTypeTable[backupSlot]
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

--/*******************/ Profiles Management /*************************/--

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

function data:CheckForAutomaticSaves()
	if type(data.db.autoSaveInfos) ~= "table" then data.db.autoSaveInfos = {} end
	local infos = data.db.autoSaveInfos

	if type(infos.lastAutoDaily) ~= "number" then infos.lastAutoDaily = 0 end
	if type(infos.lastAutoWeekly) ~= "number" then infos.lastAutoWeekly = 0 end

	local yday = date("*t").yday

	if yday >= ((infos.lastAutoDaily + 1) % 365) then
		data:ScrollBackups(data.backupType.autoDaily, 1)
		data:MakeBackup(data.backupType.autoDaily, 1, true)
		infos.lastAutoDaily = yday
	end

	if yday >= ((infos.lastAutoWeekly + 7) % 365) then
		data:ScrollBackups(data.backupType.autoWeekly, 1)
		data:MakeBackup(data.backupType.autoWeekly, 1, true)
		infos.lastAutoWeekly = yday
	end
end

--/*******************/ Backups Management /*************************/--

function private:CreateNewBackup(profileID, nameOverride)
	local profileTable = data:GetValidProfile(profileID)
	if not profileTable then
		print("Error: private:CreateNewBackup #1")
		return
	end

	local savedVarsOrdered = utils:Deepcopy(profileTable.savedVarsOrdered)
	if savedVarsOrdered ~= "table" or #savedVarsOrdered < 1 then
		print("Error: private:CreateNewBackup #2")
		return
	end

	for i = #savedVarsOrdered, 1, -1 do
		if not utils:IsValidVariableName(savedVarsOrdered[i]) then
			table.remove(savedVarsOrdered, i)
		end
	end

	if #savedVarsOrdered < 1 then
		print("Error: private:CreateNewBackup #3")
		return
	end

	-- @see data:IsValidBackupTable
	local backupTable = {
		name = type(nameOverride) == "string" and nameOverride or tostring(profileTable.name).." - "..tostring(date()),
		date = tostring(date()),
		addonVersion = tostring(GetAddOnMetadata("Nys_ToDoList", "Version") or GetAddOnMetadata("Nys_ToDoListWIP", "Version") or "0"), -- TDLATER
		savedVarsOrdered = savedVarsOrdered,
		savedVars = { },
	}

	for _, savedVar in ipairs(backupTable.savedVarsOrdered) do
		backupTable.savedVars[savedVar] = utils:Deepcopy(_G[savedVar]) -- THE moment where we actually save the saved variables
	end

	return backupTable
end

function data:ScrollBackupType(profileID, backupType, scrollCount)
	scrollCount = type(scrollCount) == "number" and math.floor(scrollCount) or 1
	if scrollCount < 1 then
		return
	end

	local profileBackupTypeTable = data:GetValidProfileBackupType(profileID, backupType)
	if not profileBackupTypeTable or #profileBackupTypeTable < 1 then
		return -- we don't need to scroll an invalid/empty table
	end

	for i = 1, scrollCount, 1 do
		for backupSlot = data.backupCounts[backupType], 1, -1 do
			profileBackupTypeTable[backupSlot] = profileBackupTypeTable[backupSlot-1]
		end
	end
end

function data:MakeBackup(profileID, backupType, backupSlot, forced)
	forced = type(forced) == "boolean" and forced or false

	local createAndMakeBackup = function()
		local profileTable = data:GetValidProfile(profileID)
		if not profileTable or not data:IsValidBackupSlot(backupType, backupSlot) then
			print("Error: data:MakeBackup #1")
			return false
		end

		local nameOverride = tostring(profileTable.name).." - "..tostring(data.backupTypesDisplayNames[backupType]).." - #"..tostring(backupSlot)
		local backupTable = private:CreateNewBackup(profileID, nameOverride)
		if not data:IsValidBackupTable(backupTable) then
			print("Error: data:MakeBackup #2")
			return false
		end

		local profileBackupTypeTable = data:GetValidProfileBackupType(profileID, backupType)
		if not profileBackupTypeTable then -- create it if it doesn't exist yet
			profileTable.backups[backupType] = {}
			profileBackupTypeTable = profileTable.backups[backupType]
		end

		profileBackupTypeTable[backupSlot] = backupTable
		collectgarbage()
		list:Refresh()
		return true
	end

	local backupTable = data:GetValidBackup(profileID, backupType, backupSlot)
	if backupTable and not forced then
		data:CreateStaticPopup(
			"OVERWRITE backup \""..backupTable.name.."\" now?\n(you cannot undo this action)",
			createAndMakeBackup,
			true
		)
		return true
	else
		return createAndMakeBackup()
	end
end

function data:DeleteBackup(profileID, backupType, backupSlot)
	local backupTable = data:GetValidBackup(profileID, backupType, backupSlot)
	if backupTable then
		data:CreateStaticPopup(
			"DELETE backup \""..backupTable.name.."\" now?\n(you cannot undo this action)",
			function()
				local profileBackupTypeTable = data:GetValidProfileBackupType(profileID, backupType)
				if not profileBackupTypeTable then
					print("Error: data:DeleteBackup #1")
					return
				end

				profileBackupTypeTable[backupSlot] = nil
				collectgarbage()
				list:Refresh()
			end,
			true
		)
		return true
	end
	return false
end

function data:ApplyBackup(profileID, backupType, backupSlot)
	local backupTable = data:GetValidBackup(profileID, backupType, backupSlot)
	if backupTable then
		data:CreateStaticPopup(
			"APPLY backup \""..backupTable.name.."\" now?\n**This action will reload your UI**",
			function()
				-- make a backup of the current state before proceeding
				local success = data:MakeBackup(profileID, data.backupType.autoPreApplyBackup, 1, true)
				if not success then
					print("Error: data:ApplyBackup #1")
					return
				end

				-- recheck validity because we waited for an user action
				backupTable = data:GetValidBackup(profileID, backupType, backupSlot)
				if not backupTable then
					print("Error: data:ApplyBackup #2")
					return
				end

				for _, savedVar in ipairs(backupTable.savedVarsOrdered) do
					if utils:IsValidVariableName(savedVar) then
						_G[savedVar] = utils:Deepcopy(backupTable.savedVars[savedVar]) -- THE moment where we actually apply the backups
					end
				end

				ReloadUI()
			end
		)
		return true
	end
	return false
end

--/*******************/ Other /*************************/--

function data:CreateStaticPopup(text, onAccept, showAlert)
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
		showAlert = not not showAlert,
		preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
		OnHide = function()
			disabled = true
		end
	}
	StaticPopup_Show("NysTDLBackup_StaticPopupDialog")
end
