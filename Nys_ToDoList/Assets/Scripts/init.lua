-- Namespaces
local addonName, tdlTable = ...;
tdlTable.init = {}; -- adds init table to addon namespace

local config = tdlTable.config;
local itemsFrame = tdlTable.itemsFrame;
local init = tdlTable.init;

-- Variables

local L = config.L;
local addonLoaded = false;
local warnTimerTime = 3600; -- in seconds (1 hour)

--/*******************/ EVENTS /*************************/--
-- we need to put them here so they have acces to every function in every file of the addon

function NysTDL:PLAYER_LOGIN()
  local disabled = config.database.options.args.main.args.general.args.groupWarnings.args.hourlyReminder.disabled
  if (NysTDL.db.global.UI_reloading) then -- just to be sure that it wasn't a reload, but a genuine player log in
    NysTDL.db.global.UI_reloading = false

    if (NysTDL.db.global.warnTimerRemaining > 0) then -- this is for the special case where we logged in, but reloaded before the 20 sec timer activated, so we just try it again
      NysTDL.warnTimer = self:ScheduleTimer(function() -- after reloading, we restart the warn timer from where we left off before the reload
        if (NysTDL.db.profile.hourlyReminder and not disabled()) then -- without forgetting that it's the hourly reminder timer this time
          NysTDL:Warn()
        end
        NysTDL.warnTimer = self:ScheduleRepeatingTimer(function()
          if (NysTDL.db.profile.hourlyReminder and not disabled()) then
            NysTDL:Warn()
          end
        end, warnTimerTime)
      end, NysTDL.db.global.warnTimerRemaining)
      return;
    end
  end

  NysTDL.db.global.warnTimerRemaining = 0
  self:ScheduleTimer(function() -- 20 secs after the player logs in, we check if we need to warn him about the remaining items
    if (addonLoaded) then -- just to be sure
      NysTDL:Warn()
      NysTDL.warnTimer = self:ScheduleRepeatingTimer(function()
        if (NysTDL.db.profile.hourlyReminder and not disabled()) then
          NysTDL:Warn()
        end
      end, warnTimerTime)
    end
  end, 20)
end

--/*******************/ CHAT COMMANDS /*************************/--
-- we need to put them here so they have acces to every function in every file of the addon

-- Commands:
init.commands = {
  [""] = function()
    itemsFrame:Toggle()
  end,

  [L["info"]] = function()
    local hex = config:RGBToHex(config.database.theme2)
    local str = L["Here are a few commands to help you:"].."\n"
    str = str.." -- "..string.format("|cff%s%s|r", hex, "/tdl "..L["toggle"])
    str = str.." -- "..string.format("|cff%s%s|r", hex, "/tdl "..L["categories"])
    str = str.." -- "..string.format("|cff%s%s|r", hex, "/tdl "..L["favorites"])
    str = str.." -- "..string.format("|cff%s%s|r", hex, "/tdl "..L["descriptions"])
    str = str.." -- "..string.format("|cff%s%s|r", hex, "/tdl "..L["hyperlinks"])
    str = str.." -- "..string.format("|cff%s%s|r", hex, "/tdl "..L["rename"])
    str = str.." -- "..string.format("|cff%s%s|r", hex, "/tdl "..L["tutorial"])
    config:PrintForced(str)
  end,

  [L["toggle"]] = function()
    config:PrintForced(L["To toggle the list, you have several ways:"]..'\n- '..L["minimap button (the default)"]..'\n- '..L["a normal TDL button"]..'\n- '..L["databroker plugin (eg. titan panel)"]..'\n- '..L["the '/tdl' command"]..'\n- '..L["key binding"]..'\n'..L["You can go to the addon options in the game's interface settings to customize this."])
  end,

  [L["categories"]] = function()
    config:PrintForced(L["Information on categories:"].."\n- "..L["The same category can be present in multiple tabs, as long as there are items for each of those tabs."].."\n- "..L["A category cannot be empty, if it is, it will just get deleted from the tab."].."\n- "..L["Left-click on the category names to expand or shrink their content."].."\n- "..L["Right-click on the category names to add new items."])
  end,

  [L["favorites"]] = function()
    config:PrintForced(L["You can favorite items!"].."\n"..L["To do so, hold the SHIFT key when the list is opened, then click on the star icons to favorite the items that you want!"])
    config:PrintForced(L["Perks of favorite items:"].."\n- "..L["cannot be deleted"].."\n- "..L["customizable color"].."\n- "..L["sorted first in categories"].."\n- "..L["have their own more visible remaining numbers"].."\n- "..L["have an auto chat warning/reminder system!"])
  end,

  [L["descriptions"]] = function()
    config:PrintForced(L["You can add descriptions on items!"].."\n"..L["To do so, hold the CTRL key when the list is opened, then click on the page icons to open a description frame!"].."\n- "..L["they are auto-saved and have no length limitations"].."\n- "..L["if an item has a description, he cannot be deleted (empty the description if you want to do so)"])
  end,

  [L["hyperlinks"]] = function()
    config:PrintForced(L["You can add hyperlinks in the list!"]..' '..L["It works the same way as when you link items or other things in the chat, just shift-click!"])
  end,

  [L["rename"]] = function()
    config:PrintForced(L["For items: just double click on them."].."\n"..L["For categories, and items with hyperlinks in them: hold ALT then double click on them."])
  end,

  [L["tutorial"]] = function()
    itemsFrame:RedoTutorial()
    config:PrintForced(L["The tutorial has been reset!"])
  end,
}

-- Command catcher:
local function HandleSlashCommands(str)
  local path = init.commands; -- easier to read

  if (#str == 0) then
    -- we just entered "/tdl" with no additional args.
    path[""]();
    return;
  end

  local args = {string.split(' ', str)};

  local deep = 1;
  for id, arg in pairs(args) do
    if (path[arg]) then
      if (type(path[arg]) == "function") then
        -- all remaining args passed to our function!
        path[arg](select(id + 1, unpack(args)))
        return;
      elseif (type(path[arg]) == "table") then
        deep = deep + 1;
        path = path[arg]; -- another sub-table found!

        if ((select(deep, unpack(args))) == nil) then
          -- here we just entered into a sub table, with no additional args
          path[""]();
          return;
        end
      end
    else
      -- does not exist!
      init.commands[L["info"]]();
      return;
    end
  end
end

--/*******************/ INITIALIZATION /*************************/--

function NysTDL:OnInitialize()
    -- Called when the addon is loaded

    -- Register new Slash Command
    SLASH_NysToDoList1 = "/tdl";
    SlashCmdList.NysToDoList = HandleSlashCommands;

    -- Saved variable database
    self.db = LibStub("AceDB-3.0"):New("NysToDoListDB", config.database.defaults)
    self:DBInit(); -- initialization for some elements of the db that need specific functions

    -- callbacks for database changes
    self.db.RegisterCallback(self, "OnProfileChanged", "ProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "ProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "ProfileChanged")
    self.db.RegisterCallback(self, "OnDatabaseReset", "ProfileChanged")

    -- events registration
    self:RegisterEvent("PLAYER_LOGIN")
    hooksecurefunc("ReloadUI", function()
      NysTDL.db.global.UI_reloading = true
      NysTDL.db.global.warnTimerRemaining = self:TimeLeft(NysTDL.warnTimer) -- if we are reloading, we keep in mind how much time there was left to our repeating warn timer
    end) -- this is for knowing when the addon is loading, if it was a UI reload or the player logging in
    hooksecurefunc("ChatEdit_InsertLink", function(...) return NysTDL:EditBoxInsertLink(...) end) -- this is for adding hyperlinks in my addon edit boxes

    -- / Blizzard interface options / --

    -- this is for adapting the width of the widgets to the length of their respective names (that can change with the locale)
    local wDef = { toggle = 160, select = 265, range = 200, keybinding = 200, color = 180 }
    NysTDL:InitializeOptionsWidthRecursive(config.database.options.args.main.args.general.args, wDef)

    -- we register our options table for AceConfig
    LibStub("AceConfigRegistry-3.0"):ValidateOptionsTable(config.database.options, addonName)
    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, config.database.options)

    -- then we add the profiles management, using AceDBOptions
    config.database.options.args.child_profiles.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    -- we also modify it a bit to better fit our needs (by adding some confirm pop-ups)
    local args = config:Deepcopy(config.database.options.args.child_profiles.args.profiles.args)
    args.reset.confirm = true
    args.reset.confirmText = L["WARNING"]..'\n\n'..L["Resetting this profile will also clear the list."]..'\n'..L["Are you sure?"]..'\n'
    args.copyfrom.confirm = true
    args.copyfrom.confirmText = L["This action will override your settings, including the list."]..'\n'..L["Are you sure?"]..'\n'
    config.database.options.args.child_profiles.args.profiles.args = args

    -- we add our frame to wow's interface options panel
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, config.toc.title, nil, "main")
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, L["Profiles"], config.toc.title, "child_profiles")

    -- / ********************** / --

    -- we create the 2 buttons
    NysTDL:CreateTDLButton();
    NysTDL:CreateMinimapButton();

    -- we create the frame
    itemsFrame:CreateItemsFrame();

    -- addon fully loaded!

    -- checking for an addon update
    if (self.db.global.addonUpdated) then
      self:AddonUpdated()
      self.db.global.addonUpdated = false
    end

    local hex = config:RGBToHex(config.database.theme2);
    config:Print(L["addon loaded!"]..' ('..string.format("|cff%s%s|r", hex, "/tdl "..L["info"])..')');
    addonLoaded = true;
end

function NysTDL:AddonUpdated()
  -- called once, when the addon gets an update
end
