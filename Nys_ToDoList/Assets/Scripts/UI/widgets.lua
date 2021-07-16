-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local utils = addonTable.utils
local enums = addonTable.enums
local widgets = addonTable.widgets
local tutorialsManager = addonTable.tutorialsManager


-- Variables
local L = addonTable.core.L

local dummyFrame = CreateFrame("Frame", nil, UIParent)
local hyperlinkEditBoxes = {}
local descFrames = {}
local descFrameLevelDiff = 20
local tdlButton

--/*******************/ MISC /*************************/--

-- // hyperlink edit boxes

function widgets:AddHyperlinkEditBox(editBox)
  table.insert(hyperlinkEditBoxes, editBox)
end

function widgets:RemoveHyperlinkEditBox(editBox)
  table.remove(hyperlinkEditBoxes, select(2, utils:HasValue(hyperlinkEditBoxes, editBox))) -- removing the ref of the hyperlink edit box
end

function widgets:SetEditBoxHyperlinkClicks(activated)
  -- IMPORTANT: this code is to activate hyperlink clicks in edit boxes such as the ones for adding new items in categories,
  -- I disabled this for practical reasons: it's easier to write new item names in them if we can click on the links without triggering the hyperlink (and it's not very useful anyways :D).

  for _, v in pairs(hyperlinkEditBoxes) do
    if activated and not v:GetHyperlinksEnabled() then -- just to be sure they are new ones (eg: not redo this for the first item name edit box of the add a category menu)
      v:SetHyperlinksEnabled(true) -- to enable OnHyperlinkClick
      v:SetScript("OnHyperlinkClick", function(self, linkData, link, button)
        ChatFrame_OnHyperlinkShow(ChatFrame1, linkData, link, button)
      end)
    elseif not activated and v:GetHyperlinksEnabled() then
      v:SetHyperlinksEnabled(false) -- to disable OnHyperlinkClick
      v:SetScript("OnHyperlinkClick", nil)
    end
  end
end

function widgets:EditBoxInsertLink(text)
  -- when we shift-click on things, we hook the link from the chat function,
  -- and add it to the one of my edit boxes who has the focus (if there is one)
  -- basically, it's what allow hyperlinks in my addon edit boxes
  for _, v in pairs(hyperlinkEditBoxes) do
		if v and v:IsVisible() and v:HasFocus() then
			v:Insert(text)
			return true
		end
	end
end

-- // description frames

function widgets:SetDescFramesAlpha(alpha)
  -- first we update (or not) the saved variable
  if NysTDL.db.profile.affectDesc then
    NysTDL.db.profile.descFrameAlpha = alpha
  end

  -- and then we update the alpha
  alpha = NysTDL.db.profile.descFrameAlpha/100
  for _, frame in pairs(descFrames) do -- we go through every desc frame
    frame:SetBackdropColor(0, 0, 0, alpha)
    frame:SetBackdropBorderColor(1, 1, 1, alpha)
    for k, x in pairs(frame.descriptionEditBox) do
      if type(k) == "string" then
        if string.sub(k, k:len()-2, k:len()) == "Tex" then -- TODO what is this for?
          x:SetAlpha(alpha)
        end
      end
    end
  end
end

function widgets:SetDescFramesContentAlpha(alpha)
  -- first we update (or not) the saved variable
  if NysTDL.db.profile.affectDesc then
    NysTDL.db.profile.descFrameContentAlpha = alpha
  end

  -- and then we update the alpha
  alpha = NysTDL.db.profile.descFrameContentAlpha/100
  for _, frame in pairs(descFrames) do -- we go through every desc frame
    -- the title is already being cared for in the update of the desc frame
    frame.closeButton:SetAlpha(alpha)
    frame.clearButton:SetAlpha(alpha)
    frame.descriptionEditBox.EditBox:SetAlpha(alpha)
    frame.descriptionEditBox.ScrollBar:SetAlpha(alpha)
    frame.resizeButton:SetAlpha(alpha)
  end
end

function widgets:DescFrameHide(frameName)
  -- here, if the name matches one of the opened description frames, we hide that frame, delete it from memory and reupdate the levels of every other active ones
  for pos, frame in pairs(descFrames) do
    if frame:GetName() == frameName then
      frame:Hide()
      widgets:RemoveHyperlinkEditBox(frame.descriptionEditBox.EditBox)
      table.remove(descFrames, pos) -- we remove the desc frame from its table
      for pos2, frame2 in pairs(descFrames) do -- we update the frame levels
        frame2:SetFrameLevel(300 + (pos2-1)*descFrameLevelDiff)
      end
      return true
    end
  end
  return false
end

function widgets:WipeDescFrames()
  -- to reset the desc frames
  for _, frame in pairs(descFrames) do
    widgets:RemoveHyperlinkEditBox(frame.descriptionEditBox.EditBox)
    frame:Hide()
  end
  wipe(descFrames)
end

-- // tdl button

function widgets:RefreshTDLButton()
  -- // to refresh everything concerbing the tdl button

  -- updating its position and shown state in accordance to the saved variables
  local points = NysTDL.db.profile.tdlButton.points
  tdlButton:ClearAllPoints()
  tdlButton:SetPoint(points.point, nil, points.relativePoint, points.xOffset, points.yOffset) -- relativeFrame = nil -> entire screen
  tdlButton:SetShown(NysTDL.db.profile.tdlButton.show)

  -- and updating its color
  widgets:UpdateTDLButtonColor()
end

function widgets:UpdateTDLButtonColor()
  -- the TDL button red option, if any tab has a reset in less than 24 hours,
  -- and also has unchecked items, we color in red the text of the tdl button

  if NysTDL.db.profile.tdlButton.red then -- if the option is checked
    tdlButton:SetNormalFontObject("GameFontNormalLarge") -- by default, we reset the color of the TDL button to yellow
    local maxTime = time() + 86400
    dataManager:DoForEachResetTab(maxTime, "unchecked", function()
      -- we color the button in red
      local font = tdlButton:GetNormalFontObject()
      font:SetTextColor(1, 0, 0, 1)
      tdlButton:SetNormalFontObject(font)
    end)
  end
end

-- // other

function widgets:SetFocusEditBox(editBox) -- DRY
  editBox:SetFocus()
  if NysTDL.db.profile.highlightOnFocus then
    editBox:HighlightText()
  else
    editBox:HighlightText(0, 0)
  end
end

function widgets:GetWidth(text)
  -- not the length (#) of a string, but the width it takes when placed on the screen as a font string
  local l = widgets:NoPointsLabel(dummyFrame, nil, text)
  return l:GetWidth()
end

--/*******************/ FRAMES /*************************/--

function widgets:TutorialFrame(tutoName, parent, showCloseButton, arrowSide, text, width, height)
  local tutoFrame = CreateFrame("Frame", "NysTDL_TutorialFrame_"..tutoName, parent, "NysTDL_HelpPlateTooltip")
  tutoFrame:SetSize(width, height)

  if arrowSide == "UP" then tutoFrame.ArrowDOWN:Show()
  elseif arrowSide == "DOWN" then tutoFrame.ArrowUP:Show()
  elseif arrowSide == "LEFT" then tutoFrame.ArrowRIGHT:Show()
  elseif arrowSide == "RIGHT" then tutoFrame.ArrowLEFT:Show() end

  local tutoFrameRightDist = 10
  if showCloseButton then
    tutoFrameRightDist = 40
    tutoFrame.closeButton = CreateFrame("Button", "closeButton", tutoFrame, "UIPanelCloseButton")
    tutoFrame.closeButton:SetPoint("TOPRIGHT", tutoFrame, "TOPRIGHT", 6, 6)
    tutoFrame.closeButton:SetScript("OnClick", function() tutorialsManager:Next() end)
  end

  tutoFrame.Text:SetWidth(tutoFrame:GetWidth() - tutoFrameRightDist)
  tutoFrame.Text:SetText(text)
  tutoFrame:Hide() -- we hide them by default, we show them only when we need to

  return tutoFrame
end

function widgets:DescriptionFrame(itemWidget)
  -- the big function to create the description frame for each items

  local itemID = itemWidget.itemID
  local itemData = select(3, dataManager:Find(itemID))
  local frameName = "NysTDL_DescFrame_"..tostring(itemID)

  -- first we check if it's already opened, in which case we act as a toggle, and hide it
  if widgets:DescFrameHide(frameName) then return end

  -- // creating the frame and all of its content

  -- we create the mini frame holding the name of the item and his description in an edit box
  local descFrame = CreateFrame("Frame", frameName, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil) -- importing the backdrop in the desc frames, as of wow 9.0
  local w = widgets:GetWidth(itemData.name)
  descFrame:SetSize(w < 180 and 180+75 or w+75, 110) -- 75 is large enough to place the closebutton, clearbutton, and a little bit of space at the right of the name

  -- background
  descFrame:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = false, tileSize = 1, edgeSize = 10, insets = { left = 1, right = 1, top = 1, bottom = 1 }})
  descFrame:SetBackdropColor(0, 0, 0, 1)

  -- properties
  descFrame:SetResizable(true)
  descFrame:SetMinResize(descFrame:GetWidth(), descFrame:GetHeight())
  descFrame:SetFrameLevel(300 + #descFrames*descFrameLevelDiff) -- TODO SetTopLevel avec frameStrata
  descFrame:SetMovable(true)
  descFrame:SetClampedToScreen(true)
  descFrame:EnableMouse(true)
  descFrame.timeSinceLastUpdate = 0 -- for the updating of the title's color and alpha
  descFrame.opening = 0 -- for the scrolling up on opening

  -- to move the frame
  descFrame:SetScript("OnMouseDown", function(self, button)
      if button == "LeftButton" then
          self:StartMoving()
      end
  end)
  descFrame:SetScript("OnMouseUp", descFrame.StopMovingOrSizing)

  -- OnUpdate script
  local tdlFrame = mainFrame:GetFrame()
  descFrame:SetScript("OnUpdate", function(self, elapsed)
    self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed

    while self.timeSinceLastUpdate > updateRate do -- every 0.05 sec (instead of every frame which is every 1/144 (0.007) sec for a 144hz display... optimization :D)
      -- we update non-stop the color of the title
      local currentAlpha = NysTDL.db.profile.descFrameContentAlpha/100
      if itemData.checked then
        self.title:SetTextColor(0, 1, 0, currentAlpha)
      else
        if itemData.favorite then
          local r, g, b = unpack(NysTDL.db.profile.favoritesColor)
          self.title:SetTextColor(r, g, b, currentAlpha)
        else
          local r, g, b = unpack(config:ThemeDownTo01(config.database.theme_yellow))
          self.title:SetTextColor(r, g, b, currentAlpha)
        end
      end

      -- if the desc frame is the oldest (the first opened on screen, or subsequently the one who has the lowest frame level)
      -- we use that one to cycle the rainbow colors if the list gets closed
      if not tdlFrame:IsShown() then
        if self:GetFrameLevel() == 300 then
          if NysTDL.db.profile.rainbow then mainFrame:ApplyNewRainbowColor(NysTDL.db.profile.rainbowSpeed) end
        end
      end

      self.timeSinceLastUpdate = self.timeSinceLastUpdate - updateRate
    end

    -- and we also update non-stop the width of the description edit box to match that of the frame if we resize it, and when the scrollbar kicks in. (this is the secret to make it work)
    self.descriptionEditBox.EditBox:SetWidth(self.descriptionEditBox:GetWidth() - (self.descriptionEditBox.ScrollBar:IsShown() and 15 or 0))

    if self.opening < 5 then -- doing this only on the 5 first updates after creating the frame, i won't go into the details but updating the vertical scroll of this template is a real fucker :D
      self.descriptionEditBox:SetVerticalScroll(0)
      self.opening = self.opening + 1
    end
  end)

  -- position
  -- TODO redo itemWidget.descBtn line below?
  descFrame:SetPoint("BOTTOMRIGHT", itemWidget.descBtn, "TOPLEFT", 0, 0) -- we spawn it basically at the cursor
  descFrame:StartMoving() -- to unlink it from the tdlFrame
  descFrame:StopMovingOrSizing()

  -- / content of the frame / --

  -- resize button
  descFrame.resizeButton = CreateFrame("Button", nil, descFrame, "NysTDL_ResizeButton")
  descFrame.resizeButton:SetPoint("BOTTOMRIGHT")
  descFrame.resizeButton:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
      descFrame:StartSizing("BOTTOMRIGHT")
      self:GetHighlightTexture():Hide() -- more noticeable
    end
  end)
  descFrame.resizeButton:SetScript("OnMouseUp", function(self)
    descFrame:StopMovingOrSizing()
    self:GetHighlightTexture():Show()
  end)

  -- close button
  descFrame.closeButton = CreateFrame("Button", "closeButton", descFrame, "NysTDL_CloseButton")  -- TODO icon button? voir aussi sur tdlFrame
  descFrame.closeButton:SetPoint("TOPRIGHT", descFrame, "TOPRIGHT", -2, -2)
  descFrame.closeButton:SetScript("OnClick", function()
      widgets:DescFrameHide(frameName)
  end)

  -- clear button
  descFrame.clearButton = CreateFrame("Button", "clearButton", descFrame, "NysTDL_ClearButton") -- TODO icon button?
  descFrame.clearButton.tooltip = L["Clear"].."\n("..L["Right-click"]..')'
  descFrame.clearButton:SetPoint("TOPRIGHT", descFrame, "TOPRIGHT", -24, -2)
  descFrame.clearButton:RegisterForClicks("RightButtonUp")
  descFrame.clearButton:SetScript("OnClick", function(self)
      local eb = self:GetParent().descriptionEditBox.EditBox
      eb:SetText("")
      eb:GetScript("OnKeyUp")(eb)
  end)

  -- item label
  descFrame.title = descFrame:CreateFontString(frameName.."_Title")
  descFrame.title:SetFontObject("GameFontNormalLarge")
  descFrame.title:SetPoint("TOPLEFT", descFrame, "TOPLEFT", 6, -5)
  descFrame.title:SetText(itemData.name)
  descFrame:SetHyperlinksEnabled(true) -- to enable OnHyperlinkClick on the frame
  descFrame:SetScript("OnHyperlinkClick", function(_, linkData, link, button)
    ChatFrame_OnHyperlinkShow(ChatFrame1, linkData, link, button)
  end)

  -- description edit box
  descFrame.descriptionEditBox = CreateFrame("ScrollFrame", frameName.."_EditBox", descFrame, "InputScrollFrameTemplate")
  descFrame.descriptionEditBox.EditBox:SetFontObject("ChatFontNormal")
  descFrame.descriptionEditBox.EditBox:SetAutoFocus(false)
  descFrame.descriptionEditBox.EditBox:SetMaxLetters(0)
  descFrame.descriptionEditBox.CharCount:Hide()
  descFrame.descriptionEditBox.EditBox.Instructions:SetFontObject("GameFontNormal")
  descFrame.descriptionEditBox.EditBox.Instructions:SetText(L["Add a description..."].."\n"..L["(automatically saved)"])
  descFrame.descriptionEditBox:SetPoint("TOPLEFT", descFrame, "TOPLEFT", 10, -30)
  descFrame.descriptionEditBox:SetPoint("BOTTOMRIGHT", descFrame, "BOTTOMRIGHT", -10, 10)
  if itemData.description then -- if there is already a description for this item, we write it on frame creation
    descFrame.descriptionEditBox.EditBox:SetText(itemData.description)
  end
  descFrame.descriptionEditBox.EditBox:SetScript("OnKeyUp", function(self)
    -- and here we save the description everytime we lift a finger (best auto-save possible I think)
    dataManager:UpdateDescription(itemID, self:GetText())
    if IsControlKeyDown() then -- just in case we are ctrling-v, to color the icon
      itemWidget.descBtn:GetScript("OnShow")(itemWidget.descBtn)
    end
  end)
  descFrame.descriptionEditBox.EditBox:SetHyperlinksEnabled(true) -- to enable OnHyperlinkClick in the EditBox
  descFrame.descriptionEditBox.EditBox:SetScript("OnHyperlinkClick", function(_, linkData, link, button)
    ChatFrame_OnHyperlinkShow(ChatFrame1, linkData, link, button)
  end)
  widgets:AddHyperlinkEditBox(descFrame.descriptionEditBox.EditBox)

  table.insert(descFrames, descFrame) -- we save it for access, level, hide, and alpha purposes

  -- // finished creating the frame

  -- we update the alpha if it needs to be
  mainFrame:Event_FrameAlphaSlider_OnValueChanged(nil, NysTDL.db.profile.frameAlpha)
  mainFrame:Event_FrameContentAlphaSlider_OnValueChanged(nil, NysTDL.db.profile.frameContentAlpha)

  mainFrame:Refresh() -- we refresh the main frame to instantly display the changes -- XXX necessary?
end

function widgets:Dummy(parentFrame, relativeFrame, xOffset, yOffset)
  local dummy = CreateFrame("Frame", nil, parentFrame, nil) -- TODO test different things
  dummy:SetPoint("TOPLEFT", relativeFrame, "TOPLEFT", xOffset, yOffset)
  dummy:SetSize(1, 1)
  dummy:Show()
  return dummy
end

--/*******************/ LABELS /*************************/--

function widgets:NoPointsLabel(relativeFrame, name, text)
  local label = relativeFrame:CreateFontString(name)
  label:SetFontObject("GameFontHighlightLarge")
  label:SetText(text)
  return label
end

function widgets:NoPointsInteractiveLabel(name, relativeFrame, text, fontObjectString)
  local interactiveLabel = CreateFrame("Frame", name, relativeFrame, "NysTDL_InteractiveLabel")
  interactiveLabel.Text:SetFontObject(fontObjectString)
  interactiveLabel.Text:SetText(text)
  interactiveLabel:SetSize(interactiveLabel.Text:GetWidth(), interactiveLabel.Text:GetHeight()) -- we init the size to the text's size

  -- this updates the frame's size each time the text's size is changed
  interactiveLabel.Button:SetScript("OnSizeChanged", function(self, width, height)
    self:GetParent():SetSize(width, height)
  end)

  return interactiveLabel
end

function widgets:NothingLabel(relativeFrame)
  local label = relativeFrame:CreateFontString(nil) -- TODO this func necessary?
  label:SetFontObject("GameFontHighlightLarge")
  label:SetTextColor(0.5, 0.5, 0.5, 0.5)
  return label
end

--/*******************/ BUTTONS /*************************/--

function widgets:Button(name, relativeFrame, text, iconPath, fc)
  fc = fc or false
  iconPath = type(iconPath) == "string" and iconPath or nil

  local btn = CreateFrame("Button", name, relativeFrame, "NysTDL_NormalButton")

  btn:SetText(text)
  btn:SetNormalFontObject("GameFontNormalLarge")
  if fc == true then btn:SetHighlightFontObject("GameFontHighlightLarge") end

  local w = widgets:GetWidth(text)
  if iconPath ~= nil then
    w = w + 23
    btn.Icon = btn:CreateTexture(nil, "ARTWORK")
    btn.Icon:SetPoint("LEFT", btn, "LEFT", 10, 0)
    btn.Icon:SetTexture(iconPath)
    btn.Icon:SetSize(17, 17)
    btn:GetFontString():SetPoint("LEFT", btn, "LEFT", 33, 0)
    btn:HookScript("OnMouseDown", function(self) self.Icon:SetPoint("LEFT", self, "LEFT", 12, -2) end)
    btn:HookScript("OnMouseUp", function(self) self.Icon:SetPoint("LEFT", self, "LEFT", 10, 0) end)
  end
  btn:SetWidth(w + 20)

  return btn
end

function widgets:IconButton(relativeFrame, template, tooltip)
  local btn = CreateFrame("Button", nil, relativeFrame, template)
  btn.tooltip = tooltip
  return btn
end

function widgets:HelpButton(relativeFrame)
  local btn = CreateFrame("Button", nil, relativeFrame, "NysTDL_HelpButton")
  btn.tooltip = L["Information"]

  -- these are for changing the color depending on the mouse actions (since they are custom xml)
  btn:HookScript("OnEnter", function(self)
    self:SetAlpha(1)
  end)
  btn:HookScript("OnLeave", function(self)
    self:SetAlpha(0.7)
  end)
  btn:HookScript("OnShow", function(self)
    self:SetAlpha(0.7)
  end)
  return btn
end

function widgets:CreateTDLButton()
  -- creating the big button to easily toggle the frame
  tdlButton = widgets:Button("tdlButton", UIParent, string.gsub(core.toc.title, "Ny's ", ""))
  tdlButton:SetFrameLevel(100)
  tdlButton:SetMovable(true)
  tdlButton:EnableMouse(true)
  tdlButton:SetClampedToScreen(true)

  -- drag
  tdlButton:RegisterForDrag("LeftButton")
  tdlButton:SetScript("OnDragStart", function()
    if (not NysTDL.db.profile.lockButton) then
      tdlButton:StartMoving()
    end
  end)
  tdlButton:SetScript("OnDragStop", function() -- we save its position
    tdlButton:StopMovingOrSizing()
    local points, _ = NysTDL.db.profile.tdlButton.points, nil
    points.point, _, points.relativePoint, points.xOffset, points.yOffset = tdlButton:GetPoint()
  end)

  -- click
  tdlButton:SetScript("OnClick", mainFrame.Toggle) -- the function the button calls when pressed

  widgets:RefreshTDLButton() -- refresh
end

-- item buttons

function widgets:RemoveButton(itemWidget)
  local btn = CreateFrame("Button", nil, itemWidget.checkBtn, "NysTDL_RemoveButton")
  btn:SetPoint("LEFT", itemWidget.checkBtn, "LEFT", -20, 0)

  -- these are for changing the color depending on the mouse actions (since they are custom xml)
  btn:HookScript("OnEnter", function(self)
    self.Icon:SetVertexColor(0.8, 0.2, 0.2)
  end)
  btn:HookScript("OnLeave", function(self)
    if tonumber(string.format("%.1f", self.Icon:GetAlpha())) ~= 0.5 then
      self.Icon:SetVertexColor(1, 1, 1)
    end
  end)
  btn:HookScript("OnMouseUp", function(self)
    if self.name == "RemoveButton" then -- TODO is this useful?
      self.Icon:SetVertexColor(1, 1, 1)
    end
  end)
  btn:HookScript("OnShow", function(self)
    self.Icon:SetVertexColor(1, 1, 1)
  end)
  return btn
end

function widgets:FavoriteButton(itemWidget)
  local btn = CreateFrame("Button", nil, itemWidget.checkBtn, "NysTDL_FavoriteButton")
  btn:SetPoint("LEFT", itemWidget.checkBtn, "LEFT", -20, -2)

  -- these are for changing the color depending on the mouse actions (since they are custom xml)
  -- and yea, this one's a bit complicated because I wanted its look to be really precise...
  btn:HookScript("OnEnter", function(self)
    if not itemWidget.itemData.favorite then -- not favorited
      self.Icon:SetDesaturated(nil)
      self.Icon:SetVertexColor(1, 1, 1)
    else
      self:SetAlpha(0.6)
    end
  end)
  btn:HookScript("OnLeave", function(self)
    if not itemWidget.itemData.favorite then
      if tonumber(string.format("%.1f", self.Icon:GetAlpha())) ~= 0.5 then -- if we are currently clicking on the button
        self.Icon:SetDesaturated(1)
        self.Icon:SetVertexColor(0.4, 0.4, 0.4)
      end
    else
      self:SetAlpha(1)
    end
   end)
   btn:HookScript("OnMouseUp", function(self)
     if self.name == "FavoriteButton" then
       self:SetAlpha(1)
       if not itemWidget.itemData.favorite then
         self.Icon:SetDesaturated(1)
         self.Icon:SetVertexColor(0.4, 0.4, 0.4)
       end
     end
   end)
   btn:HookScript("PostClick", function(self)
     if self.name == "FavoriteButton" then -- TODO same, useful?
       self:GetScript("OnShow")(self)
     end
   end)
  btn:HookScript("OnShow", function(self)
    -- if not utils:ItemExists(catName, itemName) then return end -- TODO verify if its necessary
    self:SetAlpha(1)
    if not itemWidget.itemData.favorite then
      self.Icon:SetDesaturated(1)
      self.Icon:SetVertexColor(0.4, 0.4, 0.4)
    else
      self.Icon:SetDesaturated(nil)
      self.Icon:SetVertexColor(1, 1, 1)
    end
  end)
  return btn
end

function widgets:DescButton(itemWidget)
  local btn = CreateFrame("Button", nil, itemWidget.checkBtn, "NysTDL_DescButton")
  btn:SetPoint("LEFT", itemWidget.checkBtn, "LEFT", -20, 0)

  -- these are for changing the color depending on the mouse actions (since they are custom xml)
  -- and yea, this one's a bit complicated too because it works in very specific ways
  btn:HookScript("OnEnter", function(self)
    if not itemWidget.itemData.description then -- no description
      self.Icon:SetDesaturated(nil)
      self.Icon:SetVertexColor(1, 1, 1)
    else
      self:SetAlpha(0.6)
    end
  end)
  btn:HookScript("OnLeave", function(self)
    if not itemWidget.itemData.description then
      if tonumber(string.format("%.1f", self.Icon:GetAlpha())) ~= 0.5 then -- if we are currently clicking on the button
        self.Icon:SetDesaturated(1)
        self.Icon:SetVertexColor(0.4, 0.4, 0.4)
      end
    else
      self:SetAlpha(1)
    end
   end)
   btn:HookScript("OnMouseUp", function(self)
     if self.name == "DescButton" then
       self:SetAlpha(1)
       if not itemWidget.itemData.description then
         self.Icon:SetDesaturated(1)
         self.Icon:SetVertexColor(0.4, 0.4, 0.4)
       end
     end
   end)
   btn:HookScript("PostClick", function(self)
     if self.name == "DescButton" then -- TODO same, useful?
       self:GetScript("OnShow")(self)
     end
   end)
  btn:HookScript("OnShow", function(self)
    self:SetAlpha(1)
    if not itemWidget.itemData.description then
      self.Icon:SetDesaturated(1)
      self.Icon:SetVertexColor(0.4, 0.4, 0.4)
    else
      self.Icon:SetDesaturated(nil)
      self.Icon:SetVertexColor(1, 1, 1)
    end
  end)
  return btn
end

--/*******************/ ITEM/CATEGORY WIDGETS /*************************/--

-- TODO redo
function widgets:CategoryWidget(catID)
  -- category label
  label[catName] = widgets:NoPointsInteractiveLabel("NysTDL_CatLabel_"..catName, tdlFrame, catName, "GameFontHighlightLarge")
  label[catName].catName = catName -- easy access to the catName of the label, this also allows the shown text to be different
  label[catName].Button:SetScript("OnEnter", function(self)
    local r, g, b = unpack(utils:ThemeDownTo01(database.themes.theme))
    self:GetParent().Text:SetTextColor(r, g, b, 1) -- when we hover it, we color the label
  end)
  label[catName].Button:SetScript("OnLeave", function(self)
    self:GetParent().Text:SetTextColor(1, 1, 1, 1) -- back to the default color
  end)
  label[catName].Button:SetScript("OnClick", function(self, button)
    if (IsAltKeyDown()) then return end -- we don't do any of the OnClick code if we have the Alt key down, bc it means that we want to rename the category by double clicking
    local catName = self:GetParent().catName
    if (button == "LeftButton") then -- we open/close the category
      if (utils:HasKey(NysTDL.db.profile.closedCategories, catName) and NysTDL.db.profile.closedCategories[catName] ~= nil) then -- if this is a category that is closed in certain tabs
        local isPresent, pos = utils:HasValue(NysTDL.db.profile.closedCategories[catName], dataManager:GetName(ctab())) -- we get if it is closed in the current tab
        if (isPresent) then -- if it is
          table.remove(NysTDL.db.profile.closedCategories[catName], pos) -- then we remove it from the saved variable
          if (#NysTDL.db.profile.closedCategories[catName] == 0) then -- and btw check if it was the only tab remaining where it was closed
            NysTDL.db.profile.closedCategories[catName] = nil -- in which case we nil the table variable for that category
          end
        else  -- if it is opened in the current tab
          table.insert(NysTDL.db.profile.closedCategories[catName], dataManager:GetName(ctab())) -- then we close it by adding it to the saved variable
        end
      else -- if this category was closed nowhere
        NysTDL.db.profile.closedCategories[catName] = {dataManager:GetName(ctab())} -- then we create its table variable and initialize it with the current tab (we close the category in the current tab)
      end

      -- and finally, we reload the frame to display the changes
      mainFrame:Refresh()
    elseif (button == "RightButton") then -- we try to toggle the edit box to add new items
      -- if the label we right clicked on is NOT a closed category
      if (not (select(1, utils:HasKey(NysTDL.db.profile.closedCategories, catName))) or not (select(1, utils:HasValue(NysTDL.db.profile.closedCategories[catName], dataManager:GetName(ctab()))))) then
        -- we toggle its edit box
        editBox[catName]:SetShown(not editBox[catName]:IsShown())

        if (editBox[catName]:IsShown()) then
          -- tutorial
          tutorialsManager:Validate("addItem")

          -- we also give that edit box the focus if we are showing it
          widgets:SetFocusEditBox(editBox[catName])
        end
      end
    end
  end)
  label[catName].Button:SetScript("OnDoubleClick", function(self)
    if (not IsAltKeyDown()) then return end -- we don't do any of the OnDoubleClick code if we don't have the Alt key down

    -- first, we hide the label
    local label = self:GetParent()
    label.Text:Hide()
    label.Button:Hide()

    -- then, we can create the new edit box to rename the category, where the label was
    local catName = label.catName
    local renameEditBox = widgets:NoPointsRenameEditBox(label, catName, categoryNameWidthMax, self:GetHeight())
    renameEditBox:SetPoint("LEFT", label, "LEFT", 5, 0)

    -- we move the favs remaining label to the right of the edit box while it's shown
    if (utils:HasKey(categoryLabelFavsRemaining, catName)) then
      categoryLabelFavsRemaining[catName]:ClearAllPoints()
      categoryLabelFavsRemaining[catName]:SetPoint("LEFT", renameEditBox, "RIGHT", 6, 0)
    end

    -- let's go!
    renameEditBox:SetScript("OnEnterPressed", function(self)
      local newCatName = self:GetText()
      -- first, we do some tests
      if (newCatName == "") then -- if the new cat name is empty
        self:GetScript("OnEscapePressed")(self) -- we cancel the action
        return
      elseif (newCatName == catName) then -- if the new is the same as the old
        self:GetScript("OnEscapePressed")(self) -- we cancel the action
        return
      elseif (utils:HasKey(NysTDL.db.profile.itemsList, newCatName)) then -- if the new cat name already exists
        chat:PrintForced(L["This category name already exists"]..". "..L["Please choose a different name to avoid overriding data"])
        return
      else
        local l = widgets:NoPointsLabel(tdlFrame, nil, newCatName)
        if (l:GetWidth() > categoryNameWidthMax) then -- if the new cat name is too big
          chat:PrintForced(L["This categoty name is too big!"])
          return
        end
      end

      -- and if everything is good, we can rename the category
      mainFrame:RenameCategory(catName, newCatName)
    end)

    -- cancelling
    renameEditBox:SetScript("OnEscapePressed", function(self)
      self:Hide()
      label.Text:Show()
      label.Button:Show()
      -- when hiding the edit box, we reset the pos of the favs remaining label
      if (utils:HasKey(categoryLabelFavsRemaining, catName)) then
        categoryLabelFavsRemaining[catName]:ClearAllPoints()
        categoryLabelFavsRemaining[catName]:SetPoint("LEFT", label, "RIGHT", 6, 0)
      end
    end)
    renameEditBox:HookScript("OnEditFocusLost", function(self)
      self:GetScript("OnEscapePressed")(self)
    end)
  end)

  -- associated favs remaining label
  categoryLabelFavsRemaining[catName] = widgets:NoPointsLabel(label[catName], label[catName]:GetName().."_FavsRemaining", "")

  -- associated edit box and add button
  editBox[catName] = widgets:NoPointsCatEditBox(catName)
  editBox[catName]:SetScript("OnEnterPressed", function(self)
    mainFrame:AddItem(self)
    self:Show() -- we keep it shown to add more items
    widgets:SetFocusEditBox(self)
  end)
  -- cancelling
  editBox[catName]:SetScript("OnEscapePressed", function(self)
    self:Hide()
  end)
  editBox[catName]:HookScript("OnEditFocusLost", function(self)
    self:GetScript("OnEscapePressed")(self)
  end)
  widgets:AddHyperlinkEditBox(editBox[catName])
end

-- TODO redo
function widgets:ItemWidget(itemID)
  local data = NysTDL.db.profile.itemsList[catName][itemName]

  if (not utils:HasKey(checkBtn, catName)) then checkBtn[catName] = {} end
  checkBtn[catName][itemName] = CreateFrame("CheckButton", "NysTDL_CheckBtn_"..catName.."_"..itemName, tdlFrame, "UICheckButtonTemplate")
  checkBtn[catName][itemName].InteractiveLabel = widgets:NoPointsInteractiveLabel(checkBtn[catName][itemName]:GetName().."_InteractiveLabel", checkBtn[catName][itemName], itemName, "GameFontNormalLarge")
  checkBtn[catName][itemName].InteractiveLabel:SetPoint("LEFT", checkBtn[catName][itemName], "RIGHT")
  checkBtn[catName][itemName].InteractiveLabel.Text:SetPoint("LEFT", checkBtn[catName][itemName], "RIGHT", 20, 0)
  checkBtn[catName][itemName].catName = catName -- easy access to the catName this button is in
  checkBtn[catName][itemName].itemName = itemName -- easy access to the itemName of this button, this also allows the shown text to be different
  if (utils:HasHyperlink(itemName)) then -- this is for making more space for items that have hyperlinks in them
    if (checkBtn[catName][itemName].InteractiveLabel.Text:GetWidth() > itemNameWidthMax) then
      checkBtn[catName][itemName].InteractiveLabel.Text:SetFontObject("GameFontNormal")
    end

    -- and also to deactivate the InteractiveLabel's Button, so that we can actually click on the links
    -- unless we are holding Alt, and to detect this, we actually put on them an OnUpdate script
    checkBtn[catName][itemName].InteractiveLabel:SetScript("OnUpdate", function(self)
      if (IsAltKeyDown()) then
        self.Button:Show()
      else
        self.Button:Hide()
      end
    end)
  end
  checkBtn[catName][itemName]:SetChecked(data.checked)
  checkBtn[catName][itemName]:SetScript("OnClick", function(self)
    data.checked = self:GetChecked()
    if (NysTDL.db.profile.instantRefresh) then
      mainFrame:Refresh()
    else
      mainFrame:Update()
    end
  end)
  checkBtn[catName][itemName].InteractiveLabel:SetHyperlinksEnabled(true) -- to enable OnHyperlinkClick
  checkBtn[catName][itemName].InteractiveLabel:SetScript("OnHyperlinkClick", function(_, linkData, link, button)
    ChatFrame_OnHyperlinkShow(ChatFrame1, linkData, link, button)
  end)
  checkBtn[catName][itemName].InteractiveLabel.Button:SetScript("OnDoubleClick", function(self)
    -- first, we hide the label
    local checkBtn = self:GetParent():GetParent()
    checkBtn.InteractiveLabel:Hide()

    -- then, we can create the new edit box to rename the item, where the label was
    local catName, itemName = checkBtn.catName, checkBtn.itemName
    local renameEditBox = widgets:NoPointsRenameEditBox(checkBtn, itemName, itemNameWidthMax, self:GetHeight())
    renameEditBox:SetPoint("LEFT", checkBtn, "RIGHT", 5, 0)
    -- renameEditBox:SetHyperlinksEnabled(true) -- to enable OnHyperlinkClick
    -- renameEditBox:SetScript("OnHyperlinkClick", function(_, linkData, link, button)
    --   ChatFrame_OnHyperlinkShow(ChatFrame1, linkData, link, button)
    -- end)
    widgets:AddHyperlinkEditBox(renameEditBox) -- so that we can add hyperlinks in it

    -- let's go!
    renameEditBox:SetScript("OnEnterPressed", function(self)
      local newItemName = self:GetText()
      -- first, we do some tests
      if (newItemName == "") then -- if the new item name is empty
        self:GetScript("OnEscapePressed")(self) -- we cancel the action
        return
      elseif (newItemName == itemName) then -- if the new is the same as the old
        self:GetScript("OnEscapePressed")(self) -- we cancel the action
        return
      elseif (utils:HasKey(NysTDL.db.profile.itemsList[catName], newItemName)) then -- if the new item name already exists somewhere in the category
        chat:PrintForced(L["This item name already exists in the category"]..". "..L["Please choose a different name to avoid overriding data"])
        return
      else
        local l = widgets:NoPointsLabel(tdlFrame, nil, newItemName)
        if (l:GetWidth() > itemNameWidthMax and utils:HasHyperlink(newItemName)) then l:SetFontObject("GameFontNormal") end -- if it has an hyperlink in it and it's too big, we allow it to be a little longer, considering hyperlinks take more place
        if (l:GetWidth() > itemNameWidthMax) then -- then we recheck to see if the item is not too long for good
          chat:PrintForced(L["This item name is too big!"])
          return
        end
      end

      -- and if everything is good, we can rename the item (a.k.a, delete the current one and creating a new one)
      -- while keeping the same cat, and same tab
      mainFrame:MoveItem(catName, catName, itemName, newItemName, NysTDL.db.profile.itemsList[catName][itemName].tabName)
    end)

    -- cancelling
    renameEditBox:SetScript("OnEscapePressed", function(self)
      self:Hide()
      checkBtn.InteractiveLabel:Show()
      widgets:RemoveHyperlinkEditBox(self)
    end)
    renameEditBox:HookScript("OnEditFocusLost", function(self)
      self:GetScript("OnEscapePressed")(self)
    end)
  end)

  if (not utils:HasKey(removeBtn, catName)) then removeBtn[catName] = {} end
  removeBtn[catName][itemName] = widgets:RemoveButton(checkBtn[catName][itemName])
  removeBtn[catName][itemName]:SetScript("OnClick", function(self) mainFrame:RemoveItem(self) end)

  if (not utils:HasKey(favoriteBtn, catName)) then favoriteBtn[catName] = {} end
  favoriteBtn[catName][itemName] = widgets:FavoriteButton(checkBtn[catName][itemName], catName, itemName)
  favoriteBtn[catName][itemName]:SetScript("OnClick", function(self) mainFrame:FavoriteClick(self) end)
  favoriteBtn[catName][itemName]:Hide()

  if (not utils:HasKey(descBtn, catName)) then descBtn[catName] = {} end
  descBtn[catName][itemName] = widgets:DescButton(checkBtn[catName][itemName], catName, itemName)
  descBtn[catName][itemName]:SetScript("OnClick", function() widgets:DescriptionFrame(itemWidget) end) -- TODO don't forget
  descBtn[catName][itemName]:Hide()
end

--/*******************/ EDIT BOXES /*************************/--

function widgets:NoPointsRenameEditBox(relativeFrame, text, width, height)
  local renameEditBox = CreateFrame("EditBox", tostring(relativeFrame:GetName()).."_RenameEditBox", relativeFrame, "InputBoxTemplate")
  renameEditBox:SetSize(width-10, height)
  renameEditBox:SetText(text)
  renameEditBox:SetFontObject("GameFontHighlightLarge")
  renameEditBox:SetAutoFocus(false)
  widgets:SetFocusEditBox(renameEditBox) -- TODO verify this or redo old version
  -- renameEditBox:HookScript("OnEditFocusGained", function(self)
  --   self:HighlightText(0, 0) -- we don't select everything by default when we select the edit box
  -- end)
  return renameEditBox
end

function widgets:NoPointsCatEditBox(name)
  local edb = CreateFrame("EditBox", name, nil, "InputBoxTemplate")
  edb:SetAutoFocus(false)
  -- edb:SetTextInsets(0, 15, 0, 0)
  -- local btn = CreateFrame("Button", nil, edb, "NysTDL_AddButton")
  -- btn.tooltip = L["Press enter to add the item"]
  -- btn:SetPoint("RIGHT", edb, "RIGHT", -4, -1.2)
  -- btn:EnableMouse(true)
  --
  -- -- these are for changing the color depending on the mouse actions (since they are custom xml)
  -- btn:HookScript("OnEnter", function(self)
  --   self.Icon:SetTextColor(1, 1, 0, 0.6)
  -- end)
  -- btn:HookScript("OnLeave", function(self)
  --   self.Icon:SetTextColor(1, 1, 1, 0.4)
  -- end)
  -- btn:HookScript("OnShow", function(self)
  --   self.Icon:SetTextColor(1, 1, 1, 0.4)
  -- end)
  return edb
end

--/*******************/ OTHER /*************************/--

function widgets:NoPointsLine(relativeFrame, thickness, r, g, b, a)
  a = a or 1
  local line = relativeFrame:CreateLine()
  line:SetThickness(thickness)
  if r and g and b and a then line:SetColorTexture(r, g, b, a) end
  return line
end

function widgets:ThemeLine(relativeFrame, theme, dim)
  return widgets:NoPointsLine(relativeFrame, 2, unpack(utils:ThemeDownTo01(utils:DimTheme(theme, dim))))
end
