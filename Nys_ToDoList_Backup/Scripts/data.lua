-- Namespace
local _, addonTable = ...

local data = addonTable.data
local list = addonTable.list
local utils = addonTable.utils

--/*******************/ Saved Data /*************************/--

local private = {}

--[[
	defaults = {
		nextProfileID = "1",
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
							timestamp = tostring(date()),
							addonVersion = "", -- TDLATER
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

	-- TODO data:OnDBUpdate()
	-- TODO data:VerifyIntegrity() backups
]]

---@class backupTable
---@class profileBackupTypeTable
---@class profileTable
---@class profileID

---@class backupTypes
data.backupTypes = {
	autoDaily = "autoDaily",
	autoWeekly = "autoWeekly",
	autoPreApplyBackup = "autoPreApplyBackup",
	manual = "manual"
}

-- order of backup types
data.backupTypesOrdered = {
	data.backupTypes.manual,
	data.backupTypes.autoDaily,
	data.backupTypes.autoWeekly,
	data.backupTypes.autoPreApplyBackup
}

-- TODO what happens if this shrinks ? do they get deleted ?
data.backupCounts = {
	[data.backupTypes.autoDaily] = 3,
	[data.backupTypes.autoWeekly] = 3,
	[data.backupTypes.autoPreApplyBackup] = 1,
	[data.backupTypes.manual] = 6,
}

data.backupTypesDisplayNames = {
	[data.backupTypes.autoDaily] = "Automatic (Daily)",
	[data.backupTypes.autoWeekly] = "Automatic (Weekly)",
	[data.backupTypes.autoPreApplyBackup] = "Before last backup",
	[data.backupTypes.manual] = "Manual",
}

--/*******************/ Initialization /*************************/--

function private:GetDefaults()
	-- globally saved
	local defaults = {
		nextProfileID = nil, -- more optimized if we save it
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

	-- default for Nys_ToDoList
	if not data:GetCurrentProfile() then
		local profileID = data:CreateNewProfile("Ny's To-Do List", false, { "NysToDoListDB" })
		data:SetCurrentProfile(profileID)
	end
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

---@return profileTable
---@return profileID, profileTable
function data:GetCurrentProfile(onlyTable)
	onlyTable = type(onlyTable) == "boolean" and onlyTable or false

	local profileID, profileTable = data.db.currentProfile, data:GetValidProfile(data.db.currentProfile)
	if onlyTable then
		return profileTable
	else
		return profileID, profileTable
	end
end

---@return boolean success
function data:SetCurrentProfile(profileID)
	local profileTable = data:GetValidProfile(profileID)

	if profileTable then
		data.db.currentProfile = profileID
	end

	return not not profileTable
end

---@return profileTable | nil
function data:GetValidProfile(profileID)
	return type(profileID) == "string"
		and utils:HasValue(data.db.profilesOrdered, profileID)
		and type(data.db.profiles[profileID]) == "table"
		and data.db.profiles[profileID]
end

---@return boolean
function data:IsProfileRelevant(profileID)
	local profileTable = data:GetValidProfile(profileID)
	return profileTable
		and (not profileTable.character
		or profileTable.character == utils:GetCurrentPlayerName())
end

---@return boolean
function data:IsValidBackupType(backupType)
	return type(backupType) == "string"
		and not not data.backupTypes[backupType]
end

---@return boolean
function data:IsValidBackupSlot(backupType, backupSlot)
	return data:IsValidBackupType(backupType)
		and type(backupSlot) == "number"
		and backupSlot > 0
		and backupSlot <= data.backupCounts[backupType]
end

---@return profileBackupTypeTable | nil
function data:GetValidProfileBackupType(profileID, backupType)
	local profileTable = data:GetValidProfile(profileID)
	return profileTable
		and data:IsValidBackupType(backupType)
		and type(profileTable.backups[backupType]) =="table"
		and profileTable.backups[backupType]
end

---@return boolean
function data:IsValidBackupTable(backupTable)
	-- @see private:CreateNewBackup
	return type(backupTable) == "table"
		and type(backupTable.name) == "string"
		and type(backupTable.addonVersion) == "string" -- TDLATER
		and type(backupTable.timestamp) == "string"
		and type(backupTable.savedVarsOrdered) == "table"
		and #backupTable.savedVarsOrdered > 0
		and type(backupTable.savedVars) == "table"
		and next(backupTable.savedVars) ~= nil
end

---@return backupTable | nil
function data:GetValidBackup(profileID, backupType, backupSlot)
	local profileBackupTypeTable = data:GetValidProfileBackupType(profileID, backupType)
	return profileBackupTypeTable and data:IsValidBackupSlot(backupType, backupSlot) and data:IsValidBackupTable(profileBackupTypeTable[backupSlot]) and profileBackupTypeTable[backupSlot]
end

---@return function Iterator(profileID, profileTable) ordered
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
		for _, profileID in ipairs(data.db.profilesOrdered) do
			local profileTable = data:GetValidProfile(profileID)
			if profileTable then
				callback(profileID, profileTable)
			end
		end

		return
	end

	local index, profileID, profileTable
	return function() -- iterator
		repeat
			index, profileID = next(data.db.profilesOrdered, index)
			if not index then
				return
			end

			profileTable = data:GetValidProfile(profileID)
		until profileTable

		return profileID, profileTable
	end
end

---@return function Iterator(backupType, backupSlot) ordered
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
		for _, backupType in ipairs(data.backupTypesOrdered) do
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
				backupType = data.backupTypesOrdered[indexType]
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

---@return string profileID
function private:NewProfileID()
	local profileID = type(data.db.nextProfileID) == "string"
		and type((select(2, pcall(tonumber, data.db.nextProfileID)))) == "number"
		and data.db.nextProfileID

	if type(profileID) ~= "string" then
		-- init profileID
		profileID = 0
		repeat
			profileID = profileID + 1
		until not utils:HasValue(data.db.profilesOrdered, tostring(profileID))

		data.db.nextProfileID = tostring(profileID)
		profileID = data.db.nextProfileID
	end

	data.db.nextProfileID = tostring(tonumber(profileID) + 1) -- up the next ID by one

	return profileID
end

---@return profileID, profileTable
---@return nil
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

	local profileTable = {
		name = name,
		character = isChar and tostring(utils:GetCurrentPlayerName()),
		savedVarsOrdered = utils:Deepcopy(savedVarNames),
		autoSaveInfos = { -- @see data:CheckForAutomaticSaves
			lastDaily = nil,
			lastWeekly = nil,
		},
		backups = { },
	}

	local profileID = private:NewProfileID()
	if type(profileID) ~= "string" then
		print("Error: data:CreateNewProfile #1")
		return
	end

	-- add to db
	table.insert(data.db.profilesOrdered, profileID)
	data.db.profiles[profileID] = profileTable

	return profileID, profileTable
end

function data:CheckForAutomaticSaves()
	for profileID, profileTable in data:ForEachProfile() do
		if data:IsProfileRelevant(profileID) then
			if type(profileTable.autoSaveInfos) ~= "table" then profileTable.autoSaveInfos = {} end
			local infos = profileTable.autoSaveInfos

			if type(infos.lastDaily) ~= "number" then infos.lastDaily = nil end
			if type(infos.lastWeekly) ~= "number" then infos.lastWeekly = nil end

			local yday = date("*t").yday

			if yday >= (((infos.lastDaily or -1) + 1) % 365) then
				data:ScrollProfileBackupType(profileID, data.backupTypes.autoDaily, 1)
				data:MakeBackup(profileID, data.backupTypes.autoDaily, 1, true)
				infos.lastDaily = yday
			end

			if yday >= (((infos.lastWeekly or -7) + 7) % 365) then
				data:ScrollProfileBackupType(profileID, data.backupTypes.autoWeekly, 1)
				data:MakeBackup(profileID, data.backupTypes.autoWeekly, 1, true)
				infos.lastWeekly = yday
			end
		end
	end
end

--/*******************/ Backups Management /*************************/--

---@return backupTable | nil
function private:CreateNewBackup(profileID)
	local profileTable = data:GetValidProfile(profileID)
	if not profileTable then
		print("Error: private:CreateNewBackup #1")
		return
	end

	local savedVarsOrdered = utils:Deepcopy(profileTable.savedVarsOrdered)
	if type(savedVarsOrdered) ~= "table" or #savedVarsOrdered < 1 then
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

	local addonName = tostring(GetAddOnMetadata("Nys_ToDoList", "Title") or GetAddOnMetadata("Nys_ToDoListWIP", "Title") or "Nys_ToDoList") -- TDLATER
	local addonVersion = tostring(GetAddOnMetadata("Nys_ToDoList", "Version") or GetAddOnMetadata("Nys_ToDoListWIP", "Version") or "0") -- TDLATER

	local timestamp = tostring(date())
	local name = addonName.." ("..addonVersion..") - "..timestamp

	-- @see data:IsValidBackupTable
	local backupTable = {
		name = name,
		addonVersion = addonVersion,
		timestamp = timestamp,
		savedVarsOrdered = savedVarsOrdered,
		savedVars = { },
	}

	for _, savedVar in ipairs(backupTable.savedVarsOrdered) do
		backupTable.savedVars[savedVar] = utils:Deepcopy(_G[savedVar]) -- THE moment where we actually save the saved variables
	end

	return backupTable
end

function data:ScrollProfileBackupType(profileID, backupType, scrollCount)
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

---@return boolean popupWasShown
function data:MakeBackup(profileID, backupType, backupSlot, forced)
	forced = type(forced) == "boolean" and forced or false

	local createAndMakeBackup = function()
		local profileTable = data:GetValidProfile(profileID)

		if not profileTable then
			print("Error: data:MakeBackup #1")
			return false
		end

		if not data:IsValidBackupSlot(backupType, backupSlot) then
			print("Error: data:MakeBackup #2")
			return false
		end

		local backupTable = private:CreateNewBackup(profileID)
		if not data:IsValidBackupTable(backupTable) then
			print("Error: data:MakeBackup #3")
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

---@return boolean popupWasShown
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

---@return boolean popupWasShown
function data:ApplyBackup(profileID, backupType, backupSlot)
	local backupTable = data:GetValidBackup(profileID, backupType, backupSlot)
	if backupTable then
		data:CreateStaticPopup(
			"APPLY backup \""..backupTable.name.."\" now?\n**This action will reload your UI**",
			function()
				-- recheck validity because we waited for an user action
				backupTable = data:GetValidBackup(profileID, backupType, backupSlot)
				if not backupTable then
					print("Error: data:ApplyBackup #1")
					return
				end

				-- make a backup of the current state before proceeding
				local success = data:MakeBackup(profileID, data.backupTypes.autoPreApplyBackup, 1, true)
				if not success then
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
