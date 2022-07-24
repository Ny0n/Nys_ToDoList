-- luacheck: ignore 111 211 212

-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local libs = addonTable.libs
local core = addonTable.core
local enums = addonTable.enums
local dataManager = addonTable.dataManager
local mainFrame = addonTable.mainFrame

-- Variables
local L = libs.L
local AceConfigDialog = libs.AceConfigDialog

-- ============================================ --

-- Tests function (for me :p) (callable with macros in-game)
function Nys_Tests(nb, ...)
	if nb == 1 then
		AceConfigDialog:Open(addonName)
	elseif nb == 2 then
		mainFrame:Toggle()
		-- UIFrameFadeOut(tdlFrame, 2)
		-- print(tdlFrame.fadeInfo.finishedFunc)
		-- tdlFrame.fadeInfo.finishedFunc = function(arg1)
		-- print("hey")
		-- end
		-- print(tdlFrame.fadeInfo.finishedFunc)
	elseif nb == 3 then
		core:AddonUpdated()
		-- migration:TestFunc()
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
