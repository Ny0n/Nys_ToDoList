--/*******************/ IMPORTS /*************************/--

-- File init

local importexport = NysTDL.importexport
NysTDL.importexport = importexport

-- Primary aliases

local libs = NysTDL.libs
local core = NysTDL.core
local chat = NysTDL.chat
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

---@class importexport.deflateMethod
importexport.deflateMethod = {
	PRINT = 1,
	WOW_ADDON_CHANNEL = 2,
	WOW_CHAT_CHANNEL = 3,
 }

local IEFrame
local selectedTabIDs = {}
local TabsSelectDropDown = nil
local globalButton, profileButton, titleButton

importexport.dataToOverrideOnImport = 1
importexport.dataToOverrideOnImportTypes = {
	L["None"], -- [1]
	L["All"], -- [2]
	L["Global tabs"], -- [3]
	L["Profile tabs"], -- [4]
 }

local prefixes = { "!NysTDL!" } -- I'm using a table for backwards compatibility, in case the prefix changes. It's the first one in the table that is used for exports

function private:CheckPrefixes(prefixed)
	for _,prefix in ipairs(prefixes) do
		local encoded, count = string.gsub(prefixed, "^"..prefix, "", 1)
		if count == 1 then
			return encoded
		end
	end
	return false
end

---Exports as a string the given data, using the given deflate method.
---Order of operation: Serialize -> Compress -> Encode -> return
---@param data any
---@param method importexport.deflateMethod
---@return string encodedData
function importexport:Export(data, method)
	if type(data) == "nil" then return end

    local serialized = AceSerializer:Serialize(data)
	if not serialized then return end

    local compressed = LibDeflate:CompressDeflate(serialized, {level = 9})
	if not compressed then return end

	local encoded
	if method == importexport.deflateMethod.WOW_ADDON_CHANNEL then
		encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)
	elseif method == importexport.deflateMethod.WOW_CHAT_CHANNEL then
		encoded = LibDeflate:EncodeForWoWChatChannel(compressed)
	else
		encoded = LibDeflate:EncodeForPrint(compressed)
	end

	local prefixed = prefixes[1]..encoded
	if not prefixed then return end

    return prefixed
end

---Imports the given encoded text, using the given deflate method.
---Order of operation: Decode -> Decompress -> Deserialize -> return
---@param text string
---@param method importexport.deflateMethod
---@return any decodedData
function importexport:Import(prefixed, method)
	if type(prefixed) ~= "string" then return end

	local encoded = private:CheckPrefixes(prefixed)
	if not encoded then return end

	local compressed
	if method == importexport.deflateMethod.WOW_ADDON_CHANNEL then
		compressed = LibDeflate:DecodeForWoWAddonChannel(encoded)
	elseif method == importexport.deflateMethod.WOW_CHAT_CHANNEL then
		compressed = LibDeflate:DecodeForWoWChatChannel(encoded)
	else
		compressed = LibDeflate:DecodeForPrint(encoded)
	end
    if not compressed then return end

    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then return end

    local success, data = AceSerializer:Deserialize(serialized)
    if not success then return end

    return data
end

function importexport:TryToImport(editbox)
	if not editbox or not editbox.GetText then return end

	local success
	local decodedData = importexport:Import(editbox:GetText())
	if decodedData then
		success = private:LaunchImportProcess(decodedData)
	else
		success = false
	end

	if success then
		chat:PrintForced(L["Import successful"])
	else
		chat:PrintForced(L["Invalid import text"])
	end

	collectgarbage()
	return success
end

---Shows an editbox where the player can copy or paste serialized data
function importexport:ShowIEFrame(isImport, data)
	if IEFrame then return end

	IEFrame = AceGUI:Create("Frame")
	IEFrame:SetTitle(isImport and L["Import"] or L["Export"])
	IEFrame:SetLayout("Fill")
	IEFrame:SetWidth(525)
	IEFrame:SetHeight(375)
	IEFrame:SetCallback("OnClose", function(widget)
		AceGUI:Release(widget)
		IEFrame = nil
	end)

	local editbox = AceGUI:Create("MultiLineEditBox")
	editbox.editBox:SetFontObject("GameFontHighlightSmall")
	editbox:SetLabel("")
	editbox:SetFullWidth(true)
	editbox:SetFullHeight(true)
	IEFrame:AddChild(editbox)

	local function refreshStatusText()
		local text = editbox.editBox:GetText() or ""
		local length = #text
		local subtitle = utils:SafeStringFormat(L["Characters: %s, Size: %sKB"], tostring(length), string.format("%.1f", length/1024))
		IEFrame:SetStatusText(subtitle)
	end

	editbox.editBox:HookScript("OnTextChanged", function()
		refreshStatusText()

		-- hack to fix a scroll bug when we Ctrl+V something big
		local v = editbox.scrollFrame:GetVerticalScroll()
		editbox.scrollFrame:SetVerticalScroll(0)
		editbox.scrollFrame:SetVerticalScroll(v)
	end)
	refreshStatusText()

	if isImport then
		editbox.button:SetEnabled(false)
		editbox.button:SetText(L["Import"])
		editbox.button:SetScript("OnClick", function()
			if importexport:TryToImport(editbox) then
				IEFrame:Hide()
			end
		end)
		editbox.editBox:HookScript("OnTextChanged", function()
			if editbox.editBox:GetText() == "" then
				editbox.button:SetEnabled(false)
			end
		end)
	else
		editbox:SetText(type(data) == "string" and data or "")
		editbox.button:SetEnabled(true)
		editbox.button:SetText(L["Ctrl+A"])
		editbox.button:SetScript("OnClick", function()
			widgets:SetFocusEditBox(editbox.editBox, true)
		end)
	end
	widgets:SetFocusEditBox(editbox.editBox, true)
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

	-- // Part 2.5: We find the tabs to delete if the user chose to override its data with the import
	local toDelete = {}
	local toOverride = importexport.dataToOverrideOnImport -- alias
	if toOverride ~= 1 then
		for i=3,4 do
			local isGlobal = i==3

			if #data.orderedTabIDs[isGlobal] > 0 and (toOverride == 2 or toOverride == i) then -- if there are things in this category of tabs (global / profile)
				for tabID in dataManager:ForEach(enums.tab, isGlobal) do
					tinsert(toDelete, tabID)
				end
			end
		end
	end

	-- // Part 3: Adding the processed data into the list
	dataManager.authorized = false

	-- save the data in case there is an unexpected error
	local g_itemsList, g_categoriesList, g_tabsList = dataManager:GetData(true)
	g_itemsList, g_categoriesList, g_tabsList = utils:Deepcopy(g_itemsList), utils:Deepcopy(g_categoriesList), utils:Deepcopy(g_tabsList)
	local p_itemsList, p_categoriesList, p_tabsList = dataManager:GetData(false)
	p_itemsList, p_categoriesList, p_tabsList = utils:Deepcopy(p_itemsList), utils:Deepcopy(p_categoriesList), utils:Deepcopy(p_tabsList)

	local success = pcall(function()
		-- tabs order
		for i=1,2 do
			local isGlobal = i==2
			local orderedTabIDs = dataManager:GetTabsLoc(isGlobal)

			for _,tabID in ipairs(data.orderedTabIDs[isGlobal]) do
				tinsert(orderedTabIDs, tabID)
			end
		end

		-- elements
		for _,elementInfo in ipairs(data.elements) do
			local itemsList, categoriesList, tabsList = dataManager:GetData(elementInfo.isGlobal)
			if elementInfo.enum == enums.item then -- item
				itemsList[elementInfo.ID] = elementInfo.data
			elseif elementInfo.enum == enums.category then -- category
				categoriesList[elementInfo.ID] = elementInfo.data
			elseif elementInfo.enum == enums.tab then -- tab
				tabsList[elementInfo.ID] = elementInfo.data
			end
		end
	end)

	if not success then
		local global, profile = NysTDL.acedb.global, NysTDL.acedb.profile
		global.itemsList, global.categoriesList, global.tabsList = g_itemsList, g_categoriesList, g_tabsList
		profile.itemsList, profile.categoriesList, profile.tabsList = p_itemsList, p_categoriesList, p_tabsList

		chat:PrintForced(L["Invalid import text"])
		return
	end

	-- // Part 3.5: Delete what we should be deleting because the user chose to override its current data
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

function importexport:LaunchExportProcess()
	if IEFrame then return end

	-- // Part 1: Validate the tabIDs
	if type(selectedTabIDs) ~= "table" then return end

	local tabIDs = {}
	for tabID, value in pairs(selectedTabIDs) do
		if value and dataManager:IsID(tabID) then
			tinsert(tabIDs, tabID)
		end
	end

	if #tabIDs <= 0 then -- no tabs selected
		return
	end

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
		exportData.orderedTabIDs[isGlobal] = utils:Deepcopy(dataManager:GetTabsLoc(isGlobal))
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
	local encodedData = importexport:Export(exportData)
	if encodedData then
		importexport:ShowIEFrame(false, encodedData)
	else
		chat:PrintForced(L["Export error"])
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

--/***************/ Tabs Selection /*****************/--

function importexport:CountSelectedTabs(isGlobal)
	local n = 0
	for tabID in pairs(selectedTabIDs) do
		if dataManager:IsID(tabID) then
			local isTabGlobal = select(2, dataManager:Find(tabID))
			if isGlobal == nil or isGlobal and isTabGlobal or not isGlobal and not isTabGlobal then
				n = n + 1
			end
		end
	end
	return n
end

function private:RefreshBaseLevel()
	local total, count = 0

	count = importexport:CountSelectedTabs(true)
	if globalButton then
		globalButton:SetText(L["Global tabs"].." ("..tostring(count)..")")
	end
	total = total + count

	count = importexport:CountSelectedTabs(false)
	if profileButton then
		profileButton:SetText(L["Profile tabs"].." ("..tostring(count)..")")
	end
	total = total + count

	-- if titleButton then
	-- 	titleButton:SetText(L["Select tabs"].." ("..tostring(total)..")")
	-- end
	UIDropDownMenu_Refresh(TabsSelectDropDown, nil, 1)

	-- refresh options buttons
	AceConfigRegistry:NotifyChange(core.addonName)
end

function importexport:OpenTabsSelectMenu()
	TabsSelectDropDown = CreateFrame("Frame", "NysTDL_importexport_TabsSelectMenu", UIParent, "UIDropDownMenuTemplate")
	UIDropDownMenu_Initialize(TabsSelectDropDown, private.TabsSelectMenuInitialize, "MENU")

	TabsSelectDropDown.OnTabChecked = function(_, tabID, _, checked)
		selectedTabIDs[tabID] = checked or nil
		private:RefreshBaseLevel()
	end

	TabsSelectDropDown.IsTabChecked = function(info)
		return not not selectedTabIDs[info.arg1]
	end

	TabsSelectDropDown.CheckAll = function(_, isGlobal)
		for tabID in dataManager:ForEach(enums.tab, isGlobal) do
			selectedTabIDs[tabID] = true
		end
		UIDropDownMenu_Refresh(TabsSelectDropDown, UIDROPDOWNMENU_MENU_VALUE, UIDROPDOWNMENU_MENU_LEVEL)
		private:RefreshBaseLevel()
	end

	TabsSelectDropDown.UncheckAll = function(_, isGlobal)
		for tabID in dataManager:ForEach(enums.tab, isGlobal) do
			selectedTabIDs[tabID] = nil
		end
		UIDropDownMenu_Refresh(TabsSelectDropDown, UIDROPDOWNMENU_MENU_VALUE, UIDROPDOWNMENU_MENU_LEVEL)
		private:RefreshBaseLevel()
	end

	TabsSelectDropDown.HideMenu = function()
		if UIDROPDOWNMENU_OPEN_MENU == TabsSelectDropDown then
			CloseDropDownMenus()
		end
	end

	-- show on the cursor position
	local scale, x, y = UIParent:GetScale(), GetCursorPosition()
	x, y = x/scale, y/scale
	ToggleDropDownMenu(1, nil, TabsSelectDropDown, "UIParent", x, y)
	private:RefreshBaseLevel()
end

function private.TabsSelectMenuInitialize(self, level)
	if not level then return end

	local info = UIDropDownMenu_CreateInfo()
	local fontObject = "GameFontHighlightSmallLeft"

	if level == 1 then
		-- title
		wipe(info)
		info.isTitle = true
		info.text = L["Select tabs"]
		info.notCheckable = true
		titleButton = UIDropDownMenu_AddButton(info, level)

		-- -- separator
		-- UIDropDownMenu_AddSeparator(level)

		wipe(info)
		info.text = CHECK_ALL
		info.func = self.CheckAll
		info.arg1 = nil
		info.notCheckable = true
		info.keepShownOnClick = true
		UIDropDownMenu_AddButton(info, level)

		wipe(info)
		info.text = UNCHECK_ALL
		info.func = self.UncheckAll
		info.arg1 = nil
		info.notCheckable = true
		info.keepShownOnClick = true
		UIDropDownMenu_AddButton(info, level)

		-- global tabs submenu
		wipe(info)
		info.text = L["Global tabs"]
		info.disabled = not dataManager:HasGlobalData()
		info.notCheckable = true
		info.keepShownOnClick = true
		info.hasArrow = true
		info.value = "global"
		-- info.icon = enums.icons.global.info()
		-- info.tCoordLeft, info.tCoordRight, info.tCoordTop, info.tCoordBottom = unpack(enums.icons.global.texCoords)
		-- info.iconXOffset = -20
		info.fontObject = fontObject
		info.minWidth = widgets:GetWidth(info.text, info.fontObject) + 45
		globalButton = UIDropDownMenu_AddButton(info, level)
		-- _G[globalButton:GetName().."Icon"]:SetSize(14, 14)

		-- profile tabs submenu
		wipe(info)
		info.text = L["Profile tabs"]
		info.notCheckable = true
		info.keepShownOnClick = true
		info.hasArrow = true
		info.value = "profile"
		-- info.icon = enums.icons.profile.info()
		-- info.tCoordLeft, info.tCoordRight, info.tCoordTop, info.tCoordBottom = unpack(enums.icons.profile.texCoords)
		-- info.iconXOffset = -21
		info.fontObject = fontObject
		info.minWidth = widgets:GetWidth(info.text, info.fontObject) + 45
		profileButton = UIDropDownMenu_AddButton(info, level)
		-- _G[profileButton:GetName().."Icon"]:SetSize(12, 14)

		-- -- separator
		-- UIDropDownMenu_AddSeparator(level)

		-- -- close button
		-- wipe(info)
		-- info.notCheckable = true
		-- info.text = CLOSE
		-- info.func = self.HideMenu
		-- UIDropDownMenu_AddButton(info, level)
	elseif level == 2 then
		local isGlobal = UIDROPDOWNMENU_MENU_VALUE == "global"

		wipe(info)
		info.text = CHECK_ALL
		info.func = self.CheckAll
		info.arg1 = isGlobal
		info.notCheckable = true
		info.keepShownOnClick = true
		UIDropDownMenu_AddButton(info, level)

		wipe(info)
		info.text = UNCHECK_ALL
		info.func = self.UncheckAll
		info.arg1 = isGlobal
		info.notCheckable = true
		info.keepShownOnClick = true
		UIDropDownMenu_AddButton(info, level)

		wipe(info)
		info.keepShownOnClick = true
		info.isNotRadio = true
		info.func = self.OnTabChecked
		info.checked = self.IsTabChecked
		for tabID, tabData in dataManager:ForEach(enums.tab, isGlobal) do
			info.text = tabData.name
			info.arg1 = tabID
			UIDropDownMenu_AddButton(info, level)
		end
	end
end
