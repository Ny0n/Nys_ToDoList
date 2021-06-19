-- Namespaces
local addonName, addonTable = ...

local config = addonTable.config
local utils = addonTable.utils
local autoReset = addonTable.autoReset
local widgets = addonTable.widgets
local itemsFrame = addonTable.itemsFrame
local init = addonTable.init

-- Variables

local L = config.L

--/*******************/ WIDGET CREATION FUNCTIONS /*************************/--

function widgets.tutorialFrame(tutoName, parent, showCloseButton, arrowSide, text, width, height)
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

function widgets.noPointsLabel(relativeFrame, name, text)
  local label = relativeFrame:CreateFontString(name)
  label:SetFontObject("GameFontHighlightLarge")
  label:SetText(text)
  return label
end

function widgets.noPointsInteractiveLabel(name, relativeFrame, text, fontObjectString)
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

function widgets.nothingLabel(relativeFrame)
  local label = relativeFrame:CreateFontString(nil)
  label:SetFontObject("GameFontHighlightLarge")
  label:SetTextColor(0.5, 0.5, 0.5, 0.5)
  return label
end

function widgets.button(name, relativeFrame, text, iconPath, fc)
  fc = fc or false
  iconPath = (type(iconPath) == "string") and iconPath or nil
  local btn = CreateFrame("Button", name, relativeFrame, "NysTDL_NormalButton")
  local w = widgets.noPointsLabel(relativeFrame, nil, text):GetWidth()
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

function widgets.helpButton(relativeFrame)
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

function widgets.removeButton(relativeCheckButton)
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

function widgets.favoriteButton(relativeCheckButton, catName, itemName)
  local btn = CreateFrame("Button", nil, relativeCheckButton, "NysTDL_FavoriteButton")
  btn:SetPoint("LEFT", relativeCheckButton, "LEFT", - 20, -2)

  -- these are for changing the color depending on the mouse actions (since they are custom xml)
  -- and yea, this one's a bit complicated because I wanted its look to be really precise...
  btn:HookScript("OnEnter", function(self)
    if (not utils.itemExists(catName, itemName)) then return end
    if (not NysTDL.db.profile.itemsList[catName][itemName].favorite) then -- not favorited
      self.Icon:SetDesaturated(nil)
      self.Icon:SetVertexColor(1, 1, 1)
    else
      self:SetAlpha(0.6)
    end
  end)
  btn:HookScript("OnLeave", function(self)
    if (not utils.itemExists(catName, itemName)) then return end
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
     if (not utils.itemExists(catName, itemName)) then return end
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
    if (not utils.itemExists(catName, itemName)) then return end
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

function widgets.descButton(relativeCheckButton, catName, itemName)
  local btn = CreateFrame("Button", nil, relativeCheckButton, "NysTDL_DescButton")
  btn:SetPoint("LEFT", relativeCheckButton, "LEFT", - 20, 0)

  -- these are for changing the color depending on the mouse actions (since they are custom xml)
  -- and yea, this one's a bit complicated too because it works in very specific ways
  btn:HookScript("OnEnter", function(self)
    if (not utils.itemExists(catName, itemName)) then return end
    if (not NysTDL.db.profile.itemsList[catName][itemName].description) then -- no description
      self.Icon:SetDesaturated(nil)
      self.Icon:SetVertexColor(1, 1, 1)
    else
      self:SetAlpha(0.6)
    end
  end)
  btn:HookScript("OnLeave", function(self)
    if (not utils.itemExists(catName, itemName)) then return end
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
     if (not utils.itemExists(catName, itemName)) then return end
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
    if (not utils.itemExists(catName, itemName)) then return end
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

function widgets.noPointsRenameEditBox(relativeFrame, text, width, height)
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

function widgets.noPointsLabelEditBox(name)
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

function widgets.dummy(parentFrame, relativeFrame, xOffset, yOffset)
  local dummy = CreateFrame("Frame", nil, parentFrame, nil)
  dummy:SetPoint("TOPLEFT", relativeFrame, "TOPLEFT", xOffset, yOffset)
  dummy:SetSize(1, 1)
  dummy:Show()
  return dummy
end

function widgets.noPointsLine(relativeFrame, thickness, r, g, b, a)
  a = a or 1
  local line = relativeFrame:CreateLine()
  line:SetThickness(thickness)
  if (r and g and b and a) then line:SetColorTexture(r, g, b, a) end
  return line
end
