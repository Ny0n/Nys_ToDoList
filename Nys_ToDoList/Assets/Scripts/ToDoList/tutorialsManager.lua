-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local utils = addonTable.utils
local widgets = addonTable.widgets
local itemsFrame = addonTable.itemsFrame
local tutorialsManager = addonTable.tutorialsManager

-- Variables
local L = addonTable.core.L
local tdlFrame

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

function tutorialsManager:GenerateFrames()
  -- TUTO : How to add categories ("addNewCat")
    -- frame
    tutorialFrames.addNewCat = widgets:TutorialFrame("addNewCat", tdlFrame, false, "UP", L["Start by adding a new category!"], 190, 50)

    -- targeted frame
    tutorialFramesTarget.addNewCat = tdlFrame.categoryButton
    tutorialFrames.addNewCat:SetPoint("TOP", tutorialFramesTarget.addNewCat, "BOTTOM", 0, -18)

  -- TUTO : Adding the categories ("addCat")
    -- frame
    tutorialFrames.addCat = widgets:TutorialFrame("addCat", tdlFrame, true, "UP", L["This will add your category and item to the current tab"], 240, 50)

    -- targeted frame
    tutorialFramesTarget.addCat = tdlFrame.addBtn
    tutorialFrames.addCat:SetPoint("TOP", tutorialFramesTarget.addCat, "BOTTOM", 0, -22)

  -- TUTO : adding an item to a category ("addItem")
    -- frame
    tutorialFrames.addItem = widgets:TutorialFrame("addItem", tdlFrame, false, "RIGHT", L["To add new items to existing categories, just right-click the category names!"], 220, 50)

    -- targeted frame
    -- THIS IS A SPECIAL TARGET THAT GETS UPDATED IN THE LOADCATEGORIES FUNCTION

  -- TUTO : getting more information ("getMoreInfo")
    -- frame
    tutorialFrames.getMoreInfo = widgets:TutorialFrame("getMoreInfo", tdlFrame, false, "LEFT", L["If you're having any problems, or you want more information on systems like favorites or descriptions, you can always click here to print help in the chat!"], 275, 50)

    -- targeted frame
    tutorialFramesTarget.getMoreInfo = tdlFrame.helpButton
    tutorialFrames.getMoreInfo:SetPoint("LEFT", tutorialFramesTarget.getMoreInfo, "RIGHT", 18, 0)

  -- TUTO : accessing the options ("accessOptions")
    -- frame
    tutorialFrames.accessOptions = widgets:TutorialFrame("accessOptions", tdlFrame, false, "DOWN", L["You can access the options from here"], 220, 50)

    -- targeted frame
    tutorialFramesTarget.accessOptions = tdlFrame.frameOptionsButton
    tutorialFrames.accessOptions:SetPoint("BOTTOM", tutorialFramesTarget.accessOptions, "TOP", 0, 18)

  -- TUTO : what does holding ALT do? ("ALTkey")
    -- frame
    tutorialFrames.ALTkey = widgets:TutorialFrame("ALTkey", tdlFrame, false, "DOWN", L["One more thing: if you hold ALT while the list is opened, some interesting buttons will appear!"], 220, 50)

    -- targeted frame
    tutorialFramesTarget.ALTkey = tdlFrame
    tutorialFrames.ALTkey:SetPoint("BOTTOM", tutorialFramesTarget.ALTkey, "TOP", 0, 18)
end

function tutorialsManager:SetTarget(tutoName, targetFrame)
  -- changes the target frame for a given tutorial frame
  local points = {tutorialFrames[tutoName]:GetPoint()}
  points[2] = targetFrame
  tutorialFramesTarget[tutoName] = targetFrame
  tutorialFrames[tutoName]:ClearAllPoints()
  tutorialFrames[tutoName]:SetPoint(unpack(points))
end

function tutorialsManager:SetFramesScale(scale)
  for _, v in pairs(tutorialFrames) do
    v:SetScale(scale)
  end
end

function tutorialsManager:UpdateFramesVisibility()
  -- here we manage the visibility of the tutorial frames, showing them if their corresponding buttons is shown, their tuto has not been completed (false) and the previous one is true.
  if (NysTDL.db.global.tuto_progression < #tutorialOrder) then
    for i, v in pairs(tutorialOrder) do
      local r = false
      if (NysTDL.db.global.tuto_progression < i) then -- if the current loop tutorial has not already been done
        if (NysTDL.db.global.tuto_progression == i-1) then -- and the previous one has been done
          if (tutorialFramesTarget[v] ~= nil and tutorialFramesTarget[v]:IsShown()) then -- and his corresponding target frame is currently shown
            r = true -- then we can show the tutorial frame
          end
        end
      end
      tutorialFrames[v]:SetShown(r)
    end
  elseif (NysTDL.db.global.tuto_progression == #tutorialOrder) then -- we completed the last tutorial
    tutorialFrames[tutorialOrder[#tutorialOrder]]:SetShown(false) -- we don't need to do the big loop above, we just need to hide the last tutorial frame (it's just optimization)
    NysTDL.db.global.tuto_progression = NysTDL.db.global.tuto_progression + 1 -- and we also add a step of progression, just so that we never enter this 'if' again. (optimization too :D)
    ItemsFrame_OnVisibilityUpdate() -- XXX and finally, we reset the menu openings of the list at the end of the tutorial, for more visibility
  end
end

--/*******************/ MANAGMENT /*************************/--

function tutorialsManager:Validate(tuto_name)
  -- completes the "tuto_name" tutorial, only if it was active
  local i = utils:GetKeyFromValue(tutorialOrder, tuto_name)
  if (NysTDL.db.global.tuto_progression < i) then
    if (NysTDL.db.global.tuto_progression == i-1) then
      NysTDL.db.global.tuto_progression = NysTDL.db.global.tuto_progression + 1 -- we validate the tutorial
    end
  end
end

function tutorialsManager:RedoTutorial()
  NysTDL.db.global.tuto_progression = 0
  ItemsFrame_OnVisibilityUpdate()
  tdlFrame.ScrollFrame:SetVerticalScroll(0)
end

--/*******************/ INIT /*************************/--

function tutorialsManager:Init()
  tdlFrame = itemsFrame:GetFrame()
  self:GenerateFrames()
end
