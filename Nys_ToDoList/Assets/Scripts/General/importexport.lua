--/*******************/ IMPORTS /*************************/--

-- File init

local impexp = NysTDL.impexp
NysTDL.impexp = impexp

-- Primary aliases

local libs = NysTDL.libs
local enums = NysTDL.enums
local utils = NysTDL.utils
local widgets = NysTDL.widgets
local dataManager = NysTDL.dataManager

-- Secondary aliases

local L = libs.L
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
function impexp:ShowIEFrame(title, statusText, data)
	local frame = AceGUI:Create("Frame")
	frame:SetTitle(title or "")
	frame:SetStatusText(statusText or "")
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
			elementInfo,
			...
		}
	]]

	-- ...

	-- // Part 2: Replace all IDs by new ones
	local idMap = {
		-- [importID] = dataManager:NewID(),
		-- ...
	}


	-- // Part 3: Adding the processed data into the list
	local success, psuccess
	for _,elementInfo in ipairs(data) do
		psuccess = pcall(function() -- we protect the code from potential "ID not found" errors
			if elementInfo.enum == enums.item then -- item
				success = not not dataManager:AddItem(elementInfo.ID, elementInfo.data)
			elseif elementInfo.enum == enums.category then -- category
				success = not not dataManager:AddCategory(elementInfo.ID, elementInfo.data)
			elseif elementInfo.enum == enums.tab then -- tab
				success = not not dataManager:AddTab(elementInfo.ID, elementInfo.data, elementInfo.isGlobal)
			end
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
	local exportData = {}

	-- // Part 3: Find all of the data related to the tabs we want to export, process its info, and add it to the export table
	for _,tabID in ipairs(tabIDs) do
		tinsert(exportData, private:GenerateInfoTable(tabID)) -- tabs
		for catID in dataManager:ForEach(enums.category, tabID) do
			tinsert(exportData, private:GenerateInfoTable(catID)) -- categories
		end
		for itemID in dataManager:ForEach(enums.item, tabID) do
			tinsert(exportData, private:GenerateInfoTable(itemID)) -- items
		end
	end

	-- // Part 4: Export the table and show it to the player
	local encodedData = impexp:Export(exportData)
	if encodedData then
		print("Export successful")
		local length = #encodedData
		local subtitle = "Characters: "..tostring(length)..", "..string.format("Size: %.1fKB", length/1024)
		impexp:ShowIEFrame(L["Export"], subtitle, encodedData)
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
