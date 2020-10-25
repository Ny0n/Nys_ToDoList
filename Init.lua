--------------------------------------
-- Namespaces
--------------------------------------
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
		config:Print("|cff00cc66/tdl clear|r - clears the entire list (be careful with that!)");
	end,

	["uc"] = function(...)
		itemsFrame:ResetBtns("All");
	end,

	["clear"] = function(...)
    itemsFrame:ClearAll();
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
				path[arg](select(id+1, unpack(args)))
				return;
			elseif (type(path[arg]) == "table") then
				deep = deep+1;
				path = path[arg]; -- another sub-table found!

				if ((select(deep,unpack(args))) == nil) then
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
	-- since last update, there were a lot more saved variables, and in this one now
	-- i got rid of all of them and just placed everything in one brand new and alone saved variable,
	-- this means that to keep everything that was saved, we have to transfer the old variables in the new one,
	-- the first time and only the first time that we load the addon after the update (this is temporary)
	if (not ToDoListSV) then
		ToDoListSV = {
			checkedButtons = ToDoListSV_checkedButtons or {},
			itemsList = ToDoListSV_itemsList or { ["Daily"] = {}, ["Weekly"] = {} },
			autoReset = ToDoListSV_autoReset or { ["Daily"] = config:GetSecondsToReset().daily, ["Weekly"] = config:GetSecondsToReset().weekly },
			lastLoadedTab = ToDoListSV_lastLoadedTab or "ToDoListUIFrameTab1",
			closedCategories = {},
			newCatClosed = true,
		}
	end

  -- We load the frame
  config:CreateItemsFrame();

	config:Print("ToDoList loaded! type |cff00cc66/tdl help|r for information.");
end

--Creating the virtual frame to handle the event
local load = CreateFrame("Frame");
load:SetScript("OnEvent", init.Load);
load:RegisterEvent("ADDON_LOADED");-- We register the event of the addon loaded
----------------------------------
