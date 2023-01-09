--/*******************/ IMPORTS /*************************/--

-- File init

local impexp = NysTDL.impexp
NysTDL.impexp = impexp

-- Primary aliases

local libs = NysTDL.libs
local core = NysTDL.core
local enums = NysTDL.enums
local utils = NysTDL.utils
local widgets = NysTDL.widgets
local database = NysTDL.database
local mainFrame = NysTDL.mainFrame
local tabsFrame = NysTDL.tabsFrame
local dataManager = NysTDL.dataManager
local resetManager = NysTDL.resetManager

-- Secondary aliases

local L = libs.L
local AceConfigRegistry = libs.AceConfigRegistry
local AceSerializer = libs.AceSerializer
local LibDeflate = libs.LibDeflate
local AceGUI = libs.AceGUI

--/*******************************************************/--

-- Variables

local private = {}

-- // WoW & Lua APIs

local wipe, select = wipe, select
local type, pairs, ipairs = type, pairs, ipairs
local tinsert, tremove = table.insert, table.remove

---@class impexp.deflateMethod
impexp.deflateMethod = {
	PRINT = 1,
	WOW_ADDON_CHANNEL = 2,
	WOW_CHAT_CHANNEL = 3,
 }

---Exports as a string the given data, using the given deflate method.
---Order of operation: Serialize -> Compress -> Encode -> return
---@param data any
---@param method impexp.deflateMethod
---@return string encodedData
function impexp:Export(data, method)
	if type(data) == "nil" then return end

    local serialized = AceSerializer:Serialize(data)
	if not serialized then return end

    local compressed = LibDeflate:CompressDeflate(serialized, {level = 9})
	if not compressed then return end

	local encoded
	if method == impexp.deflateMethod.WOW_ADDON_CHANNEL then
		encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)
	elseif method == impexp.deflateMethod.WOW_CHAT_CHANNEL then
		encoded = LibDeflate:EncodeForWoWChatChannel(compressed)
	else
		encoded = LibDeflate:EncodeForPrint(compressed)
	end

    return encoded
end

---Imports the given text, using the given deflate method.
---Order of operation: Decode -> Decompress -> Deserialize -> return
---@param text string
---@param method impexp.deflateMethod
---@return any decodedData
function impexp:Import(text, method)
	if type(text) ~= "string" then return end

	local decoded
	if method == impexp.deflateMethod.WOW_ADDON_CHANNEL then
		decoded = LibDeflate:DecodeForWoWAddonChannel(text)
	elseif method == impexp.deflateMethod.WOW_CHAT_CHANNEL then
		decoded = LibDeflate:DecodeForWoWChatChannel(text)
	else
		decoded = LibDeflate:DecodeForPrint(text)
	end
    if not decoded then return end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return end

    local success, data = AceSerializer:Deserialize(decompressed)
    if not success then return end

    return data
end

function impexp:TryToImport(editbox)
	if not editbox or not editbox.GetText then return end

	local success
	local decodedData = impexp:Import(editbox:GetText())
	if decodedData then
		success = private:LaunchImportProcess(decodedData)
	else
		success = false
	end

	if success then
		print("Import successful")
	else
		print("Import error")
	end

	collectgarbage()
	return success
end

---Shows an editbox where the player can copy or paste serialized data
function impexp:ShowIEFrame(title, data)
	local frame = AceGUI:Create("Frame")
	frame:SetTitle(title or "")
	frame:SetLayout("Fill")
	frame:SetWidth(525)
	frame:SetHeight(375)
	frame:SetCallback("OnClose", function(widget)
		AceGUI:Release(widget)
	end)

	local editbox = AceGUI:Create("MultiLineEditBox")
	editbox.editBox:SetFontObject("GameFontHighlightSmall")
	editbox:SetLabel("")
	editbox:SetFullWidth(true)
	editbox:SetFullHeight(true)
	frame:AddChild(editbox)

	local function refreshStatusText()
		local text = editbox.editBox:GetText() or ""
		local length = #text
		local subtitle = "Characters: "..tostring(length)..", "..string.format("Size: %.1fKB", length/1024)
		frame:SetStatusText(subtitle)
	end

	editbox.editBox:HookScript("OnTextChanged", refreshStatusText)
	refreshStatusText()

	if type(data) == "string" then
		editbox:SetText(data)
		editbox.button:SetEnabled(true)
		editbox.button:SetText(L["Ctrl+A"])
		editbox.button:SetScript("OnClick", function()
			widgets:SetFocusEditBox(editbox, true)
		end)
	else
		editbox.button:SetEnabled(false)
		editbox.button:SetText(L["Import"])
		editbox.button:SetScript("OnClick", function()
			if impexp:TryToImport(editbox) then
				frame:Hide()
			end
		end)
	end
end

--/***************/ Data Import /*****************/--

function private:LaunchImportProcess(data)
	-- // Part 1: Validate the data
	if type(data) ~= "table" then return end
	--[[
		data = {
			orderedTabIDs = {
				[true] = {...},
				[false] = {...},
			},
			elements = {
				elementInfo = {
					ID = ID,
					enum = enum,
					isGlobal = isGlobal,
					data = utils:Deepcopy(data),
				},
				...
			}
		}
	]]

	-- ...

	-- // Part 2: Replace all IDs by new ones
	local idMap = {
		-- [importID] = dataManager:NewID(),
		-- ...
	}

	-- helpers
	local function replacement(ID)
		if not ID then return end
		local r = idMap[ID]
		if not r then
			r = dataManager:NewID()
			idMap[ID] = r
		end
		return r
	end
	local function replaceTable(tbl, isKey)
		local temp = utils:Deepcopy(tbl)
		wipe(tbl)

		if isKey then
			for ID in pairs(temp) do
				tbl[replacement(ID)] = true
			end
		else
			for _,ID in ipairs(temp) do
				tinsert(tbl, replacement(ID))
			end
		end
	end

	-- tabs order
	for i=1,2 do
		local isGlobal = i==2
		replaceTable(data.orderedTabIDs[isGlobal])
	end

	-- elements
	for _,elementInfo in ipairs(data.elements) do
		elementInfo.ID = replacement(elementInfo.ID)
		local data = elementInfo.data
		if elementInfo.enum == enums.item then -- item
			data.originalTabID = replacement(data.originalTabID)
			replaceTable(data.tabIDs, true)
			data.catID = replacement(data.catID)
		elseif elementInfo.enum == enums.category then -- category
			data.originalTabID = replacement(data.originalTabID)
			replaceTable(data.tabIDs, true)
			replaceTable(data.closedInTabIDs, true)
			data.parentCatID = replacement(data.parentCatID)
			replaceTable(data.orderedContentIDs)
		elseif elementInfo.enum == enums.tab then -- tab
			replaceTable(data.orderedCatIDs)
			replaceTable(data.shownIDs, true)
		end
	end

	-- // Part 2.5: We save the tabs to delete if the user chose to override its data with the import
	local toDelete = {}
	for i=1,2 do
		local isGlobal = i==2

		if #data.orderedTabIDs[isGlobal] > 0 and true then -- if there are things in this category TODO and CHECK IF WE SELECTED OVERRIDE OR NOT
			for tabID in dataManager:ForEach(enums.tab, isGlobal) do
				tinsert(toDelete, tabID)
			end
		end
	end

	-- // Part 3: Adding the processed data into the list
	dataManager.authorized = false

	-- tabs order
	for i=1,2 do
		local isGlobal = i==2
		local orderedTabIDs = (select(3, dataManager:GetData(isGlobal))).orderedTabIDs

		for _,tabID in ipairs(data.orderedTabIDs[isGlobal]) do
			tinsert(orderedTabIDs, tabID)
		end
	end

	-- elements
	local success, psuccess
	for _,elementInfo in ipairs(data.elements) do
		psuccess = pcall(function() -- we protect the code from potential "ID not found" errors
			local itemsList, categoriesList, tabsList = dataManager:GetData(elementInfo.isGlobal)
			if elementInfo.enum == enums.item then -- item
				itemsList[elementInfo.ID] = elementInfo.data
			elseif elementInfo.enum == enums.category then -- category
				categoriesList[elementInfo.ID] = elementInfo.data
			elseif elementInfo.enum == enums.tab then -- tab
				tabsList[elementInfo.ID] = elementInfo.data
			end
			success = true
		end)

		if psuccess then
			if not success then
				print("error adding element")
			else
				-- ...
			end
		else
			print("pcall error adding element")
		end
	end

	-- // Part 3.5: Delete what we saved
	local nbToUndo = 0
	for _,tabID in ipairs(toDelete) do
		-- TDLATER dataManager clearing = true/false et faire gaffe aux protected contents si je les réajoute (faudrait force delete)
		local result, nb = dataManager:DeleteTab(tabID)
		if result or nb > 0 then
			nbToUndo = nbToUndo + 1
		end
	end
	if nbToUndo > 0 then
		dataManager:AddUndo(nbToUndo)
	end

	dataManager.authorized = true

	-- // Last Part: Refresh!
	local wasShown = mainFrame:GetFrame():IsShown()
	database:ProfileChanged()
	mainFrame:GetFrame():SetShown(wasShown)

	return true
end

function impexp:LaunchExportProcess(tabIDs)
	-- // Part 1: Validate the tabIDs
	if type(tabIDs) ~= "table" then return end
	--[[
		tabIDs = {
			ID,
			ID,
			...
		}
	]]

	-- // Part 2: Create the export table
	local exportData = {
		orderedTabIDs = {
			[true] = {}, -- global
			[false] = {}, -- profile
		},
		elements = {},
	}

	-- helpers
	local function isTabInExport(tabID)
		return utils:HasValue(tabIDs, tabID)
	end
	local function removeUnusedTabIDs(tbl, isKey)
		local temp = utils:Deepcopy(tbl)
		wipe(tbl)

		if isKey then
			for tabID in pairs(temp) do
				if isTabInExport(tabID) then
					tbl[tabID] = true
				end
			end
		else
			for _,tabID in ipairs(temp) do
				if isTabInExport(tabID) then
					tinsert(tbl, tabID)
				end
			end
		end
	end

	-- // Part 3: Find all of the data related to the tabs we want to export, process its info, and add it to the export table
	-- tabs order
	for i=1,2 do
		local isGlobal = i==2
		exportData.orderedTabIDs[isGlobal] = utils:Deepcopy((select(3, dataManager:GetData(isGlobal))).orderedTabIDs)
		removeUnusedTabIDs(exportData.orderedTabIDs[isGlobal])
	end

	-- elements
	for _,tabID in ipairs(tabIDs) do
		tinsert(exportData.elements, private:GenerateInfoTable(tabID)) -- tabs
		for catID in dataManager:ForEach(enums.category, tabID, true) do
			tinsert(exportData.elements, private:GenerateInfoTable(catID)) -- categories
		end
		for itemID in dataManager:ForEach(enums.item, tabID, true) do
			tinsert(exportData.elements, private:GenerateInfoTable(itemID)) -- items
		end
	end

	-- // Part 4: Process the shownIDs
	for _,elementInfo in ipairs(exportData.elements) do
		local data = elementInfo.data
		if elementInfo.enum == enums.item then -- item
			removeUnusedTabIDs(data.tabIDs, true)
		elseif elementInfo.enum == enums.category then -- category
			removeUnusedTabIDs(data.tabIDs, true)
			removeUnusedTabIDs(data.closedInTabIDs, true)
		elseif elementInfo.enum == enums.tab then -- tab
			local temp = {}
			for _,catID in ipairs(data.orderedCatIDs) do -- those are catIDs, not tabIDs (so we find and use their originalTabID)
				local originalTabID = (select(3, dataManager:Find(catID))).originalTabID
				if isTabInExport(originalTabID) then
					tinsert(temp, catID)
				end
			end
			data.orderedCatIDs = temp

			removeUnusedTabIDs(data.shownIDs, true)
		end
	end

	-- // Last Part: Export the table and show it to the player
	local encodedData = impexp:Export(exportData)
	if encodedData then
		print("Export successful")
		impexp:ShowIEFrame(L["Export"], encodedData)
	else
		print("Export error")
	end

	collectgarbage()
end

function private:GenerateInfoTable(ID)
	local enum, isGlobal, data = dataManager:Find(ID)
	return {
		ID = ID,
		enum = enum,
		isGlobal = isGlobal,
		data = utils:Deepcopy(data),
	}
end
