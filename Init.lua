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
		config:Print("List of slash commands:")
		config:Print("|cff00cc66/tdl|r - shows items frame");
		config:Print("|cff00cc66/tdl button|r - shows or hides the toggle button");
		config:Print("|cff00cc66/tdl help|r - shows help info");
		config:Print("(When adding a new category, the name of the first item is required)");
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

	config:Print("ToDoList loaded! type |cff00cc66/tdl help|r for information.");

  -- Register new Slash Command!
	SLASH_ToDoList1 = "/tdl";
	SlashCmdList.ToDoList = HandleSlashCommands;

	-- Initializing the saved variables
	if (ToDoListSV_checkedButtons == nil) then ToDoListSV_checkedButtons = {} end
	if (ToDoListSV_itemsList == nil) then
		ToDoListSV_itemsList = {
			["Daily"] = {},
			["Weekly"] = {},
		}
	end
	if (ToDoListSV_autoReset == nil) then
		ToDoListSV_autoReset = {
			["Daily"] = config:GetSecondsToReset().daily,
			["Weekly"] = config:GetSecondsToReset().weekly,
		}
	end

  -- We load the frame
  config:CreateItemsFrame();
end

--Creating the virtual frame to handle the event
local load = CreateFrame("Frame");
load:SetScript("OnEvent", init.Load);
load:RegisterEvent("ADDON_LOADED");-- We register the event of the addon loaded
----------------------------------
