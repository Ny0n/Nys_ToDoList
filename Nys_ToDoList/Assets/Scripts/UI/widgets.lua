-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local widgets = addonTable.widgets
local utils = addonTable.utils

-- Variables
local L = addonTable.core.L

local hyperlinkEditBoxes = {}
local dummyFrame = nil -- TODO

--/*******************/ MISC /*************************/--

-- // hyperlink edit boxes

function widgets:AddHyperlinkEditBox(editBox)
  table.insert(hyperlinkEditBoxes, editBox)
end

function widgets:RemoveHyperlinkEditBox(editBox)
  table.remove(hyperlinkEditBoxes, select(2, utils:HasValue(hyperlinkEditBoxes, editBox))) -- removing the ref of the hyperlink edit box
end

function widgets:SetHyperlinkClicks(activated)
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

-- // other

function widgets:SetFocusEditBox(editBox) -- DRY
  editBox:SetFocus()
  if (NysTDL.db.profile.highlightOnFocus) then
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

function widgets:DescriptionFrameHide(name)
  -- here, if the name matches one of the opened description frames, we hide that frame, delete it from memory and reupdate the levels of every other active ones
  for pos, v in pairs(descFrames) do
    if (v:GetName() == name) then
      v:Hide()
      table.remove(hyperlinkEditBoxes, select(2, config:HasItem(hyperlinkEditBoxes, v.descriptionEditBox.EditBox))) -- removing the ref of the hyperlink edit box
      table.remove(descFrames, pos)
      for pos2, v2 in pairs(descFrames) do -- we reupdate the frame levels
        v2:SetFrameLevel(300 + (pos2-1)*descFrameLevelDiff)
      end
      return true
    end
  end
  return false
end

--/*******************/ FRAMES /*************************/--

function widgets:TutorialFrame(tutoName, parent, showCloseButton, arrowSide, text, width, height)
  local tutoFrame = CreateFrame("Frame", "NysTDL_tutoFrame_"..tutoName, parent, "NysTDL_HelpPlateTooltip")
  tutoFrame:SetSize(width, height)
  if (arrowSide == "UP") then tutoFrame.ArrowDOWN:Show()
  elseif (arrowSide == "DOWN") then tutoFrame.ArrowUP:Show()
  elseif (arrowSide == "LEFT") then tutoFrame.ArrowRIGHT:Show()
  elseif (arrowSide == "RIGHT") then tutoFrame.ArrowLEFT:Show() end
  local tutoFrameRightDist = 10
  if (showCloseButton) then
    tutoFrameRightDist = 40
    tutoFrame.closeButton = CreateFrame("Button", "closeButton", tutoFrame, "UIPanelCloseButton")
    tutoFrame.closeButton:SetPoint("TOPRIGHT", tutoFrame, "TOPRIGHT", 6, 6)
    tutoFrame.closeButton:SetScript("OnClick", function() NysTDL.db.global.tuto_progression = NysTDL.db.global.tuto_progression + 1 end)
  end
  tutoFrame.Text:SetWidth(tutoFrame:GetWidth() - tutoFrameRightDist)
  tutoFrame.Text:SetText(text)
  tutoFrame:Hide() -- we hide them by default, we show them only when we need to

  return tutoFrame
end

function widgets:DescriptionFrame(args)
  -- TODO
end

function itemsFrame:DescriptionClick(self)
  -- the big function to create the description frame for each items

  local catName, itemName = self:GetParent().catName, self:GetParent().itemName

  if (widgets:DescriptionFrameHide("NysTDL_DescFrame_"..catName.."_"..itemName)) then return end

  -- we create the mini frame holding the name of the item and his description in an edit box
  local descFrame = CreateFrame("Frame", "NysTDL_DescFrame_"..catName.."_"..itemName, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil) -- importing the backdrop in the desc frames, as of wow 9.0
  local w = config:CreateNoPointsLabel(UIParent, nil, itemName):GetWidth()
  descFrame:SetSize((w < 180) and 180+75 or w+75, 110) -- 75 is large enough to place the closebutton, clearbutton, and a little bit of space at the right of the name

  -- background
  descFrame:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = false, tileSize = 1, edgeSize = 10, insets = { left = 1, right = 1, top = 1, bottom = 1 }})
  descFrame:SetBackdropColor(0, 0, 0, 1)

  -- properties
  descFrame:SetResizable(true)
  descFrame:SetMinResize(descFrame:GetWidth(), descFrame:GetHeight())
  descFrame:SetFrameLevel(300 + #descFrames*descFrameLevelDiff)
  descFrame:SetMovable(true)
  descFrame:SetClampedToScreen(true)
  descFrame:EnableMouse(true)
  descFrame.timeSinceLastUpdate = 0 -- for the updating of the title's color and alpha
  descFrame.opening = 0 -- for the scrolling up on opening

  -- to move the frame
  descFrame:SetScript("OnMouseDown", function(self, button)
      if (button == "LeftButton") then
          self:StartMoving()
      end
  end)
  descFrame:SetScript("OnMouseUp", descFrame.StopMovingOrSizing)

  -- other scripts
  descFrame:SetScript("OnUpdate", function(self, elapsed)
    self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed

    while (self.timeSinceLastUpdate > updateRate) do -- every 0.05 sec (instead of every frame which is every 1/144 (0.007) sec for a 144hz display... optimization :D)
      -- we update non-stop the color of the title
      local currentAlpha = NysTDL.db.profile.descFrameContentAlpha/100
      if (checkBtn[catName][itemName]:GetChecked()) then
        self.title:SetTextColor(0, 1, 0, currentAlpha)
      else
        if (NysTDL.db.profile.itemsList[catName][itemName].favorite) then
          local r, g, b = unpack(NysTDL.db.profile.favoritesColor)
          self.title:SetTextColor(r, g, b, currentAlpha)
        else
          local r, g, b = unpack(config:ThemeDownTo01(config.database.theme_yellow))
          self.title:SetTextColor(r, g, b, currentAlpha)
        end
      end

      -- if the desc frame is the oldest (the first opened on screen, or subsequently the one who has the lowest frame level)
      -- we use that one to cycle the rainbow colors if the list gets closed
      if (not itemsFrameUI:IsShown()) then
        if (self:GetFrameLevel() == 300) then
          if (NysTDL.db.profile.rainbow) then itemsFrame:ApplyNewRainbowColor(NysTDL.db.profile.rainbowSpeed) end
        end
      end

      self.timeSinceLastUpdate = self.timeSinceLastUpdate - updateRate
    end

    -- and we also update non-stop the width of the description edit box to match that of the frame if we resize it, and when the scrollbar kicks in. (this is the secret to make it work)
    self.descriptionEditBox.EditBox:SetWidth(self.descriptionEditBox:GetWidth() - (self.descriptionEditBox.ScrollBar:IsShown() and 15 or 0))

    if (self.opening < 5) then -- doing this only on the 5 first updates after creating the frame, i won't go into the details but updating the vertical scroll of this template is a real fucker :D
      self.descriptionEditBox:SetVerticalScroll(0)
      self.opening = self.opening + 1
    end
  end)

  -- position
  descFrame:ClearAllPoints()
  descFrame:SetParent(UIParent)
  descFrame:SetPoint("BOTTOMRIGHT", self, "TOPLEFT", 0, 0)
  descFrame:StartMoving() -- to unlink it from the itemsframe
  descFrame:StopMovingOrSizing()

  -- / content of the frame / --

  -- resize button
  descFrame.resizeButton = CreateFrame("Button", nil, descFrame, "NysTDL_ResizeButton")
  descFrame.resizeButton:SetPoint("BOTTOMRIGHT")
  descFrame.resizeButton:SetScript("OnMouseDown", function(self, button)
    if (button == "LeftButton") then
      descFrame:StartSizing("BOTTOMRIGHT")
      self:GetHighlightTexture():Hide() -- more noticeable
    end
  end)
  descFrame.resizeButton:SetScript("OnMouseUp", function(self)
    descFrame:StopMovingOrSizing()
    self:GetHighlightTexture():Show()
  end)

  -- close button
  descFrame.closeButton = CreateFrame("Button", "closeButton", descFrame, "NysTDL_CloseButton")
  descFrame.closeButton:SetPoint("TOPRIGHT", descFrame, "TOPRIGHT", -2, -2)
  descFrame.closeButton:SetScript("OnClick", function(self)
      widgets:DescriptionFrameHide(self:GetParent():GetName())
  end)

  -- clear button
  descFrame.clearButton = CreateFrame("Button", "clearButton", descFrame, "NysTDL_ClearButton")
  descFrame.clearButton.tooltip = L["Clear"].."\n("..L["Right-click"]..')'
  descFrame.clearButton:SetPoint("TOPRIGHT", descFrame, "TOPRIGHT", -24, -2)
  descFrame.clearButton:RegisterForClicks("RightButtonUp")
  descFrame.clearButton:SetScript("OnClick", function(self)
      local eb = self:GetParent().descriptionEditBox.EditBox
      eb:SetText("")
      eb:GetScript("OnKeyUp")(eb)
  end)

  -- item label
  descFrame.title = descFrame:CreateFontString(itemName.."_descFrameTitle")
  descFrame.title:SetFontObject("GameFontNormalLarge")
  descFrame.title:SetPoint("TOPLEFT", descFrame, "TOPLEFT", 6, -5)
  descFrame.title:SetText(itemName)
  descFrame:SetHyperlinksEnabled(true) -- to enable OnHyperlinkClick
  descFrame:SetScript("OnHyperlinkClick", function(_, linkData, link, button)
    ChatFrame_OnHyperlinkShow(ChatFrame1, linkData, link, button)
  end)

  -- description edit box
  descFrame.descriptionEditBox = CreateFrame("ScrollFrame", itemName.."_descFrameEditBox", descFrame, "InputScrollFrameTemplate")
  descFrame.descriptionEditBox.EditBox:SetFontObject("ChatFontNormal")
  descFrame.descriptionEditBox.EditBox:SetAutoFocus(false)
  descFrame.descriptionEditBox.EditBox:SetMaxLetters(0)
  descFrame.descriptionEditBox.CharCount:Hide()
  descFrame.descriptionEditBox.EditBox.Instructions:SetFontObject("GameFontNormal")
  descFrame.descriptionEditBox.EditBox.Instructions:SetText(L["Add a description..."].."\n"..L["(automatically saved)"])
  descFrame.descriptionEditBox:SetPoint("TOPLEFT", descFrame, "TOPLEFT", 10, -30)
  descFrame.descriptionEditBox:SetPoint("BOTTOMRIGHT", descFrame, "BOTTOMRIGHT", -10, 10)
  if (NysTDL.db.profile.itemsList[catName][itemName].description) then -- if there is already a description for this item, we write it on frame creation
    descFrame.descriptionEditBox.EditBox:SetText(NysTDL.db.profile.itemsList[catName][itemName].description)
  end
  descFrame.descriptionEditBox.EditBox:SetScript("OnKeyUp", function(self)
    -- and here we save the description everytime we lift a finger (best auto-save possible I think)
    NysTDL.db.profile.itemsList[catName][itemName].description = (self:GetText() ~= "") and self:GetText() or nil
    if (IsControlKeyDown()) then -- just in case we are ctrling-v, to color the icon
      descBtn[catName][itemName]:GetScript("OnShow")(descBtn[catName][itemName])
    end
  end)
  descFrame.descriptionEditBox.EditBox:SetHyperlinksEnabled(true) -- to enable OnHyperlinkClick
  descFrame.descriptionEditBox.EditBox:SetScript("OnHyperlinkClick", function(_, linkData, link, button)
    ChatFrame_OnHyperlinkShow(ChatFrame1, linkData, link, button)
  end)
  table.insert(hyperlinkEditBoxes, descFrame.descriptionEditBox.EditBox)

  table.insert(descFrames, descFrame) -- we save it for level, hide, and alpha purposes

  -- we update the alpha if it needs to be
  FrameAlphaSlider_OnValueChanged(nil, NysTDL.db.profile.frameAlpha)
  FrameContentAlphaSlider_OnValueChanged(nil, NysTDL.db.profile.frameContentAlpha)

  itemsFrame:ReloadTab() -- we reload the tab to instantly display the changes
end

function widgets:Dummy(parentFrame, relativeFrame, xOffset, yOffset)
  local dummy = CreateFrame("Frame", nil, parentFrame, nil)
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
  local label = CreateFrame("Frame", name, relativeFrame, "NysTDL_InteractiveLabel")
  label.Text:SetFontObject(fontObjectString)
  label.Text:SetText(text)
  label:SetSize(label.Text:GetWidth(), label.Text:GetHeight()) -- we init the size to the text's size

  -- this updates the frame's size each time the text's size is changed
  label.Button:SetScript("OnSizeChanged", function(self, width, height)
    self:GetParent():SetSize(width, height)
  end)

  return label
end

function widgets:NothingLabel(relativeFrame)
  local label = relativeFrame:CreateFontString(nil)
  label:SetFontObject("GameFontHighlightLarge")
  label:SetTextColor(0.5, 0.5, 0.5, 0.5)
  return label
end

--/*******************/ BUTTONS /*************************/--

function widgets:Button(name, relativeFrame, text, iconPath, fc)
  fc = fc or false
  iconPath = (type(iconPath) == "string") and iconPath or nil
  local btn = CreateFrame("Button", name, relativeFrame, "NysTDL_NormalButton")
  local w = self:NoPointsLabel(relativeFrame, nil, text):GetWidth()
  btn:SetText(text)
  btn:SetNormalFontObject("GameFontNormalLarge")
  if (fc == true) then btn:SetHighlightFontObject("GameFontHighlightLarge") end
  if (iconPath ~= nil) then
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

-- item buttons

function widgets:RemoveButton(relativeCheckButton)
  local btn = CreateFrame("Button", nil, relativeCheckButton, "NysTDL_RemoveButton")
  btn:SetPoint("LEFT", relativeCheckButton, "LEFT", - 20, 0)

  -- these are for changing the color depending on the mouse actions (since they are custom xml)
  btn:HookScript("OnEnter", function(self)
    self.Icon:SetVertexColor(0.8, 0.2, 0.2)
  end)
  btn:HookScript("OnLeave", function(self)
    if (tonumber(string.format("%.1f", self.Icon:GetAlpha())) ~= 0.5) then
      self.Icon:SetVertexColor(1, 1, 1)
    end
  end)
  btn:HookScript("OnMouseUp", function(self)
    if (self.name == "RemoveButton") then
      self.Icon:SetVertexColor(1, 1, 1)
    end
  end)
  btn:HookScript("OnShow", function(self)
    self.Icon:SetVertexColor(1, 1, 1)
  end)
  return btn
end

function widgets:FavoriteButton(relativeCheckButton, catName, itemName)
  local btn = CreateFrame("Button", nil, relativeCheckButton, "NysTDL_FavoriteButton")
  btn:SetPoint("LEFT", relativeCheckButton, "LEFT", - 20, -2)

  -- these are for changing the color depending on the mouse actions (since they are custom xml)
  -- and yea, this one's a bit complicated because I wanted its look to be really precise...
  btn:HookScript("OnEnter", function(self)
    if (not utils:ItemExists(catName, itemName)) then return end
    if (not NysTDL.db.profile.itemsList[catName][itemName].favorite) then -- not favorited
      self.Icon:SetDesaturated(nil)
      self.Icon:SetVertexColor(1, 1, 1)
    else
      self:SetAlpha(0.6)
    end
  end)
  btn:HookScript("OnLeave", function(self)
    if (not utils:ItemExists(catName, itemName)) then return end
    if (not NysTDL.db.profile.itemsList[catName][itemName].favorite) then
      if (tonumber(string.format("%.1f", self.Icon:GetAlpha())) ~= 0.5) then -- if we are currently clicking on the button
        self.Icon:SetDesaturated(1)
        self.Icon:SetVertexColor(0.4, 0.4, 0.4)
      end
    else
      self:SetAlpha(1)
    end
   end)
   btn:HookScript("OnMouseUp", function(self)
     if (not utils:ItemExists(catName, itemName)) then return end
     if (self.name == "FavoriteButton") then
       self:SetAlpha(1)
       if (not NysTDL.db.profile.itemsList[catName][itemName].favorite) then
         self.Icon:SetDesaturated(1)
         self.Icon:SetVertexColor(0.4, 0.4, 0.4)
       end
     end
   end)
   btn:HookScript("PostClick", function(self)
     if (self.name == "FavoriteButton") then
       self:GetScript("OnShow")(self)
     end
   end)
  btn:HookScript("OnShow", function(self)
    if (not utils:ItemExists(catName, itemName)) then return end
    self:SetAlpha(1)
    if (not NysTDL.db.profile.itemsList[catName][itemName].favorite) then
      self.Icon:SetDesaturated(1)
      self.Icon:SetVertexColor(0.4, 0.4, 0.4)
    else
      self.Icon:SetDesaturated(nil)
      self.Icon:SetVertexColor(1, 1, 1)
    end
  end)
  return btn
end

function widgets:DescButton(relativeCheckButton, catName, itemName)
  local btn = CreateFrame("Button", nil, relativeCheckButton, "NysTDL_DescButton")
  btn:SetPoint("LEFT", relativeCheckButton, "LEFT", - 20, 0)

  -- these are for changing the color depending on the mouse actions (since they are custom xml)
  -- and yea, this one's a bit complicated too because it works in very specific ways
  btn:HookScript("OnEnter", function(self)
    if (not utils:ItemExists(catName, itemName)) then return end
    if (not NysTDL.db.profile.itemsList[catName][itemName].description) then -- no description
      self.Icon:SetDesaturated(nil)
      self.Icon:SetVertexColor(1, 1, 1)
    else
      self:SetAlpha(0.6)
    end
  end)
  btn:HookScript("OnLeave", function(self)
    if (not utils:ItemExists(catName, itemName)) then return end
    if (not NysTDL.db.profile.itemsList[catName][itemName].description) then
      if (tonumber(string.format("%.1f", self.Icon:GetAlpha())) ~= 0.5) then -- if we are currently clicking on the button
        self.Icon:SetDesaturated(1)
        self.Icon:SetVertexColor(0.4, 0.4, 0.4)
      end
    else
      self:SetAlpha(1)
    end
   end)
   btn:HookScript("OnMouseUp", function(self)
     if (not utils:ItemExists(catName, itemName)) then return end
     if (self.name == "DescButton") then
       self:SetAlpha(1)
       if (not NysTDL.db.profile.itemsList[catName][itemName].description) then
         self.Icon:SetDesaturated(1)
         self.Icon:SetVertexColor(0.4, 0.4, 0.4)
       end
     end
   end)
   btn:HookScript("PostClick", function(self)
     if (self.name == "DescButton") then
       self:GetScript("OnShow")(self)
     end
   end)
  btn:HookScript("OnShow", function(self)
    if (not utils:ItemExists(catName, itemName)) then return end
    self:SetAlpha(1)
    if (not NysTDL.db.profile.itemsList[catName][itemName].description) then
      self.Icon:SetDesaturated(1)
      self.Icon:SetVertexColor(0.4, 0.4, 0.4)
    else
      self.Icon:SetDesaturated(nil)
      self.Icon:SetVertexColor(1, 1, 1)
    end
  end)
  return btn
end

--/*******************/ EDIT BOXES /*************************/--

function widgets:NoPointsRenameEditBox(relativeFrame, text, width, height)
  local renameEditBox = CreateFrame("EditBox", relativeFrame:GetName().."_renameEditBox", relativeFrame, "InputBoxTemplate")
  renameEditBox:SetSize(width-10, height)
  renameEditBox:SetText(text)
  renameEditBox:SetFontObject("GameFontHighlightLarge")
  renameEditBox:SetAutoFocus(false)
  renameEditBox:SetFocus()
  if (not NysTDL.db.profile.highlightOnFocus) then
    renameEditBox:HighlightText(0, 0)
  end
  -- renameEditBox:HookScript("OnEditFocusGained", function(self)
  --   self:HighlightText(0, 0) -- we don't select everything by default when we select the edit box
  -- end)
  return renameEditBox
end

function widgets:NoPointsLabelEditBox(name)
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
  if (r and g and b and a) then line:SetColorTexture(r, g, b, a) end
  return line
end
