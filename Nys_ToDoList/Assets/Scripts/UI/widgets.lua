-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local utils = addonTable.utils
local enums = addonTable.enums
local widgets = addonTable.widgets
local database = addonTable.database
local dragndrop = addonTable.dragndrop
local mainFrame = addonTable.mainFrame
local databroker = addonTable.databroker
local dataManager = addonTable.dataManager
local tutorialsManager = addonTable.tutorialsManager

-- Variables
local L = core.L

widgets.frame = CreateFrame("Frame", nil, UIParent) -- utility frame
local widgetsFrame = widgets.frame

local tdlButton
local hyperlinkEditBoxes = {}
local descFrames = {}
local descFrameLevelDiff = 20
local categoryNameWidthMax = 220 -- TODO use those from dataManager?
local itemNameWidthMax = 240

local updateRate = 0.05
local refreshRate = 1

-- WoW APIs
local PlaySound = PlaySound
local CreateFrame, UIParent = CreateFrame, UIParent

--/*******************/ MISC /*************************/--

-- // hyperlink edit boxes

function widgets:AddHyperlinkEditBox(editBox)
  table.insert(hyperlinkEditBoxes, editBox)
end

function widgets:RemoveHyperlinkEditBox(editBox)
  table.remove(hyperlinkEditBoxes, select(2, utils:HasValue(hyperlinkEditBoxes, editBox))) -- removing the ref of the hyperlink edit box
end

function widgets:SetEditBoxesHyperlinksEnabled(enabled)
  -- IMPORTANT: this code is to activate hyperlink clicks in edit boxes such as the ones for adding new items in categories,
  -- I disabled this for practical reasons: it's easier to write new item names in them if we can click on the links without triggering the hyperlink (and it's not very useful anyways :D).

  for _, editBox in pairs(hyperlinkEditBoxes) do
    widgets:SetHyperlinksEnabled(editBox, enabled)
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

function widgets:DescFrameHide(itemID)
  -- here, if the name matches one of the opened description frames, we hide that frame, delete it from memory and reupdate the levels of every other active ones
  for pos, frame in ipairs(descFrames) do
    if frame.itemID == itemID then
      frame:Hide()
      widgets:RemoveHyperlinkEditBox(frame.descriptionEditBox.EditBox)
      table.remove(descFrames, pos) -- we remove the desc frame from the descFrames table
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

function widgets:UpdateTDLButtonColor() -- TODO fix calcul (red even when all checked)
  -- the TDL button red option, if any tab has a reset in less than 24 hours,
  -- and also has unchecked items, we color in red the text of the tdl button

  tdlButton:SetNormalFontObject("GameFontNormalLarge") -- by default, we reset the color of the TDL button to yellow
  if NysTDL.db.profile.tdlButton.red then -- if the option is checked
    local maxTime = time() + 86400
    dataManager:DoIfFoundTabMatch(maxTime, "totalUnchecked", function()
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
  local l = widgets:NoPointsLabel(UIParent, nil, text)
  return l:GetWidth()
end

function widgets:SetHyperlinksEnabled(frame, enabled)
  if enabled then
    frame:SetHyperlinksEnabled(true) -- to enable OnHyperlinkClick
    frame:SetScript("OnHyperlinkClick", function(_, linkData, link, button)
      ChatFrame_OnHyperlinkShow(ChatFrame1, linkData, link, button)
    end)
  else
    frame:SetHyperlinksEnabled(false) -- to disable OnHyperlinkClick
    frame:SetScript("OnHyperlinkClick", nil)
  end
end

--/*******************/ FRAMES /*************************/--

function widgets:TutorialFrame(tutoName, showCloseButton, arrowSide, text, width, height)
  local tutoFrame = CreateFrame("Frame", "NysTDL_TutorialFrame_"..tutoName, UIParent, "NysTDL_HelpPlateTooltip")
  tutoFrame:SetSize(width, height)

  if arrowSide == "UP" then tutoFrame.ArrowDOWN:Show()
  elseif arrowSide == "DOWN" then tutoFrame.ArrowUP:Show()
  elseif arrowSide == "LEFT" then tutoFrame.ArrowRIGHT:Show()
  elseif arrowSide == "RIGHT" then tutoFrame.ArrowLEFT:Show() end

  local tutoFrameRightDist = 10 -- TODO redo this dist
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
  -- // the big function to create the description frame for each item

  local itemID = itemWidget.itemID
  local itemData = select(3, dataManager:Find(itemID))

  -- first we check if it's already opened, in which case we act as a toggle, and hide it
  if widgets:DescFrameHide(itemID) then return end

  -- // creating the frame and all of its content

  -- we create the mini frame holding the name of the item and his description in an edit box
  local descFrame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil) -- importing the backdrop in the desc frames, as of wow 9.0
  local w = widgets:GetWidth(itemData.name)
  descFrame:SetSize(w < 180 and 180+75 or w+75, 110) -- 75 is large enough to place the closebutton, clearbutton, and a little bit of space at the right of the name

  -- background
  descFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 1, edgeSize = 10,
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
  })
  descFrame:SetBackdropColor(0, 0, 0, 1)

  -- quick access
  descFrame.itemID = itemID
  descFrame.itemData = itemData

  -- properties
  descFrame:EnableMouse(true)
  descFrame:SetMovable(true)
  descFrame:SetClampedToScreen(true)
  descFrame:SetResizable(true)
  descFrame:SetMinResize(descFrame:GetWidth(), descFrame:GetHeight())
  descFrame:SetToplevel(true)
  widgets:SetHyperlinksEnabled(descFrame, true)

  -- frame vars
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
          local r, g, b = unpack(utils:ThemeDownTo01(database.themes.theme_yellow))
          self.title:SetTextColor(r, g, b, currentAlpha)
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
  descFrame:SetPoint("BOTTOMRIGHT", itemWidget.descBtn, "TOPLEFT", 0, 0) -- we spawn it basically where we clicked

  -- to unlink it from the itemWidget
  descFrame:StartMoving()
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
  descFrame.closeButton:SetScript("OnClick", function() widgets:DescFrameHide(itemID) end)

  -- clear button
  descFrame.clearButton = CreateFrame("Button", "clearButton", descFrame, "NysTDL_ClearButton") -- TODO icon button?
  descFrame.clearButton.tooltip = L["Clear"].."\n("..L["Right-click"]..')'
  descFrame.clearButton:SetPoint("TOPRIGHT", descFrame, "TOPRIGHT", -24, -2)
  descFrame.clearButton:RegisterForClicks("RightButtonUp") -- only responds to right-clicks
  descFrame.clearButton:SetScript("OnClick", function(self)
      self:GetParent().descriptionEditBox.EditBox:SetText("")
  end)

  -- item label
  descFrame.title = descFrame:CreateFontString(nil)
  descFrame.title:SetFontObject("GameFontNormalLarge")
  descFrame.title:SetPoint("TOPLEFT", descFrame, "TOPLEFT", 6, -5)
  descFrame.title:SetText(itemData.name)

  -- description edit box
  descFrame.descriptionEditBox = CreateFrame("ScrollFrame", nil, descFrame, "InputScrollFrameTemplate")
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
    descFrame.descriptionEditBox.EditBox.Instructions:Hide()
  end
  descFrame.descriptionEditBox.EditBox:SetScript("OnTextChanged", function(self)
    -- and here we save the description everytime the text is updated (best auto-save possible I think)
    dataManager:UpdateDescription(itemID, self:GetText())
    self.Instructions:SetShown(self:GetText() == "") -- we show/hide the hint
  end)
  widgets:SetHyperlinksEnabled(descFrame.descriptionEditBox.EditBox, true)
  widgets:AddHyperlinkEditBox(descFrame.descriptionEditBox.EditBox)

  table.insert(descFrames, descFrame) -- we save it for access, level, hide, and alpha purposes

  -- // finished creating the frame

  -- we update the alpha if it needs to be
  mainFrame:Event_FrameAlphaSlider_OnValueChanged(NysTDL.db.profile.frameAlpha)
  mainFrame:Event_FrameContentAlphaSlider_OnValueChanged(NysTDL.db.profile.frameContentAlpha)
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

function widgets:NoPointsInteractiveLabel(relativeFrame, name, text, fontObjectString)
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

function widgets:NothingLabel(relativeFrame) -- TODO this func necessary?
  local label = relativeFrame:CreateFontString(nil)
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

  -- properties
  tdlButton:EnableMouse(true)
  tdlButton:SetMovable(true)
  tdlButton:SetClampedToScreen(true)
  tdlButton:SetToplevel(true)

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

function widgets:RemoveButton(widget)
  local btn = CreateFrame("Button", nil, widget, "NysTDL_RemoveButton")

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

--[[

-- // categoryWidget example:

contentWidgets = {
  [catID] = { -- widgets:CategoryWidget(catID)
    -- data
    enum = enums.category,
    catID = catID,
    catData = catData,
    -- frames
    interactiveLabel,
    favsRemainingLabel,
    addEditBox,
  },
  ...
}

]]

function widgets:CategoryWidget(catID, parentFrame)
  local categoryWidget = CreateFrame("Frame", nil, parentFrame, nil)
  categoryWidget:SetSize(1, 1) -- so that its children are visible

  -- // data

  categoryWidget.enum = enums.category
  categoryWidget.catID = catID
  categoryWidget.catData = select(3, dataManager:Find(catID))
  local catData = categoryWidget.catData

  -- // frames

  -- / interactiveLabel
  categoryWidget.interactiveLabel = widgets:NoPointsInteractiveLabel(categoryWidget, nil, catData.name, "GameFontHighlightLarge")
  categoryWidget.interactiveLabel:SetPoint("LEFT", categoryWidget, "LEFT", 20, 0)

  categoryWidget.interactiveLabel.Button:SetScript("OnEnter", function(self)
    if IsAltKeyDown() then return end
    local r, g, b = unpack(utils:ThemeDownTo01(database.themes.theme))
    self:GetParent().Text:SetTextColor(r, g, b, 1) -- when we hover it, we color the label
    --print("enter")
  end)
  categoryWidget.interactiveLabel.Button:SetScript("OnLeave", function(self)
    self:GetParent().Text:SetTextColor(1, 1, 1, 1) -- back to the default color
    --print("leave")
  end)
  categoryWidget.interactiveLabel.Button:SetScript("OnClick", function(_, button)
    -- we don't do any of the OnClick code if we have the Alt key down,
    -- bc it means that we may want to rename the category by double clicking
    if IsAltKeyDown() then return end

    if button == "LeftButton" then -- we open/close the category
      categoryWidget.addEditBox:SetText(catID) -- TODO remove
      dataManager:ToggleClosed(catID, database.ctab())
    elseif button == "RightButton" then -- we try to toggle the addEditBox
      -- if the cat we right clicked on is NOT a closed category
      if catData.closedInTabIDs[database.ctab()] then return end
      -- we toggle its edit box
      categoryWidget.addEditBox:SetShown(not categoryWidget.addEditBox:IsShown())
      -- categoryWidget.addCatEditBox:SetShown(not categoryWidget.addCatEditBox:IsShown()) -- TDLATER

      if categoryWidget.addEditBox:IsShown() then -- and if we are opening it
        tutorialsManager:Validate("addItem") -- tutorial
        widgets:SetFocusEditBox(categoryWidget.addEditBox) -- we give it the focus
      end
    end
  end)
  categoryWidget.interactiveLabel.Button:SetScript("OnDoubleClick", function(self)
    -- we don't do any of the OnDoubleClick code if we don't have the Alt key down
    if not IsAltKeyDown() then return end

    -- first, we hide the interactiveLabel
    self:GetParent():Hide()

    -- then, we can create the new edit box to rename the category, where the label was
    local renameEditBox = widgets:NoPointsRenameEditBox(categoryWidget, catData.name, categoryNameWidthMax, self:GetHeight())
    renameEditBox:SetPoint("LEFT", categoryWidget.removeBtn, "LEFT", 25, 0)

    -- let's go!
    renameEditBox:SetScript("OnEnterPressed", function(self)
      dataManager:Rename(catID, self:GetText()) -- TODO verify if it closes the box when it doesn't work
    end)

    -- cancelling
    renameEditBox:SetScript("OnEscapePressed", function(self)
      -- we hide the edit box and show the label
      self:Hide()
      categoryWidget.interactiveLabel:Show()
    end)
    renameEditBox:HookScript("OnEditFocusLost", function(self)
      self:GetScript("OnEscapePressed")(self)
    end)
  end)

  -- / removeBtn
  categoryWidget.removeBtn = widgets:RemoveButton(categoryWidget)
  categoryWidget.removeBtn:SetPoint("LEFT", categoryWidget.interactiveLabel, "LEFT", -20, 0)
  categoryWidget.removeBtn:SetScript("OnClick", function() dataManager:DeleteCat(catID) end)

  -- / favsRemainingLabel
  categoryWidget.favsRemainingLabel = widgets:NoPointsLabel(categoryWidget.interactiveLabel, nil, "")
  categoryWidget.favsRemainingLabel:SetPoint("LEFT", categoryWidget.interactiveLabel, "RIGHT", 6, 0)

  -- / originalTabLabel
  categoryWidget.originalTabLabel = widgets:NoPointsLabel(categoryWidget.interactiveLabel, nil, "")
  categoryWidget.originalTabLabel:SetTextColor(0.5, 0.5, 0.5, 0.5)

  -- / emptyLabel
  categoryWidget.emptyLabel = widgets:NoPointsLabel(categoryWidget, nil, "this category is empty")
  categoryWidget.emptyLabel:SetPoint("LEFT", categoryWidget, "TOPLEFT", enums.ofsxContent, -enums.ofsyCatContent)
  categoryWidget.emptyLabel:SetTextColor(0.5, 0.5, 0.5, 0.5)

  -- / addEditBox
  categoryWidget.addEditBox = widgets:NoPointsCatEditBox(categoryWidget)
  categoryWidget.addEditBox:SetPoint("RIGHT", categoryWidget.interactiveLabel, "LEFT", 270, 0)
  categoryWidget.addEditBox:SetPoint("LEFT", categoryWidget.interactiveLabel, "RIGHT", 10, 0)
  categoryWidget.addEditBox:SetSize(100, 30)
  categoryWidget.addEditBox:Hide()
  -- TODO check this
  -- -- edit box width (we adapt it based on the category label's width)
  -- local labelWidth = tonumber(string.format("%i", categoryWidget.interactiveLabel.Text:GetWidth()))
  -- local rightPointDistance = 297 -- in alignment with the item renaming edit boxes
  -- local editBoxAddItemWidth = 150 -- max width
  -- if labelWidth + editBoxAddItemWidth > rightPointDistance then
  --   categoryWidget.addEditBox:SetSize(editBoxAddItemWidth - 10 - ((labelWidth + editBoxAddItemWidth) - rightPointDistance), categoryWidget.interactiveLabel.Button:GetHeight())
  -- else
  --   categoryWidget.addEditBox:SetSize(editBoxAddItemWidth - 10, categoryWidget.interactiveLabel.Button:GetHeight())
  -- end
  categoryWidget.addEditBox:SetScript("OnEnterPressed", function(self)
    if dataManager:CreateItem(self:GetText(), catData.originalTabID, catID) then
      self:SetText("") -- we clear the box if the adding was a success
    end
    self:Show() -- we keep it shown to add more items
    widgets:SetFocusEditBox(self)
  end)
  -- cancelling
  categoryWidget.addEditBox:SetScript("OnEscapePressed", function(self)
    self:Hide()
  end)
  categoryWidget.addEditBox:HookScript("OnEditFocusLost", function(self)
    self:GetScript("OnEscapePressed")(self)
  end)
  widgets:AddHyperlinkEditBox(categoryWidget.addEditBox)

  -- TDLATER sub-cat creation
  -- -- / addCatEditBox
  -- categoryWidget.addCatEditBox = widgets:NoPointsCatEditBox(categoryWidget)
  -- categoryWidget.addCatEditBox:SetPoint("RIGHT", categoryWidget.interactiveLabel, "LEFT", 270, -20)
  -- categoryWidget.addCatEditBox:SetPoint("LEFT", categoryWidget.interactiveLabel, "RIGHT", 10, -20)
  -- categoryWidget.addCatEditBox:SetSize(100, 30)
  -- categoryWidget.addCatEditBox:Hide()
  -- categoryWidget.addCatEditBox:SetScript("OnEnterPressed", function(self)
  --   if dataManager:CreateCategory(self:GetText(), catData.originalTabID, catID) then
  --     self:SetText("") -- we clear the box if the adding was a success
  --   end
  --   self:Show() -- we keep it shown to add more categories
  --   widgets:SetFocusEditBox(self)
  -- end)
  -- -- cancelling
  -- categoryWidget.addCatEditBox:SetScript("OnEscapePressed", function(self)
  --   self:Hide()
  -- end)
  -- categoryWidget.addCatEditBox:HookScript("OnEditFocusLost", function(self)
  --   self:GetScript("OnEscapePressed")(self)
  -- end)

  -- / drag&drop
  dragndrop:RegisterForDrag(categoryWidget)

  return categoryWidget
end

--[[

-- // itemWidget example:

contentWidgets = {
  [itemID] = { -- widgets:CategoryWidget(catID)
    -- data
    enum = enums.item,
    itemID = itemID,
    itemData = itemData,
    -- frames
    checkBtn,
    interactiveLabel,
    removeBtn,
    favoriteBtn,
    descBtn,
  },
  ...
}

]]

function widgets:ItemWidget(itemID, parentFrame)
  local itemWidget = CreateFrame("Frame", nil, parentFrame, nil)
  itemWidget:SetSize(1, 1) -- so that its children are visible

  -- // data

  itemWidget.enum = enums.item
  itemWidget.itemID = itemID
  itemWidget.itemData = select(3, dataManager:Find(itemID))
  local itemData = itemWidget.itemData

  -- // frames

  -- / checkBtn
  itemWidget.checkBtn = CreateFrame("CheckButton", nil, itemWidget, "UICheckButtonTemplate")
  -- itemWidget.checkBtn = CreateFrame("CheckButton", nil, itemWidget, "ChatConfigCheckButtonTemplate")
  -- itemWidget.checkBtn = CreateFrame("CheckButton", nil, itemWidget, "OptionsCheckButtonTemplate")
  itemWidget.checkBtn:SetPoint("LEFT", itemWidget, "LEFT", 20, 0)
  itemWidget.checkBtn:SetScript("OnClick", function() dataManager:ToggleChecked(itemID) end)
  -- itemWidget.checkBtn:SetSize(26, 26)
  -- itemWidget.checkBtn:SetHitRectInsets(0, -widgets:GetWidth(itemData.name), 0, 0)

  -- / interactiveLabel
  itemWidget.interactiveLabel = widgets:NoPointsInteractiveLabel(itemWidget, nil, itemData.name, "GameFontNormalLarge")
  itemWidget.interactiveLabel:SetPoint("LEFT", itemWidget.checkBtn, "RIGHT")
  itemWidget.interactiveLabel.Text:SetPoint("LEFT", itemWidget.checkBtn, "RIGHT", 20, 0) -- TODO why this line?

  if utils:HasHyperlink(itemData.name) then -- this is for making more space for items that have hyperlinks in them
    if itemWidget.interactiveLabel.Text:GetWidth() > itemNameWidthMax then
      itemWidget.interactiveLabel.Text:SetFontObject("GameFontNormal")
    end

    -- and also to deactivate the InteractiveLabel's Button, so that we can actually click on the links
    -- unless we are holding Alt, and to detect this, we actually put on them an OnUpdate script
    itemWidget.interactiveLabel:SetScript("OnUpdate", function(self) -- TODO OULA
      if IsAltKeyDown() then
        self.Button:Show()
      else
        self.Button:Hide()
      end
    end)
  end

  widgets:SetHyperlinksEnabled(itemWidget.interactiveLabel, true)
  itemWidget.interactiveLabel.Button:SetScript("OnDoubleClick", function(self)
    -- first, we hide the interactiveLabel
    self:GetParent():Hide()

    -- then, we can create the new edit box to rename the item, where the label was
    local renameEditBox = widgets:NoPointsRenameEditBox(itemWidget, itemData.name, itemNameWidthMax, self:GetHeight())
    renameEditBox:SetPoint("LEFT", itemWidget.checkBtn, "RIGHT", 5, 0)
    -- widgets:SetHyperlinksEnabled(renameEditBox, true)
    widgets:AddHyperlinkEditBox(renameEditBox) -- so that we can add hyperlinks in it

    -- cancelling
    renameEditBox:SetScript("OnEscapePressed", function(self)
      -- we hide the edit box and show the label
      self:Hide()
      categoryWidget.interactiveLabel:Show()

      -- when hiding the edit box, we reset the pos of the favsRemainingLabel
      categoryWidget.favsRemainingLabel:ClearAllPoints()
      categoryWidget.favsRemainingLabel:SetPoint("LEFT", categoryWidget.interactiveLabel, "RIGHT", 6, 0)
    end)
    renameEditBox:HookScript("OnEditFocusLost", function(self)
      self:GetScript("OnEscapePressed")(self)
    end)


    -- let's go!
    renameEditBox:SetScript("OnEnterPressed", function(self)
      dataManager:Rename(itemID, self:GetText()) -- TODO verify if it closes the box when it doesn't work
    end)

    -- cancelling
    renameEditBox:SetScript("OnEscapePressed", function(self)
      -- we hide the edit box and show the label
      self:Hide()
      itemWidget.interactiveLabel:Show()
      widgets:RemoveHyperlinkEditBox(self)
    end)
    renameEditBox:HookScript("OnEditFocusLost", function(self)
      self:GetScript("OnEscapePressed")(self)
    end)
  end)

  -- / removeBtn
  itemWidget.removeBtn = widgets:RemoveButton(itemWidget)
  itemWidget.removeBtn:SetPoint("LEFT", itemWidget.checkBtn, "LEFT", -20, 0)
  itemWidget.removeBtn:SetScript("OnClick", function() dataManager:DeleteItem(itemID) end)

  -- / favoriteBtn
  itemWidget.favoriteBtn = widgets:FavoriteButton(itemWidget)
  itemWidget.favoriteBtn:SetScript("OnClick", function() dataManager:ToggleFavorite(itemID) end)
  itemWidget.favoriteBtn:Hide()

  -- / descBtn
  itemWidget.descBtn = widgets:DescButton(itemWidget)
  itemWidget.descBtn:SetScript("OnClick", function() widgets:DescriptionFrame(itemWidget) end)
  itemWidget.descBtn:Hide()

  -- / drag&drop
  dragndrop:RegisterForDrag(itemWidget)

  return itemWidget
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

function widgets:NoPointsCatEditBox(categoryWidget)
  local edb = CreateFrame("EditBox", nil, categoryWidget, "InputBoxTemplate")
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

--/*******************/ INITIALIZATION /*************************/--

local function OnUpdate(self, elapsed)
  widgetsFrame.timeSinceLastUpdate = widgetsFrame.timeSinceLastUpdate + elapsed
  widgetsFrame.timeSinceLastRefresh = widgetsFrame.timeSinceLastRefresh + elapsed

  -- // every frame // --

  -- tuto frames visibility
  tutorialsManager:UpdateFramesVisibility()

  -- // ----------- // --

  while widgetsFrame.timeSinceLastUpdate > updateRate do
    widgetsFrame.timeSinceLastUpdate = widgetsFrame.timeSinceLastUpdate - updateRate

    -- // every 0.05 sec // -- (instead of every frame which is every 1/144 (0.007) sec for a 144hz display... optimization :D)

    -- rainbow update
    if NysTDL.db.profile.rainbow then
      if #descFrames > 0 or mainFrame:GetFrame():IsShown() then -- we don't really need to update the color at all times
        mainFrame:ApplyNewRainbowColor()
      end
    end

    -- // -------------- // --

    while widgetsFrame.timeSinceLastRefresh > refreshRate do
      widgetsFrame.timeSinceLastRefresh = widgetsFrame.timeSinceLastRefresh - refreshRate

      -- // every 1 sec // --

      -- xxx

      -- // ----------- // --
    end
  end
end

function widgets:Initialize()
  -- first we create every visual widget of every file
  tutorialsManager:CreateTutoFrames()
  widgets:CreateTDLButton()
  databroker:CreateDatabrokerObject()
  databroker:CreateTooltipFrame() -- TODO redo this later
  databroker:CreateMinimapButton()
  mainFrame:CreateTDLFrame()

  -- then we manage the widgetsFrame
  widgetsFrame.timeSinceLastUpdate = 0
  widgetsFrame.timeSinceLastRefresh = 0
  widgetsFrame:SetScript("OnUpdate", OnUpdate)
end

function widgets:ProfileChanged()
  -- visual updates to match the new profile
  widgets:RefreshTDLButton()
  databroker:SetMode(NysTDL.db.profile.databrokerMode)
  -- TODO a terme ici ligne pr refresh tooltip frame de databroker
  databroker:RefreshMinimapButton()

  widgets:WipeDescFrames()
  mainFrame:Init()
end
