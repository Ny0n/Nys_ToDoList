-- Namespace
local _, addonTable = ...

local core = addonTable.core
local data = addonTable.data
local list = addonTable.list
local utils = addonTable.utils

local L = core.L

--/*******************/ Saved Data /*************************/--

local private = {}

--[[
	defaults = {
		nextProfileID = "1", -- NOTE: profiles are not really used atm, but the system is in place in case I ever want to add them
		currentProfile = profileID,
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
							addonName = "", -- TDLATER
							addonVersion = "", -- TDLATER
							timestamp = time(),
							savedVarsOrdered = utils:Deepcopy(profiles[profileID].savedVarsOrdered), -- ipairs
							savedVars = { -- pairs
								["savedVar"] = utils:Deepcopy(savedVar),
								...
							}
						}
					},
					...
				},
				pendingBackup = utils:Deepcopy(backupTable) or nil,
			},
			...
		},
	}
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

data.backupCounts = {
	[data.backupTypes.autoDaily] = 3,
	[data.backupTypes.autoWeekly] = 3,
	[data.backupTypes.autoPreApplyBackup] = 1,
	[data.backupTypes.manual] = 5,
}

--/*******************/ Initialization /*************************/--

function NysTDLBackup:ApplyPendingBackup()
	local profileTable = data:GetCurrentProfile(true)
	local backupTable = type(profileTable.pendingBackup) == "table" and profileTable.pendingBackup or nil

	if data:IsValidBackupTable(backupTable) and (select(2, C_AddOns.IsAddOnLoaded("Nys_ToDoList"))) then
		-- Apply the pending backup directly, then invalidate it

		for _, savedVar in ipairs(backupTable.savedVarsOrdered) do
			if utils:IsValidVariableName(savedVar) then
				_G[savedVar] = utils:Deepcopy(backupTable.savedVars[savedVar])
			end
		end

		profileTable.pendingBackup = nil
		collectgarbage()
	end
end

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
		error("Error: private:ApplyDefaults #1")
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
	-- // check the profiles (& backups TDLATER) to make sure the Ordered tables and their data counterpart are correct

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
end

function data:Initialize()
	-- NysToDoListBackupDB
	NysToDoListBackupDB = type(NysToDoListBackupDB) ~= "table" and {} or NysToDoListBackupDB
	data.db = utils:Deepcopy(NysToDoListBackupDB)

	-- defaults
	private:ApplyDefaults(data.db, private:GetDefaults())
	private:VerifyIntegrity()

	-- free up memory
	NysToDoListBackupDB = nil
	collectgarbage()

	-- locales (we have to wait for the ADDON_LOADED event before we can use the "L" table)
	data.backupTypesDisplayNames = {
		[data.backupTypes.autoDaily] = L["Automatic"].." ("..L["Daily"]..")",
		[data.backupTypes.autoWeekly] = L["Automatic"].." ("..L["Weekly"]..")",
		[data.backupTypes.autoPreApplyBackup] = L["Automatic"].." ("..L["Pre-Backup"]..")",
		[data.backupTypes.manual] = L["Manual"],
	}

	-- default for Nys_ToDoList
	if not data:GetCurrentProfile() then
		local profileID = data:CreateNewProfile("Ny's To-Do List", false, { "NysToDoListDB" })
		data:SetCurrentProfile(profileID, false)
	end
end

function data:Uninitialize()
	NysToDoListBackupDB = data.db -- back to the global env to be saved
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

---@param refreshList boolean Defaults to true
---@return boolean success
function data:SetCurrentProfile(profileID, refreshList)
	if type(refreshList) ~= "boolean" then refreshList = true end
	local profileTable = data:GetValidProfile(profileID)

	if profileTable then
		data.db.currentProfile = profileID
		if refreshList then
			list:Refresh()
		end
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
		and type(backupTable.addonName) == "string" -- TDLATER
		and type(backupTable.addonVersion) == "string" -- TDLATER
		and type(backupTable.timestamp) == "number"
		and backupTable.timestamp >= 0
		and type(backupTable.savedVarsOrdered) == "table"
		and #backupTable.savedVarsOrdered > 0
		and type(backupTable.savedVars) == "table"
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
		pendingBackup = nil,
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
	if not core.listLoaded then
		return
	end

	for profileID, profileTable in data:ForEachProfile() do
		if data:IsProfileRelevant(profileID) then
			if type(profileTable.autoSaveInfos) ~= "table" then profileTable.autoSaveInfos = {} end
			local infos = profileTable.autoSaveInfos

			if type(infos.lastDaily) ~= "number" then infos.lastDaily = -1 end
			if type(infos.lastWeekly) ~= "number" then infos.lastWeekly = -7 end

			local yday = date("*t").yday

			local deltaDaily = ((yday - infos.lastDaily) + 365) % 365
			local deltaWeekly = ((yday - infos.lastWeekly) + 365) % 365

			if deltaDaily >= 1 then
				infos.lastDaily = yday
				data:ScrollProfileBackupType(profileID, data.backupTypes.autoDaily, 1)
				data:MakeBackup(profileID, data.backupTypes.autoDaily, 1, true)
			end

			if deltaWeekly >= 7 then
				infos.lastWeekly = yday
				data:ScrollProfileBackupType(profileID, data.backupTypes.autoWeekly, 1)
				data:MakeBackup(profileID, data.backupTypes.autoWeekly, 1, true)
			end
		end
	end
end

--/*******************/ Backups Management /*************************/--

function data:GetBackupDisplayName(backupTable, full)
	if not data:IsValidBackupTable(backupTable) then
		print("Error: data:GetBackupDisplayName #1")
		return
	end

	local timestampFormatted = date("%d-%b-%y %X", backupTable.timestamp)

	if full then
		return timestampFormatted.." - "..backupTable.addonName.." ("..backupTable.addonVersion..")"
	else
		return timestampFormatted
	end
end

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

	-- TDLATER only profileID.name or new addons list
	local addonLoaded = (C_AddOns.IsAddOnLoaded("Nys_ToDoList") and "Nys_ToDoList") or false
	if not addonLoaded then
		print("Error: private:CreateNewBackup #4 (addon not loaded)")
		return
	end

	-- @see data:IsValidBackupTable
	local backupTable = {
		addonName = tostring(C_AddOns.GetAddOnMetadata(addonLoaded, "Title")),
		addonVersion = tostring(C_AddOns.GetAddOnMetadata(addonLoaded, "Version")),
		timestamp = time(),
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
	if not profileBackupTypeTable or not next(profileBackupTypeTable) then
		return -- we don't need to scroll an invalid/empty table
	end

	for i = 1, scrollCount, 1 do
		for backupSlot = data.backupCounts[backupType], 1, -1 do
			profileBackupTypeTable[backupSlot] = profileBackupTypeTable[backupSlot-1]
		end
	end

	collectgarbage()
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

		if not forced then
			pcall(function()
				UIErrorsFrame:AddMessage(L["Backup Created"], YELLOW_FONT_COLOR:GetRGB())
			end)
		end

		return true
	end

	local backupTable = data:GetValidBackup(profileID, backupType, backupSlot)
	if backupTable and not forced then
		data:CreateStaticPopup(
			L["OVERWRITE this backup now?"].."\n".."\""..data:GetBackupDisplayName(backupTable, true).."\"".."\n\n("..L["You cannot undo this action"]..")",
			nil,
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
			L["DELETE this backup now?"].."\n".."\""..data:GetBackupDisplayName(backupTable, true).."\"".."\n\n("..L["You cannot undo this action"]..")",
			nil,
			function()
				local profileBackupTypeTable = data:GetValidProfileBackupType(profileID, backupType)
				if not profileBackupTypeTable then
					print("Error: data:DeleteBackup #1")
					return
				end

				profileBackupTypeTable[backupSlot] = nil
				collectgarbage()

				list:Refresh()

				pcall(function()
					UIErrorsFrame:AddMessage(L["Backup Deleted"], YELLOW_FONT_COLOR:GetRGB())
				end)
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
			L["APPLY this backup now?"].."\n".."\""..data:GetBackupDisplayName(backupTable, true).."\"".."\n\n** "..L["This action will reload your UI"].." **",
			core.listLoaded and utils:SafeStringFormat(L["The current data will be backed up under the %s section"]..".", "\""..data.backupTypesDisplayNames[data.backupTypes.autoPreApplyBackup].."\"") or nil,
			function()
				-- recheck validity because we waited for an user action
				backupTable = data:GetValidBackup(profileID, backupType, backupSlot)
				if not backupTable then
					print("Error: data:ApplyBackup #1")
					return
				end

				if core.listLoaded then
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
				else
					-- mark the addons to be loaded on the next reload, save the backup that will be applied on reload, and reload
					local addonToLoad = "Nys_ToDoList" -- TDLATER addons...
					local loaded, reason = C_AddOns.LoadAddOn(addonToLoad)
					if not loaded then
						if reason == "DISABLED" then
							C_AddOns.EnableAddOn(addonToLoad)
						else
							print("Error: data:ApplyBackup #3 - "..tostring(tostring(ADDON_LOAD_FAILED):format(addonToLoad, reason)))
							return
						end
					end

					-- note: we just went through data:GetValidBackup successfully, so we know the profile is valid
					local profileTable = data:GetValidProfile(profileID)
					profileTable.pendingBackup = utils:Deepcopy(backupTable)
				end

				ReloadUI()
			end
		)
		return true
	end
	return false
end

--/*******************/ Other /*************************/--

function data:CreateStaticPopup(text, subText, onAccept, showAlert)
	local disabled = false
	StaticPopup_Hide("NysTDLBackup_StaticPopupDialog")
	StaticPopupDialogs["NysTDLBackup_StaticPopupDialog"] = {
		text = text,
		subText = subText,
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
		preferredIndex = 3,
		OnHide = function()
			disabled = true
		end
	}
	StaticPopup_Show("NysTDLBackup_StaticPopupDialog")
end
