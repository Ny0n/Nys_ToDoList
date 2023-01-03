-- luacheck: ignore 111 211 212

--/*******************/ IMPORTS /*************************/--

-- Primary aliases

local libs = NysTDL.libs
local chat = NysTDL.chat
local database = NysTDL.database
local dataManager = NysTDL.dataManager
local enums = NysTDL.enums
local events = NysTDL.events
local impexp = NysTDL.impexp
local migration = NysTDL.migration
local optionsManager = NysTDL.optionsManager
local resetManager = NysTDL.resetManager
local tutorialsManager = NysTDL.tutorialsManager
local utils = NysTDL.utils
local databroker = NysTDL.databroker
local dragndrop = NysTDL.dragndrop
local mainFrame = NysTDL.mainFrame
local tabsFrame = NysTDL.tabsFrame
local widgets = NysTDL.widgets
local core = NysTDL.core

-- Secondary aliases

local L = libs.L
local AceConfigDialog = libs.AceConfigDialog
local addonName = core.addonName

--/*******************************************************/--

---Tests function for me :p (callable with macros in-game)
---@param nb number
---@param ... any
function NysTDL:Tests(nb, ...)

	-- NysTDL.dataManager:Find()

	if nb == 1 then
		AceConfigDialog:Open(addonName)
	elseif nb == 2 then
		-- mainFrame:Toggle()
		-- UIFrameFadeOut(tdlFrame, 2)
		-- print(tdlFrame.fadeInfo.finishedFunc)
		-- tdlFrame.fadeInfo.finishedFunc = function(arg1)
		-- print("hey")
		-- end
		-- print(tdlFrame.fadeInfo.finishedFunc)

		-- impexp:ShowIEFrame(L["Export"], "", "")
		-- do return end

		local tabIDs = {}

		-- for tabID in dataManager:ForEach(enums.tab, false) do
		-- 	table.insert(tabIDs, tabID)
		-- end

		local tabID = dataManager:FindFirstIDByName("Daily", enums.tab)
		table.insert(tabIDs, tabID)

		impexp:LaunchExportProcess(tabIDs)
	elseif nb == 3 then
		impexp:ShowIEFrame(L["Import"])

		-- core:AddonUpdated()
		-- for tabID, tabData in dataManager:ForEach(enums.tab, false) do
		--   if next(tabData.reset.days) then
		--     print(">================<")
		--     print(tabData.name.." tab next reset times:")
		-- 		for timerResetID,targetTime in pairs(tabData.reset.nextResetTimes) do
		--       resetManager:PrintTimeDiff(timerResetID, targetTime)
		-- 		end
		--   end
		-- end
		-- print("<================>")
	elseif nb == 4 then
		-- ITEM EXPLOSION
		local refreshID = dataManager:SetRefresh(false)

		local itemTabID, itemCatID
		for tabID,tabData in dataManager:ForEach(enums.tab) do
			if tabData.name == "All" then
				itemCatID = dataManager:CreateCategory("EXPLOSION", tabID)
				itemTabID = tabID
			end
		end
		for i = 1, 100 do
			dataManager:CreateItem(tostring(i), itemTabID, itemCatID)
		end

		-- for i=1,2000 do
		-- 	dataManager:Undo()
		-- end

		dataManager:SetRefresh(true, refreshID)

		mainFrame:Refresh()
	elseif nb == 5 then
		migration:TestFunc()
	end
	print("--Nys_Tests--")
end

local backdrop_tests = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	-- edgeFile = "Interface\\BUTTONS\\UI-Debuff-Border",
	-- edgeFile = "Interface\\ARENAENEMYFRAME\\UI-Arena-Border",
	-- edgeFile = "Interface\\PaperDollInfoFrame\\UI-GearManager-Border",
	-- edgeFile = "Interface\\DialogFrame\\UI-DialogBox-TestWatermark-Border",
	-- edgeFile = "Interface\\GLUES\\COMMON\\Glue-Tooltip-Border",
	-- edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border-Corrupted",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = false, tileSize = 1, edgeSize = 10,
	insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

-- // Secure action button test
-- local macroBtn = CreateFrame("Button", "myMacroButton", UIParent, "SecureActionButtonTemplate")
-- macroBtn:SetAttribute("type1", "macro") -- left click causes macro
-- macroBtn:SetAttribute("macrotext1", "/say test") -- text for macro on left click
-- macroBtn:SetSize(100, 100)
-- macroBtn:SetPoint("CENTER")
-- macroBtn:RegisterForClicks("LeftButtonDown")
