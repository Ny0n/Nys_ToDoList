-- luacheck: ignore 111 211 212

--/*******************/ IMPORTS /*************************/--

-- Primary aliases

local core = NysTDL.core
local libs = NysTDL.libs
local chat = NysTDL.chat
local database = NysTDL.database
local dataManager = NysTDL.dataManager
local enums = NysTDL.enums
local events = NysTDL.events
local importexport = NysTDL.importexport
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

-- Secondary aliases

local L = libs.L
local AceConfigDialog = libs.AceConfigDialog
local addonName = core.addonName

--/*******************************************************/--

---Tests function for me :p (callable with macros in-game)
---@param nb number
---@param ... any
function NysTDL:Tests(nb, ...)
	nb = nb or 0
	if nb == 0 then
		print((select(4, GetBuildInfo())))
	elseif nb == 1 then
		AceConfigDialog:Open(addonName)
	elseif nb == 2 then
		-- mainFrame:Toggle()
		-- UIFrameFadeOut(tdlFrame, 2)
		-- print(tdlFrame.fadeInfo.finishedFunc)
		-- tdlFrame.fadeInfo.finishedFunc = function(arg1)
		-- print("hey")
		-- end
		-- print(tdlFrame.fadeInfo.finishedFunc)

		importexport:LaunchExportProcess()
	elseif nb == 3 then
		importexport:ShowIEFrame(true)

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
		NysTDL.tutorialsManager:ResetTuto("backup")

		-- -- ITEM EXPLOSION
		-- local refreshID = dataManager:SetRefresh(false)

		-- local itemTabID, itemCatID
		-- for tabID,tabData in dataManager:ForEach(enums.tab) do
		-- 	if tabData.name == "All" then
		-- 		itemCatID = dataManager:CreateCategory("EXPLOSION", tabID)
		-- 		itemTabID = tabID
		-- 	end
		-- end
		-- for i = 1, 100 do
		-- 	dataManager:CreateItem(tostring(i), itemTabID, itemCatID)
		-- end

		-- -- for i=1,2000 do
		-- -- 	dataManager:Undo()
		-- -- end

		-- dataManager:SetRefresh(true, refreshID)

		-- mainFrame:Refresh()
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

local function tests()
	-- local macroBtn = CreateFrame("Button", "myMacroButton", UIParent, "InsecureActionButtonTemplate")
	-- macroBtn:SetAttribute("type1", "macro") -- left click causes macro
	-- macroBtn:SetAttribute("macrotext1", "/s hey!") -- text for macro on left click
	-- macroBtn:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	-- macroBtn:SetSize(150, 50)
	-- macroBtn:SetText("btn1")
	-- macroBtn:HookScript("OnClick", function()
	-- 	-- TargetUnit(UnitName("player"))
	-- 	print(1)
	-- end)
	-- macroBtn:Show()
	hooksecurefunc("SecureActionButton_OnClick", function()
		print("listen!")
	end)
	-- local btn = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
	-- btn:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
	-- btn:SetSize(150, 50)
	-- btn:SetText("btn1")
	-- btn:SetScript("OnClick", function()
	-- 	SecureActionButton_OnClick(macroBtn, "LeftButton", 1)
	-- end)
	-- Create the macro to use

local myMacro = [=[
/tar frostwall
]=]

	-- Create the secure frame to activate the macro
	local frame = CreateFrame("Button", "myMacroButton", UIParent, "SecureActionButtonTemplate");
	frame:SetPoint("CENTER")
	frame:SetSize(100, 100);
	-- frame:SetAttribute("type1", "target") -- left click causes macro
	-- frame:SetAttribute("unit", "frostwall") -- text for macro on left click
	frame:SetAttribute("type", "macro")
	frame:SetAttribute("macrotext", myMacro);
	frame:RegisterForClicks("LeftButtonDown");
end

-- table.insert(core.Event_OnInitialize_Start, tests)
