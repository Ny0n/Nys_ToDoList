-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local utils = addonTable.utils
local widgets = addonTable.widgets
local mainFrame = addonTable.mainFrame
local tutorialsManager = addonTable.tutorialsManager

-- Variables
local L = addonTable.core.L

-- tutorial
local tutorialFrames = {}
local tutorialFramesTarget = {}
local tutorialOrder = {
  "addNewCat",
  "addCat",
  "addItem",
  "accessOptions",
  "getMoreInfo",
  "ALTkey"
}

--/*******************/ FRAMES /*************************/--

function tutorialsManager:CreateTutoFrames() -- TODO redo tuto texts
  -- POLISH if text is bigger than width, ... by default but not right AND frame strata too high
  -- TUTO : How to add categories ("addNewCat")
  tutorialFrames.addNewCat = widgets:TutorialFrame("addNewCat", false, "UP", L["Start by adding a new category!"], 190, 50)

  -- TUTO : Adding the categories ("addCat")
  tutorialFrames.addCat = widgets:TutorialFrame("addCat", true, "UP", L["This will add your category to the current tab"], 240, 50)

  -- TUTO : adding an item to a category ("addItem")
  tutorialFrames.addItem = widgets:TutorialFrame("addItem", false, "RIGHT", L["To add new items to existing categories, just right-click the category names!"], 220, 50)

  -- TUTO : getting more information ("getMoreInfo")
  tutorialFrames.getMoreInfo = widgets:TutorialFrame("getMoreInfo", false, "LEFT", L["If you're having any problems, or you just want more information, you can always click here to print help in the chat!"], 275, 50)

  -- TUTO : accessing the options ("accessOptions")
  tutorialFrames.accessOptions = widgets:TutorialFrame("accessOptions", false, "DOWN", L["You can access the options from here"], 220, 50)

  -- TUTO : what does holding ALT do? ("ALTkey")
  tutorialFrames.ALTkey = widgets:TutorialFrame("ALTkey", true, "DOWN", "x", 220, 50)
end

function tutorialsManager:SetPoint(tutoName, point, relativeTo, relativePoint, ofsx, ofsy)
  -- sets the points and target frame of a given tutorial
  tutorialFramesTarget[tutoName] = relativeTo
  tutorialFrames[tutoName]:ClearAllPoints()
  tutorialFrames[tutoName]:SetPoint(point, relativeTo, relativePoint, ofsx, ofsy)
end

function tutorialsManager:SetFramesScale(scale)
  for _, v in pairs(tutorialFrames) do
    v:SetScale(scale)
  end
end

function tutorialsManager:UpdateFramesVisibility()
  -- here we manage the visibility of the tutorial frames, showing them if their corresponding frames are shown,
  -- their tuto has not been completed (false) and the previous one is true.
  -- this is called by the OnUpdate event of the tdlFrame

  if NysTDL.db.global.tuto_progression < #tutorialOrder then
    for i, v in pairs(tutorialOrder) do
      local r = false
      if NysTDL.db.global.tuto_progression < i then -- if the current loop tutorial has not already been done
        if NysTDL.db.global.tuto_progression == i-1 then -- and the previous one has been done
          if tutorialFramesTarget[v] ~= nil and tutorialFramesTarget[v]:IsVisible() then -- and his corresponding target frame is currently visible
            r = true -- then we can show the tutorial frame
          end
        end
      end
      tutorialFrames[v]:SetShown(r)
    end
  elseif NysTDL.db.global.tuto_progression == #tutorialOrder then -- we completed the last tutorial
    tutorialFrames[tutorialOrder[#tutorialOrder]]:SetShown(false) -- we don't need to do the big loop above, we just need to hide the last tutorial frame (it's just optimization)
    tutorialsManager:Next() -- and we also add a step of progression, just so that we never enter this 'if' again. (optimization too :D)
    mainFrame:Event_TDLFrame_OnVisibilityUpdate() -- and finally, we reset the menu openings of the list at the end of the tutorial, for more visibility
  end
end

--/*******************/ MANAGMENT /*************************/--

function tutorialsManager:Validate(tuto_name)
  -- completes the "tuto_name" tutorial, only if it was active
  local i = utils:GetKeyFromValue(tutorialOrder, tuto_name)
  if NysTDL.db.global.tuto_progression < i then
    if NysTDL.db.global.tuto_progression == i-1 then
      tutorialsManager:Next() -- we validate the tutorial by going to the next one
    end
  end
end

function tutorialsManager:Next()
  NysTDL.db.global.tuto_progression = NysTDL.db.global.tuto_progression + 1
end

function tutorialsManager:Previous()
  NysTDL.db.global.tuto_progression = NysTDL.db.global.tuto_progression - 1
  if NysTDL.db.global.tuto_progression < 0 then
    NysTDL.db.global.tuto_progression = 0
  end
end

function tutorialsManager:Reset()
  NysTDL.db.global.tuto_progression = 0
  mainFrame:Event_TDLFrame_OnVisibilityUpdate()
  mainFrame:GetFrame().ScrollFrame:SetVerticalScroll(0)
end
