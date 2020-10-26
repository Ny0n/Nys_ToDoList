-- Namespaces
local _, tdlTable = ...;
tdlTable.init = {}; -- adds init table to addon namespace

local config = tdlTable.config;
local itemsFrame = tdlTable.itemsFrame;
local init = tdlTable.init;

-- Commands:
init.commands = {
  [""] = function(...)
    itemsFrame:Toggle();
  end,

  ["button"] = function(...)
    itemsFrame:ToggleBtn();
  end,

  ["help"] = function(...)
    config:Print("Type |cff00cc66/tdl command|r to see all the slash commands");
    config:Print("When adding a new category, the name of the first item is required (there can't be an empty category)");
    config:Print("To add a new item, type its name in the editbox next to the category name you want to add your item in!");
    config:Print("You can click on the category names to expand or shrink their content, for more visibility");
  end,

  ["command"] = function(...)
    config:Print("List of slash commands:")
    config:Print("|cff00cc66/tdl|r - shows items frame");
    config:Print("|cff00cc66/tdl button|r - shows or hides the toggle button");
    config:Print("|cff00cc66/tdl help|r - shows help info");
    config:Print("|cff00cc66/tdl uc|r - unchecks every item");
    config:Print("|cff00cc66/tdl clear|r - clears the entire list");
  end,

  ["uc"] = function(...)
    itemsFrame:ResetBtns("All");
  end,

  ["clear"] = function(...)
    itemsFrame:ClearTab("All");
  end,

  ["undo"] = function(...)
    itemsFrame:UndoRemove();
  end,
}

-- Command catcher:
local function HandleSlashCommands(str)
  local path = init.commands; -- optimise!

  if (#str == 0) then
    -- User just entered "/tdl" with no additional args.
    path[""]();
    return;
  end

  local args = {string.split(' ', str)};

  local deep = 1;
  for id, arg in pairs(args) do
    arg = arg:lower(); -- current arg to low caps

    if (path[arg]) then
      if (type(path[arg]) == "function") then
        -- all remaining args passed to our function!
        path[arg](select(id + 1, unpack(args)))
        return;
      elseif (type(path[arg]) == "table") then
        deep = deep + 1;
        path = path[arg]; -- another sub-table found!

        if ((select(deep, unpack(args))) == nil) then
          -- User just entered "/tdl" with no additional args.
          path[""]();
          return;
        end
      end
    else
      -- does not exist!
      init.commands["help"]();
      return;
    end
  end
end

--Loading the AddOn----------------

-- Initialisation
function init:Load(self, name)
  if (name ~= "Nys_ToDoList") then
    return;
  end

  -- Register new Slash Command!
  SLASH_ToDoList1 = "/tdl";
  SlashCmdList.ToDoList = HandleSlashCommands;

  -- Initializing the saved variable
  if (ToDoListSV == nil) then
    ToDoListSV = {};
  end

  if (ToDoListSV.itemsList == nil) then ToDoListSV.itemsList = { ["Daily"] = {}, ["Weekly"] = {} } end

  if (ToDoListSV.weeklyDay == nil) then ToDoListSV.weeklyDay = 4 end
  if (ToDoListSV.dailyHour == nil) then ToDoListSV.dailyHour = 8 end
  if (ToDoListSV.autoReset == nil) then ToDoListSV.autoReset = { ["Daily"] = config:GetSecondsToReset().daily, ["Weekly"] = config:GetSecondsToReset().weekly } end

  if (ToDoListSV.newCatClosed == nil) then ToDoListSV.newCatClosed = true end
  if (ToDoListSV.optionsClosed == nil) then ToDoListSV.optionsClosed = true end
  if (ToDoListSV.toggleBtnIsShown == nil) then ToDoListSV.toggleBtnIsShown = true end
  if (ToDoListSV.showChatMessages == nil) then ToDoListSV.showChatMessages = true end
  if (ToDoListSV.rememberUndo == nil) then ToDoListSV.rememberUndo = true end

  if (ToDoListSV.lastLoadedTab == nil) then ToDoListSV.lastLoadedTab = "ToDoListUIFrameTab1" end
  if (ToDoListSV.checkedButtons == nil) then ToDoListSV.checkedButtons = {} end
  if (ToDoListSV.closedCategories == nil) then ToDoListSV.closedCategories = {} end
  if (not ToDoListSV.rememberUndo) then ToDoListSV.undoTable = nil end
  if (ToDoListSV.undoTable == nil) then ToDoListSV.undoTable = {} end


  -- We load the frame
  config:CreateItemsFrame();

  config:Print("ToDoList loaded! type |cff00cc66/tdl help|r for information.");
end

--Creating the virtual frame to handle the event
local load = CreateFrame("Frame");
load:SetScript("OnEvent", init.Load);
load:RegisterEvent("ADDON_LOADED");-- We register the event of the addon loaded
----------------------------------
