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
local tutorialsManager = addonTable.tutorialsManager
local widgets = addonTable.widgets
local core = addonTable.core

-- Variables
local L = core.L

-- ============================================ --

-- Tests function (for me :p)
function Nys_Tests(yes)
  if yes == 1 then -- tests profile
    print(mainFrame:GetFrame():GetFrameStrata())
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
  	for tabID, tabData in dataManager:ForEach(enums.tab, false) do
      if next(tabData.reset.days) then
        print(">================<")
        print(tabData.name.." tab next reset times:")
    		for timerResetID,targetTime in pairs(tabData.reset.nextResetTimes) do
          resetManager:PrintTimeDiff(timerResetID, targetTime)
    		end
      end
    end
    print("<================>")
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
    print("<Undo Table>")
    for k,v in pairs(NysTDL.db.profile.undoTable) do
      print(k, v)
    end
  end
  print("--Nys_Tests--")
end
