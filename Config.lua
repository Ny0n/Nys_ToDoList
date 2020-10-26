-- Namespaces
local _, tdlTable = ...;
tdlTable.config = {}; -- adds config table to addon namespace

local config = tdlTable.config;

--------------
-- Database
--------------

local database = {
  theme = {
    r = 0,
    g = 0.8, -- 204/255
    b = 1,
    hex = "00ccff"
  },
}

--------------------------------------
-- General config functions
--------------------------------------

-- Other general purposes functions:
function config:Print(...)
  if (not ToDoListSV.showChatMessages) then return; end -- we don't print anything if the user chose to deactivate this

  local hex = (select(4, config:GetThemeColor()));
  local prefix = string.format("|cff%s%s|r", hex:upper(), "ToDoList:");

  local tab = {}
  for i = 0, #... do
    local s = (select(i + 1, ...))
    if type(s) == "table" then
      for i = 0, #s do
        table.insert(tab, (select(i + 1, unpack(s))))
      end
    else
      table.insert(tab, s)
    end
  end

  DEFAULT_CHAT_FRAME:AddMessage(string.join(' ', prefix, unpack(tab)))
end

function config:GetThemeColor()
  local c = database.theme;
  return c.r, c.g, c.b, c.hex;
end

function config:GetDayByNumber(n)
  if (n == 1) then return "Sunday" end
  if (n == 2) then return "Monday" end
  if (n == 3) then return "Tuesday" end
  if (n == 4) then return "Wednesday" end
  if (n == 5) then return "Thursday" end
  if (n == 6) then return "Friday" end
  if (n == 7) then return "Saturday" end
end

function config:HasItem(table, item)
  local isPresent = false;
  local pos = 0;
  for key, value in pairs(table) do
    if (value == item) then
      isPresent = true;
      pos = key;
      break;
    end
  end
  return isPresent, pos;
end

function config:HasKey(table, key)
  for k, v in pairs(table) do
    if (k == key) then
      return true;
    end
  end
  return false;
end

function config:HasAtLeastOneItem(tabSource, tabDest)
  for i = 1, #tabSource do
    if (config:HasItem(tabDest, tabSource[i])) then
      return true;
    end
  end
  return false;
end

function config:GetTimeUntilReset()
  local dateValue = date("*t");

  local function gethours()
    local n = 0;
    local value = dateValue.hour;
    while (value ~= ToDoListSV.dailyHour) do
      if (value == 24) then
        value = 0;
      end
      n = n + 1;
      value = value + 1;
    end

    if (n == 0) then
      n = 24;
    end
    return n - 1; -- because min and sec are displayed
  end

  local function getdays()
    local n = 0;
    local value = dateValue.wday;
    if (dateValue.hour >= ToDoListSV.dailyHour) then
      value = value + 1;
    end
    while (value ~= ToDoListSV.weeklyDay) do
      if (value == 8) then
        value = 1;
      end
      n = n + 1;
      value = value + 1;
    end
    return n;
  end

  local timeUntil = {
    days = getdays(),
    hour = gethours(),
    min = math.abs(dateValue.min - 59),
    sec = math.abs(dateValue.sec - 59),
  }

  return timeUntil;
end

function config:GetSecondsToReset()
  local secondsUntil = {
    weekly = config:GetTimeUntilReset().days * 24 * 60 * 60
     + config:GetTimeUntilReset().hour * 60 * 60
     + config:GetTimeUntilReset().min * 60
     + config:GetTimeUntilReset().sec
     + time(),

    daily = config:GetTimeUntilReset().hour * 60 * 60
     + config:GetTimeUntilReset().min * 60
     + config:GetTimeUntilReset().sec
     + time(),
  }

  return secondsUntil;
end

-- Widget creation functions:--
function config:CreateButton(name, relativeFrame, xSize, ySize, text)
  local btn = CreateFrame("Button", name, relativeFrame, "UIMenuButtonStretchTemplate");
  btn:SetSize(xSize, ySize);
  btn:SetText(text);
  btn:SetNormalFontObject("GameFontNormalLarge");
  btn:SetHighlightFontObject("GameFontHighlightLarge");
  return btn;
end

function config:CreateTransparentButton(name, relativeFrame, xSize, ySize, text)
  local btn = CreateFrame("Button", name, relativeFrame, "UIMenuButtonStretchTemplate");
  btn:SetSize(xSize, ySize);
  btn:SetText(text);
  btn:SetHighlightTexture("");
  btn:SetNormalFontObject("GameFontNormalLarge");
  btn:SetHighlightFontObject("GameFontHighlightLarge");
  return btn;
end

function config:CreateRemoveButton(relativeCheckButton)
  local btn = CreateFrame("Button", nil, relativeCheckButton, "RemoveButton");
  btn:SetPoint("LEFT", relativeCheckButton, "LEFT", - 20, 0);

  -- these are for changing the color depending on the mouse actions (since they are custom xml)
  btn:HookScript("OnEnter", function(self) self.Icon:SetVertexColor(0.5, 0.5, 0.5) end);
  btn:HookScript("OnLeave", function(self) self.Icon:SetVertexColor(1, 1, 0.2) end);
  btn:HookScript("OnShow", function(self) self.Icon:SetVertexColor(1, 1, 0.2) end);
  return btn;
end

function config:CreateAddButton(relativeEditBox)
  local btn = CreateFrame("Button", nil, relativeEditBox, "AddButton");
  btn:SetPoint("RIGHT", relativeEditBox, "RIGHT", 16, - 1.2);

  -- these are for changing the color depending on the mouse actions (since they are custom xml)
  btn:HookScript("OnEnter", function(self) self.Icon:SetVertexColor(0.5, 0.5, 0.1) end);
  btn:HookScript("OnLeave", function(self) self.Icon:SetVertexColor(1, 0.9, 0.2) end);
  btn:HookScript("OnShow", function(self) self.Icon:SetVertexColor(1, 0.9, 0.2) end);
  return btn;
end

function config:CreateNoPointsLabelEditBox(name)
  local edb = CreateFrame("EditBox", name, nil, "InputBoxTemplate");
  edb:SetSize(120, 30);
  edb:SetAutoFocus(false);
  return edb;
end

function config:CreateLabel(point, relativeFrame, relativePoint, xOffset, yOffset, text)
  local label = relativeFrame:CreateFontString(nil);
  label:SetPoint(point, relativeFrame, relativePoint, xOffset, yOffset);
  label:SetFontObject("GameFontHighlightLarge");
  label:SetText(text);
  return label;
end

function config:CreateNoPointsLabel(relativeFrame, name, text)
  local label = relativeFrame:CreateFontString(name);
  label:SetFontObject("GameFontHighlightLarge");
  label:SetText(text);
  return label;
end

function config:CreateNothingLabel(relativeFrame)
  local label = relativeFrame:CreateFontString(nil);
  label:SetFontObject("GameFontHighlightLarge");
  label:SetText("There are no items!");
  label:SetTextColor(0.5, 0.5, 0.5, 0.5);
  return label;
end

function config:CreateDummy(relativeFrame, xOffset, yOffset)
  local dummy = CreateFrame("Frame", nil, ItemsFrameUI, nil);
  dummy:SetPoint("TOPLEFT", relativeFrame, "TOPLEFT", xOffset, yOffset);
  dummy:SetSize(1, 1);
  dummy:Show();
  return dummy;
end
