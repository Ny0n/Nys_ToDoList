-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local chat = addonTable.chat
local utils = addonTable.utils
local database = addonTable.database
local mainFrame = addonTable.mainFrame
local dataManager = addonTable.dataManager
local resetManager = addonTable.resetManager
local tutorialsManager = addonTable.tutorialsManager

-- Variables
local L = core.L

--/*******************/ CHAT RELATED FUNCTIONS /*************************/--

function chat:Print(...)
  if not NysTDL.db.profile.showChatMessages then return end -- we don't print anything if the user chose to deactivate this
  self:PrintForced(...)
end

local T_PrintForced = {}
function chat:PrintForced(...)
  if ... == nil then return end

  local hex = utils:RGBToHex(database.themes.theme)
  local prefix = string.format("|cff%s%s|r", hex, core.toc.title..':')

  wipe(T_PrintForced)
  local message = T_PrintForced
  for i = 1, select("#", ...) do
    local s = (select(i, ...))
    if type(s) == "table" then
      for j = 1, #s do
        table.insert(message, (select(j, unpack(s))))
      end
    else
      table.insert(message, s)
    end
  end

  DEFAULT_CHAT_FRAME:AddMessage(string.join(' ', prefix, unpack(message)))
end

-- Warning function
function chat:Warn()
  if NysTDL.db.profile.showWarnings then -- if the option is checked
    if not resetManager:autoResetedThisSessionGET() then -- we don't want to show this warning if it's the first log in of the day, only if it is the next ones
      local haveWarned = false
      local warn = "--------------| |cffff0000"..L["WARNING"].."|r |--------------"

      if NysTDL.db.profile.favoritesWarning then -- and the user allowed this functionnality
        local uncheckedFav = dataManager:GetRemainingNumbers().uncheckedFav
        if uncheckedFav > 0 then
          local msg = ""

          local maxTime = time() + 86400
          dataManager:DoIfFoundTabMatch(maxTime, "uncheckedFav", function(tabID, tabData)
            local nb = dataManager:GetRemainingNumbers(nil, tabID).uncheckedFav
            if msg ~= "" then
              msg = msg.." + "
            end
            local tabName = L[tabData.name] or tabData.name
            msg = msg..tostring(nb).." ("..tabName..")"
          end, true)

          if msg ~= "" then
            local hex = utils:RGBToHex({ NysTDL.db.profile.favoritesColor[1]*255, NysTDL.db.profile.favoritesColor[2]*255, NysTDL.db.profile.favoritesColor[3]*255} )
            msg = string.format("|cff%s%s|r", hex, msg)
            if not haveWarned then self:PrintForced(warn) haveWarned = true end
            self:PrintForced(utils:SafeStringFormat(L["You still have %s favorite item(s) to do before the next reset, don't forget them!"], msg))
          end
        end
      end

      if NysTDL.db.profile.normalWarning then
        local totalUnchecked = dataManager:GetRemainingNumbers().totalUnchecked
        if totalUnchecked > 0 then
          local total = 0

          local maxTime = time() + 86400
          dataManager:DoIfFoundTabMatch(maxTime, "totalUnchecked", function(tabID, tabData)
            local nb = dataManager:GetRemainingNumbers(nil, tabID).totalUnchecked
            total = total + nb
          end, true)

          if total ~= 0 then
            if not haveWarned then self:PrintForced(warn) haveWarned = true end
            self:PrintForced(L["Total number of items left to do before tomorrow:"]..' '..tostring(total))
          end
        end
      end

      -- TDLATER maybe also do this if i ever want to redo this system
      -- if haveWarned then
      --   local timeUntil = autoReset:GetTimeUntilReset()
      --   local msg = utils:SafeStringFormat(L["Time remaining: %i hours %i min"], timeUntil.hour, timeUntil.min + 1)
      --   self:PrintForced(msg)
      -- end
    end
  end
end

--/*******************/ CHAT COMMANDS /*************************/--

-- Commands:
chat.commands = { -- TDLATER FIX if all chat commands locales are the same, we cant access them
  [""] = function()
    mainFrame:Toggle()
  end,

  [L["info"]] = function()
    local hex = utils:RGBToHex(database.themes.theme2)
    local str = L["Here are a few commands to help you:"].."\n"
    str = str.." -- "..string.format("|cff%s%s|r", hex, "/tdl "..L["toggle"])
    str = str.." -- "..string.format("|cff%s%s|r", hex, "/tdl "..L["categories"])
    str = str.." -- "..string.format("|cff%s%s|r", hex, "/tdl "..L["hyperlinks"])
    str = str.." -- "..string.format("|cff%s%s|r", hex, "/tdl "..L["editmode"])
    str = str.." -- "..string.format("|cff%s%s|r", hex, "/tdl "..L["favorites"])
    str = str.." -- "..string.format("|cff%s%s|r", hex, "/tdl "..L["descriptions"])
    str = str.." -- "..string.format("|cff%s%s|r", hex, "/tdl "..L["tutorial"])
    chat:PrintForced(str)
  end,

  [L["toggle"]] = function()
    chat:PrintForced(L["To toggle the list, you have several ways:"]
      ..'\n- '..L["minimap button (the default)"]
      ..'\n- '..L["a normal 'To-Do List' button"]
      ..'\n- '..L["databroker plugin (eg. titan panel)"]
      ..'\n- '..L["the '/tdl' command"]
      ..'\n- '..L["key binding"]
      ..'\n'..L["You can go to the addon options in the game's interface settings to customize this."])
  end,

  [L["categories"]] = function()
    chat:PrintForced(L["Information on categories:"]
      .."\n- "..L["Left-click on the category names to expand or shrink their content."]
      .."\n- "..L["Right-click on the category names to add new items."])
  end,

  [L["favorites"]] = function()
    chat:PrintForced(L["You can favorite items!"]..' '..L["(toggle the edit mode to do so)"]
      .."\n- "..L["customizable color"]
      .."\n- "..L["sorted first in categories"]
      .."\n- "..L["have their own more visible remaining numbers"]
      .."\n- "..L["have an auto chat warning/reminder system!"]
      .."\n- "..L["the item cannot be deleted"])
  end,

  [L["descriptions"]] = function()
    chat:PrintForced(L["You can add descriptions on items!"]..' '..L["(toggle the edit mode to do so)"]
      .."\n- "..L["they are auto-saved and have no length limitations"]
      .."\n- "..L["the item cannot be deleted"]..' '..L["(empty the description if you want to do so)"])
  end,

  [L["hyperlinks"]] = function()
    chat:PrintForced(L["You can add hyperlinks in the list!"]
      ..' '..L["It works the same way as when you link items or other things in the chat, just shift-click!"])
  end,

  [L["editmode"]] = function()
    chat:PrintForced(L["Either right-click anywhere on the list, or click on the dedicated button to toggle the edit mode."]
      .."\n"..L["In edit mode, you can:"]
      .."\n- "..L["Delete items and categories"]
      .."\n- "..L["Favorite and add descriptions on items"]
      .."\n- "..L["Rename items and categories (double-click)"]
      .."\n- "..L["Reorder/Sort the list (drag & drop)"]
      .."\n- "..L["Resize the list"]
      .."\n- "..L["Undo what you deleted and access special actions for the tab"]
  )
  end,

  [L["tutorial"]] = function()
    tutorialsManager:Reset()
    chat:PrintForced(L["The tutorial has been reset!"])
  end,
}

-- Command catcher:
function chat.HandleSlashCommands(str)
  local path = chat.commands -- alias

  if #str == 0 then
    -- we just entered "/tdl" with no additional args
    path[""]()
    return
  end

  local args = { string.split(' ', str) }

  local deep = 1
  for id, arg in pairs(args) do
    if path[arg] then
      if type(path[arg]) == "function" then
        -- all remaining args passed to our function!
        path[arg](select(id + 1, unpack(args)))
        return
      elseif type(path[arg]) == "table" then
        deep = deep + 1
        path = path[arg] -- another sub-table found!

        if (select(deep, unpack(args))) == nil then
          -- here we just entered into a sub table, with no additional args
          path[""]()
          return
        end
      end
    else
      -- does not exist!
      chat.commands[L["info"]]()
      return
    end
  end
end
