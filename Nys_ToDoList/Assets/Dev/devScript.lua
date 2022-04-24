-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local chat = addonTable.chat
local database = addonTable.database
local enums = addonTable.enums
local events = addonTable.events
local optionsManager = addonTable.optionsManager
local resetManager = addonTable.resetManager
local utils = addonTable.utils
local databroker = addonTable.databroker
local dataManager = addonTable.dataManager
local mainFrame = addonTable.mainFrame
local tabsFrame = addonTable.tabsFrame
local tutorialsManager = addonTable.tutorialsManager
local widgets = addonTable.widgets
local core = addonTable.core

-- Variables
local L = core.L

-- ============================================ --

-- Tests function (for me :p)
function Nys_Tests(yes, ...)
  if yes == 1 then -- tests profile
    optionsManager:ToggleOptions()
    -- print(mainFrame:GetFrame():GetFrameStrata())
    -- tutorialsManager:UpdateFramesVisibility()

    do return end

    NysTDL.db.profile.minimap = { hide = false, minimapPos = 241, lock = false, tooltip = true }
    NysTDL.db.profile.framePos = { point = "CENTER", relativeTo = nil, relativePoint = "CENTER", xOffset = 0, yOffset = 0 }
    NysTDL.db.profile.frameSize = { width = 340, height = 400 }
    NysTDL.db.profile.tdlButton = { ["show"] = true, ["points"] = { ["point"] = "BOTTOMRIGHT", ["relativePoint"] = "BOTTOMRIGHT", ["xOffset"] = -182.9999237060547, ["yOffset"] = 44.99959945678711 }
    }

    NysTDL.db.profile.lastLoadedTab = "ToDoListUIFrameTab2"
    NysTDL.db.profile.rememberUndo = false
    NysTDL.db.profile.autoReset = nil

    NysTDL.db.profile.showChatMessages = false
    NysTDL.db.profile.showWarnings = false
    NysTDL.db.profile.favoritesWarning = true
    NysTDL.db.profile.normalWarning = false
    NysTDL.db.profile.hourlyReminder = true

    NysTDL.db.profile.frameAlpha = 65
    NysTDL.db.profile.frameContentAlpha = 100
    NysTDL.db.profile.affectDesc = true
    NysTDL.db.profile.descFrameAlpha = 65
    NysTDL.db.profile.descFrameContentAlpha = 100

    NysTDL.db.profile.rainbow = true
    NysTDL.db.profile.rainbowSpeed = 1
    NysTDL.db.profile.weeklyDay = 4
    NysTDL.db.profile.dailyHour = 9
    NysTDL.db.profile.favoritesColor = {
      0.5720385674916013, -- [1]
      0, -- [2]
      1, -- [3]
    }
    NysTDL:ProfileChanged()
  elseif yes == 2 then
    LibStub("AceConfigDialog-3.0"):Open("Nys_ToDoListWIP")
  elseif yes == 3 then
    UIFrameFadeOut(tdlFrame, 2)
      print(tdlFrame.fadeInfo.finishedFunc)
    tdlFrame.fadeInfo.finishedFunc = function(arg1)
      print("hey")
    end
    print(tdlFrame.fadeInfo.finishedFunc)
  elseif yes == 4 then
    local catData = select(3, dataManager:Find(...))
  	for contentOrder,contentID in ipairs(catData.orderedContentIDs) do
      local enum, _, contentData = dataManager:Find(contentID)
      print(contentOrder, enum, contentData.name)
    end


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
  elseif yes == 5 then -- EXPLOSION
    local refreshID = dataManager:SetRefresh(false)

    -- local itemTabID, itemCatID
    -- for tabID,tabData in dataManager:ForEach(enums.tab) do
    --   if tabData.name == "All" then
    --     itemCatID = dataManager:CreateCategory("EXPLOSION", tabID)
    --     itemTabID = tabID
    --   end
    -- end
    -- for i = 1, 100 do
    --   dataManager:CreateItem(tostring(i), itemTabID, itemCatID)
    -- end

    for i=1,2000 do
      dataManager:Undo()
    end

  	dataManager:SetRefresh(true, refreshID)

    mainFrame:Refresh()
  elseif yes == 6 then
    -- print(unpack(utils:GetAllVersionsOlderThan(...)))
    -- print(utils:IsVersionOlderThan(..., "4.0"))
    -- print(NysTDL.db.global.latestVersion)
    -- print(NysTDL.db.profile.latestVersion)
    print("<Undo Table>")
    for k,v in pairs(NysTDL.db.profile.undoTable) do
      print(k, v)
    end
    -- local scrollFrame = tabsFrame:Get()
    -- tabsFrame:Refresh()
    -- if ... then
    --   scrollFrame:SetHorizontalScroll(...)
    -- end
    -- print(scrollFrame:GetHorizontalScroll())
    -- tabsFrame:Set()
    -- tabsFrame:Refresh()
  elseif yes == 7 then
    tabsFrame:Get()
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
