-- Namespaces
local addonName, tdlTable = ...;
tdlTable.config = {}; -- adds config table to addon namespace

local config = tdlTable.config;

--/*******************/ ADDON LIBS AND DATA HANDLER /*************************/--
-- libs
NysTDL = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceTimer-3.0", "AceEvent-3.0")
config.AceGUI = LibStub("AceGUI-3.0")
config.L = LibStub("AceLocale-3.0"):GetLocale(addonName)
config.LDB = LibStub("LibDataBroker-1.1")
config.LDBIcon = LibStub("LibDBIcon-1.0")
-- data (from toc file)
config.toc = {}
config.toc.title = GetAddOnMetadata(addonName, "Title") -- better than "Nys_ToDoList"
config.toc.wowVersion = GetAddOnMetadata(addonName, "X-WoW-Version")

-- Variables
local AceGUI = config.AceGUI
local L = config.L

-- Bindings.xml globals
BINDING_HEADER_NysTDL = config.toc.title
BINDING_NAME_NysTDL = L["Show/Hide the To-Do List"]

--/*******************/ DATABASE /*************************/--

config.database = {
    -- addon themes (rgb)
    theme = { 0, 204, 255 }, -- theme
    theme2 = { 0, 204, 102 }, -- theme2
    theme_yellow = { 255, 216, 0 }, -- theme_yellow

    version = GetAddOnMetadata(addonName, "Version"),

    -- AceConfig options table
    options = {
        handler = NysTDL,
        type = "group",
        name = config.toc.title..' - '..L["Options"],
        childGroups = "tab",
        args = {
          general = {
      			order = 0,
            type = "group",
            name = L["General"],
      			desc = L["Manage general options"],
            args = {

              -- / options widgets / --

              weeklyDay = {
                  order = 4.1,
                  type = "select",
                  style = "dropdown",
                  name = L["Weekly reset day"],
                  desc = L["Choose the day for the weekly reset"],
                  values = {
                    [2] = L["Monday"],
                    [3] = L["Tuesday"],
                    [4] = L["Wednesday"],
                    [5] = L["Thursday"],
                    [6] = L["Friday"],
                    [7] = L["Saturday"],
                    [1] = L["Sunday"],
                  },
                  sorting = {
                    2, 3, 4, 5, 6, 7, 1,
                  },
                  get = "weeklyDayGET",
                  set = "weeklyDaySET",
              }, -- weeklyDay
              dailyHour = {
                  order = 4.2,
                  type = "range",
                  name = L["Daily reset hour"],
                  desc = L["Choose the hour for the daily reset"],
                  min = 0,
                  max = 23,
                  step = 1,
                  get = "dailyHourGET",
                  set = "dailyHourSET",
              }, -- dailyHour
              showChatMessages = {
                  order = 3.1,
                  type = "toggle",
                  name = L["Show chat messages"],
                  desc = L["Enable or disable the chat messages"],
                  get = "showChatMessagesGET",
                  set = "showChatMessagesSET",
              }, -- showChatMessages
              showFavoritesWarning = {
                  order = 3.2,
                  type = "toggle",
                  name = L["Show favorites warning"],
                  desc = L["Enable or disable the chat warning/reminder for favorite items"],
                  get = "showFavoritesWarningGET",
                  set = "showFavoritesWarningSET",
              }, -- showFavoritesWarning
              rememberUndo = {
                  order = 3.3,
                  type = "toggle",
                  name = L["Remember undos"],
                  desc = L["Save undos between sessions"],
                  get = "rememberUndoGET",
                  set = "rememberUndoSET",
              }, -- rememberUndo
              favoritesColor = {
                  order = 3.4,
                  type = "color",
                  name = L["Favorites color"],
                  desc = L["Change the color for the favorite items"],
                  get = "favoritesColorGET",
                  set = "favoritesColorSET",
              }, -- favoritesColor
              tdlButtonShow = {
                  order = 2.3,
                  type = "toggle",
                  name = L["Show TDL button"],
                  desc = L["Toggles the display of the 'To-Do List' button"],
                  get = "tdlButtonShowGET",
                  set = "tdlButtonShowSET",
              }, -- tdlButtonShow
              minimapButtonHide = {
                  order = 2.1,
                  type = "toggle",
                  name = L["Show minimap button"],
                  desc = L["Toggles the display of the minimap button"],
                  get = function(info) return not NysTDL:minimapButtonHideGET(info) end,
                  set = function(info, newValue) NysTDL:minimapButtonHideSET(info, not newValue) end,
              }, -- minimapButtonHide
              minimapButtonTooltip = {
                  order = 2.2,
                  -- disabled = function() return NysTDL.db.profile.minimap.hide; end,
                  type = "toggle",
                  name = L["Show tooltip"],
                  desc = L["Show the tooltip of the minimap/databroker button"],
                  get = "minimapButtonTooltipGET",
                  set = "minimapButtonTooltipSET",
              }, -- minimapButtonTooltip
              keyBind = {
                  type = "keybinding",
                  name = L["Show/Hide the list"],
                  desc = L["Bind a key to toggle the list"]..'\n'..L["(independant from profile)"],
                  order = 1.1,
                  get = "keyBindGET",
                  set = "keyBindSET",
              }, -- keyBind

              -- / layout widgets / --

              -- spacers
              spacer111 = {
          			order = 1.11,
          			type = "description",
          			width = "full",
          			name = "",
          		}, -- spacer111
              spacer199 = {
          			order = 1.99,
          			type = "description",
          			width = "full",
          			name = "\n",
          		}, -- spacer199
              spacer211 = {
          			order = 2.11,
          			type = "description",
          			width = "full",
          			name = "",
          		}, -- spacer211
              spacer221 = {
          			order = 2.21,
          			type = "description",
          			width = "full",
          			name = "",
          		}, -- spacer221
              spacer231 = {
          			order = 2.31,
          			type = "description",
          			width = "full",
          			name = "",
          		}, -- spacer231
              spacer299 = {
          			order = 2.99,
          			type = "description",
          			width = "full",
          			name = "\n",
          		}, -- spacer299
              spacer311 = {
          			order = 3.11,
          			type = "description",
          			width = "half",
          			name = "",
          		}, -- spacer311
              spacer321 = {
          			order = 3.21,
          			type = "description",
          			width = "full",
          			name = "",
          		}, -- spacer321
              spacer331 = {
          			order = 3.31,
          			type = "description",
          			width = "half",
          			name = "",
          		}, -- spacer331
              spacer341 = {
          			order = 3.41,
          			type = "description",
          			width = "full",
          			name = "",
          		}, -- spacer331
              spacer399 = {
          			order = 3.99,
          			type = "description",
          			width = "full",
          			name = "\n",
          		}, -- spacer399
              spacer411 = {
          			order = 4.11,
          			type = "description",
          			width = "full",
          			name = "",
          		}, -- spacer411

              -- headers
              header1 = {
          			order = 1,
          			type = "header",
                name = L["Key Binding"],
          		}, -- header1
              header2 = {
          			order = 2,
          			type = "header",
                name = L["Buttons"],
          		}, -- header2
              header3 = {
          			order = 3,
          			type = "header",
                name = L["Settings"],
          		}, -- header3
              header4 = {
          			order = 4,
          			type = "header",
                name = L["Auto Uncheck"],
          		}, -- header4
            }, -- args
          }, -- general
        }, -- args
    }, -- options

    -- AceDB defaults table
    defaults = {
        profile = {
            minimap = { hide = false, minimapPos = 241, lock = false, tooltip = true }, -- for LibDBIcon
            tdlButton = { show = false, points = { point = "CENTER", relativeTo = UIParent, relativePoint = "CENTER", xOffset = 0, yOffset = 0 } },
            framePos = { point = "CENTER", relativeTo = UIParent, relativePoint = "CENTER", xOffset = 0, yOffset = 0 },
            itemsList = nil,
            itemsDaily = nil,
            itemsWeekly = nil,
            itemsFavorite = {},
            itemsDesc = {},
            favoritesColor = { 1, 0.5, 0.6 },
            weeklyDay = 4,
            dailyHour = 9,
            autoReset = nil,
            showChatMessages = true,
            showFavoritesWarning = true,
            rememberUndo = true,
            frameAlpha = 75,
            frameContentAlpha = 100,
            affectDesc = true,
            descFrameAlpha = 75,
            descFrameContentAlpha = 100,
            lastLoadedTab = "ToDoListUIFrameTab1",
            checkedButtons = {},
            closedCategories = {},
            undoTable = {},
            UI_reloading = false,
        }, -- profile
    }, -- defaults
}

--------------------------------------
-- General config functions
--------------------------------------

function config:Print(...)
  if (not NysTDL.db.profile.showChatMessages) then return; end -- we don't print anything if the user chose to deactivate this
  config:PrintForced(...);
end

function config:PrintForced(...)
  if (... == nil) then return; end

  local hex = self:RGBToHex(self.database.theme);
  local prefix = string.format("|cff%s%s|r", hex, config.toc.title..':');

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

function config:RGBToHex(rgb)
	local hexadecimal = ""

	for key, value in pairs(rgb) do
		local hex = ''

		while(value > 0)do
			local index = math.fmod(value, 16) + 1
			value = math.floor(value / 16)
			hex = string.sub('0123456789ABCDEF', index, index) .. hex
		end

		if(string.len(hex) == 0)then
			hex = '00'

		elseif(string.len(hex) == 1)then
			hex = '0' .. hex
		end

		hexadecimal = hexadecimal..hex
	end

	return hexadecimal
end

function config:ThemeDownTo01(theme)
  local r, g, b = unpack(theme)
  return { r/255, g/255, b/255 }
end

function config:DimTheme(theme, dim)
  local r, g, b = unpack(theme)
  return { r*dim, g*dim, b*dim }
end

function config:Deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[config:Deepcopy(orig_key)] = config:Deepcopy(orig_value)
        end
        setmetatable(copy, config:Deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
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

    while (value ~= NysTDL.db.profile.dailyHour) do
      n = n + 1;
      value = value + 1;
      if (value == 24) then
        value = 0;
      end
    end

    if (n == 0) then
      n = 24;
    end

    return n - 1; -- because it's a countdown (it's like min and sec are also displayed)
  end

  local function getdays()
    local n = 0;
    local value = dateValue.wday;

    if (dateValue.hour >= NysTDL.db.profile.dailyHour) then
      value = value + 1;
      if (value == 8) then
        value = 1;
      end
    end

    while (value ~= NysTDL.db.profile.weeklyDay) do
      n = n + 1;
      value = value + 1;
      if (value == 8) then
        value = 1;
      end
    end

    return n; -- same, but a bit more complicated since it depends on the daily reset hour
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
function config:CreateNoPointsLabel(relativeFrame, name, text)
  local label = relativeFrame:CreateFontString(name);
  label:SetFontObject("GameFontHighlightLarge");
  label:SetText(text);
  return label;
end

function config:CreateNothingLabel(relativeFrame)
  local label = relativeFrame:CreateFontString(nil);
  label:SetFontObject("GameFontHighlightLarge");
  label:SetText(L["There are no items!"]);
  label:SetTextColor(0.5, 0.5, 0.5, 0.5);
  return label;
end

function config:CreateButton(name, relativeFrame, text, iconPath, fc)
  fc = fc or false
  iconPath = (type(iconPath) == "string") and iconPath or nil
  local btn = CreateFrame("Button", name, relativeFrame, "NysTDL_NormalButton");
  local w = config:CreateNoPointsLabel(relativeFrame, nil, text):GetWidth();
  btn:SetText(text);
  btn:SetNormalFontObject("GameFontNormalLarge");
  if (fc == true) then btn:SetHighlightFontObject("GameFontHighlightLarge"); end
  if (iconPath ~= nil) then
    w = w + 23;
    btn.Icon = btn:CreateTexture(nil, "ARTWORK")
    btn.Icon:SetPoint("LEFT", btn, "LEFT", 10, 0)
    btn.Icon:SetTexture(iconPath)
    btn.Icon:SetSize(17, 17)
    btn:GetFontString():SetPoint("LEFT", btn, "LEFT", 33, 0)
    btn:HookScript("OnMouseDown", function(self) btn.Icon:SetPoint("LEFT", btn, "LEFT", 12, -2) end)
    btn:HookScript("OnMouseUp", function(self) btn.Icon:SetPoint("LEFT", btn, "LEFT", 10, 0) end)
  end
  btn:SetWidth(w + 20);
  return btn;
end

function config:CreateHelpButton(relativeFrame)
  local btn = CreateFrame("Button", nil, relativeFrame, "NysTDL_HelpButton");
  btn.tooltip = L["Information"];

  -- these are for changing the color depending on the mouse actions (since they are custom xml)
  btn:HookScript("OnEnter", function(self)
    self:SetAlpha(1)
  end);
  btn:HookScript("OnLeave", function(self)
    self:SetAlpha(0.7)
  end);
  btn:HookScript("OnShow", function(self)
    self:SetAlpha(0.7)
  end);
  return btn;
end

function config:CreateRemoveButton(relativeCheckButton)
  local btn = CreateFrame("Button", nil, relativeCheckButton, "NysTDL_RemoveButton");
  btn:SetPoint("LEFT", relativeCheckButton, "LEFT", - 20, 0);

  -- these are for changing the color depending on the mouse actions (since they are custom xml)
  btn:HookScript("OnEnter", function(self)
    self.Icon:SetVertexColor(0.8, 0.2, 0.2)
  end);
  btn:HookScript("OnLeave", function(self)
    if (tonumber(string.format("%.1f", self.Icon:GetAlpha())) ~= 0.5) then
      self.Icon:SetVertexColor(1, 1, 1)
    end
  end);
  btn:HookScript("OnMouseUp", function(self)
    if (self.name == "RemoveButton") then
      self.Icon:SetVertexColor(1, 1, 1)
    end
  end);
  btn:HookScript("OnShow", function(self)
    self.Icon:SetVertexColor(1, 1, 1)
  end);
  return btn;
end

function config:CreateFavoriteButton(relativeCheckButton)
  local btn = CreateFrame("Button", nil, relativeCheckButton, "NysTDL_FavoriteButton");
  btn:SetPoint("LEFT", relativeCheckButton, "LEFT", - 20, -2);

  -- these are for changing the color depending on the mouse actions (since they are custom xml)
  -- and yea, this one's a bit complicated because I wanted its look to be really precise...
  btn:HookScript("OnEnter", function(self)
    if (not config:HasItem(NysTDL.db.profile.itemsFavorite, self:GetParent():GetName())) then
      self.Icon:SetDesaturated(nil)
      self.Icon:SetVertexColor(1, 1, 1)
    else
      self:SetAlpha(0.6)
    end
  end);
  btn:HookScript("OnLeave", function(self)
    if (not config:HasItem(NysTDL.db.profile.itemsFavorite, self:GetParent():GetName())) then
      if (tonumber(string.format("%.1f", self.Icon:GetAlpha())) ~= 0.5) then -- if we are currently clicking on the button
        self.Icon:SetDesaturated(1)
        self.Icon:SetVertexColor(0.4, 0.4, 0.4)
      end
    else
      self:SetAlpha(1)
    end
   end);
   btn:HookScript("OnMouseUp", function(self)
     if (self.name == "FavoriteButton") then
       self:SetAlpha(1)
       if (not config:HasItem(NysTDL.db.profile.itemsFavorite, self:GetParent():GetName())) then
         self.Icon:SetDesaturated(1)
         self.Icon:SetVertexColor(0.4, 0.4, 0.4)
       end
     end
   end);
   btn:HookScript("PostClick", function(self)
     if (self.name == "FavoriteButton") then
       self:GetScript("OnShow")(self)
     end
   end);
  btn:HookScript("OnShow", function(self)
    self:SetAlpha(1)
    if (not config:HasItem(NysTDL.db.profile.itemsFavorite, self:GetParent():GetName())) then
      self.Icon:SetDesaturated(1)
      self.Icon:SetVertexColor(0.4, 0.4, 0.4)
    else
      self.Icon:SetDesaturated(nil)
      self.Icon:SetVertexColor(1, 1, 1)
    end
  end);
  return btn;
end

function config:CreateDescButton(relativeCheckButton)
  local btn = CreateFrame("Button", nil, relativeCheckButton, "NysTDL_DescButton");
  btn:SetPoint("LEFT", relativeCheckButton, "LEFT", - 20, 0);

  -- these are for changing the color depending on the mouse actions (since they are custom xml)
  -- and yea, this one's a bit complicated too because it works in very specific ways
  btn:HookScript("OnEnter", function(self)
    if (not config:HasKey(NysTDL.db.profile.itemsDesc, self:GetParent():GetName())) then
      self.Icon:SetDesaturated(nil)
      self.Icon:SetVertexColor(1, 1, 1)
    else
      self:SetAlpha(0.6)
    end
  end);
  btn:HookScript("OnLeave", function(self)
    if (not config:HasKey(NysTDL.db.profile.itemsDesc, self:GetParent():GetName())) then
      if (tonumber(string.format("%.1f", self.Icon:GetAlpha())) ~= 0.5) then -- if we are currently clicking on the button
        self.Icon:SetDesaturated(1)
        self.Icon:SetVertexColor(0.4, 0.4, 0.4)
      end
    else
      self:SetAlpha(1)
    end
   end);
   btn:HookScript("OnMouseUp", function(self)
     if (self.name == "DescButton") then
       self:SetAlpha(1)
       if (not config:HasKey(NysTDL.db.profile.itemsDesc, self:GetParent():GetName())) then
         self.Icon:SetDesaturated(1)
         self.Icon:SetVertexColor(0.4, 0.4, 0.4)
       end
     end
   end);
   btn:HookScript("PostClick", function(self)
     if (self.name == "DescButton") then
       self:GetScript("OnShow")(self)
     end
   end);
  btn:HookScript("OnShow", function(self)
    self:SetAlpha(1)
    if (not config:HasKey(NysTDL.db.profile.itemsDesc, self:GetParent():GetName())) then
      self.Icon:SetDesaturated(1)
      self.Icon:SetVertexColor(0.4, 0.4, 0.4)
    else
      self.Icon:SetDesaturated(nil)
      self.Icon:SetVertexColor(1, 1, 1)
    end
  end);
  return btn;
end

function config:CreateAddButton(relativeEditBox)
  local btn = CreateFrame("Button", nil, relativeEditBox, "NysTDL_AddButton");
  btn.tooltip = L["Press enter or click to add the item"];
  btn:SetPoint("RIGHT", relativeEditBox, "RIGHT", 16, - 1.2);

  -- these are for changing the color depending on the mouse actions (since they are custom xml)
  btn:HookScript("OnEnter", function(self)
    self.Icon:SetTextColor(unpack(config:ThemeDownTo01(config.database.theme_yellow)), tonumber(string.format("%.1f", self.Icon:GetAlpha())));
  end);
  btn:HookScript("OnLeave", function(self)
    self.Icon:SetTextColor(1, 1, 1, tonumber(string.format("%.1f", self.Icon:GetAlpha())));
  end);
  btn:HookScript("OnShow", function(self)
    self.Icon:SetTextColor(1, 1, 1);
  end);
  return btn;
end

function config:CreateNoPointsLabelEditBox(name)
  local edb = CreateFrame("EditBox", name, nil, "InputBoxTemplate");
  edb:SetSize(120, 30);
  edb:SetAutoFocus(false);
  return edb;
end

function config:CreateDummy(relativeFrame, xOffset, yOffset)
  local dummy = CreateFrame("Frame", nil, ItemsFrameUI, nil);
  dummy:SetPoint("TOPLEFT", relativeFrame, "TOPLEFT", xOffset, yOffset);
  dummy:SetSize(1, 1);
  dummy:Show();
  return dummy;
end

function config:CreateNoPointsLine(relativeFrame, thickness, r, g, b, a)
  a = a or 1
  local line = relativeFrame:CreateLine()
  line:SetThickness(thickness)
  if (r and g and b and a) then line:SetColorTexture(r, g, b, a) end
  return line;
end
