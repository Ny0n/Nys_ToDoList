-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local chat = addonTable.chat
local enums = addonTable.enums
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
	local msg = T_PrintForced
	for i = 1, select("#", ...) do
		local s = (select(i, ...))
		if type(s) == "table" then
		for j = 1, #s do
			table.insert(msg, (select(j, unpack(s))))
		end
		else
			table.insert(msg, s)
		end
	end

	DEFAULT_CHAT_FRAME:AddMessage(string.join(' ', prefix, unpack(msg)))
end

function chat:CustomPrintForced(str, noprefix)
  -- to disable the prefix

  if str == nil then return end
  if not pcall(tostring, str) then return end
  str = tostring(str)

  local hex = utils:RGBToHex(database.themes.theme)
  local prefix = string.format("|cff%s%s|r", hex, core.toc.title..':')

  if noprefix then
    DEFAULT_CHAT_FRAME:AddMessage(str)
  else
    DEFAULT_CHAT_FRAME:AddMessage(prefix..' '..str)
  end
end

-- Warning function
function chat:Warn()
	if NysTDL.db.profile.showWarnings then -- if the option is checked
		if not resetManager:autoResetedThisSessionGET() then -- we don't want to show this warning if it's the first log in of the day, only if it is the next ones
			local haveWarned = false
			local warn = "--------------| |cffff0000"..L["Warning"]:upper().."|r |--------------"

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
						if not haveWarned then chat:PrintForced(warn) haveWarned = true end
						chat:PrintForced(utils:SafeStringFormat(L["You still have %s favorite item(s) to do before the next reset"]..".", msg))
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
						if not haveWarned then chat:PrintForced(warn) haveWarned = true end
						chat:PrintForced(L["Total number of items left to do before tomorrow"]..": "..tostring(total))
					end
				end
			end

			-- -- TDLATER maybe also do this if i ever want to redo this system
			-- if haveWarned then
			-- 	local timeUntil = resetManager:GetTimeUntilReset()
			-- 	local msg = utils:SafeStringFormat(L["Time remaining: %i hours %i min"], timeUntil.hour, timeUntil.min + 1)
			-- 	chat:PrintForced(msg)
			-- end
		end
	end
end

--/*******************/ CHAT COMMANDS /*************************/--

-- Commands:
chat.commands = {
	[""] = function()
		mainFrame:Toggle()
	end,

	[L["info"]] = function()
		local hex = utils:RGBToHex(database.themes.theme2)
		local slashCommand = core.slashCommand..' '

		local str = L["Here are a few commands to help you"]..":\n"

		str = str.." -- "..string.format("|cff%s%s|r", hex, slashCommand..L["toggle"])
		str = str.." -- "..string.format("|cff%s%s|r", hex, slashCommand..L["categories"])
		str = str.." -- "..string.format("|cff%s%s|r", hex, slashCommand..L["hyperlinks"])
		str = str.." -- "..string.format("|cff%s%s|r", hex, slashCommand..L["editmode"])
		str = str.." -- "..string.format("|cff%s%s|r", hex, slashCommand..L["favorites"])
		str = str.." -- "..string.format("|cff%s%s|r", hex, slashCommand..L["descriptions"])
		str = str.." -- "..string.format("|cff%s%s|r", hex, slashCommand..L["tutorial"])
		-- <!> When adding a new chat command, add its original (enUS) name in chat.commandLocales.list (in core.lua) <!>

		str = str.." -- "

		if not chat.commandLocales.isOK then
			str = str..enums.translationErrMsg
		end

		chat:CustomPrintForced(str)
	end,

	[L["toggle"]] = function()
		chat:CustomPrintForced(L["To toggle the list, you have several ways"]..":")
		chat:CustomPrintForced("- "..L["A minimap button"].." ("..L["Enabled by default"]..")", true)
		chat:CustomPrintForced("- "..utils:SafeStringFormat(L["A movable %s button"], "\""..core.simpleAddonName.."\""), true)
		chat:CustomPrintForced("- "..utils:SafeStringFormat(L["The %s command"], "\""..core.slashCommand.."\""), true)
		chat:CustomPrintForced("- "..L["Databroker plugin (e.g. Titan Panel)"], true)
		chat:CustomPrintForced("- "..L["Key binding"], true)
		chat:CustomPrintForced(L["You can go to the addon options in the game's interface settings to customize this"]..".", true)
	end,

	[L["categories"]] = function()
		chat:CustomPrintForced(L["Information on categories"]..":")
		chat:CustomPrintForced("- "..L["Left-click on the category names to expand or shrink their content"]..".", true)
		chat:CustomPrintForced("- "..L["Right-click on the category names to add new items"]..".", true)
	end,

	[L["favorites"]] = function()
		chat:CustomPrintForced(L["You can favorite items!"].." ("..L["Toggle the edit mode to do so"]..")")
		chat:CustomPrintForced("- "..L["Customizable color"], true)
		chat:CustomPrintForced("- "..L["Sorted first in categories"], true)
		chat:CustomPrintForced("- "..L["More visible remaining numbers"], true)
		chat:CustomPrintForced("- "..L["Chat warning/reminder system"], true)
	end,

	[L["descriptions"]] = function()
		chat:CustomPrintForced(L["You can add descriptions on items!"].." ("..L["Toggle the edit mode to do so"]..")")
		chat:CustomPrintForced("- "..L["They are automatically saved"], true)
		chat:CustomPrintForced("- "..utils:SafeStringFormat(L["You can write up to %i characters"], enums.maxDescriptionCharCount), true)
	end,

	[L["hyperlinks"]] = function()
		chat:CustomPrintForced(L["You can add hyperlinks in the list!"])
		chat:CustomPrintForced(L["It works the same way as when you link items or other things in the chat, just shift-click"]..".", true)
	end,

	[L["editmode"]] = function()
		chat:CustomPrintForced(L["Either right-click anywhere on the list, or click on the dedicated button to toggle the edit mode"]..".")
		chat:CustomPrintForced("- "..L["Delete items and categories"], true)
		chat:CustomPrintForced("- "..L["Favorite and add descriptions on items"], true)
		chat:CustomPrintForced("- "..L["Rename items and categories"].." ("..L["Double-Click"]..")", true)
		chat:CustomPrintForced("- "..L["Reorder/Sort the list"].." ("..L["Drag and Drop"]..")", true)
		chat:CustomPrintForced("- "..L["Resize the list"].." ("..L["Button in the bottom-right"]..")", true)
		chat:CustomPrintForced("- "..utils:SafeStringFormat(L["Access new buttons: %s and %s"], "\""..L["Undo last remove"].."\"", "\""..L["Tab actions"].."\""), true)
		tutorialsManager:Validate("TM_introduction_editmodeChat")
	end,

	[L["tutorial"]] = function()
		tutorialsManager:Reset()
		chat:CustomPrintForced(L["The tutorial has been reset"])
	end,
}

-- Command catcher:
function chat.HandleSlashCommands(str)
	local path = chat.commands -- alias

	if #str == 0 then
		-- we just entered the slash command with no additional args
		path[""]()
		return
	end

	local args = { string.split(' ', str) }

	local deep = 1
	for id, arg in pairs(args) do
		if path[arg] then
			if type(path[arg]) == "function" then
				-- all remaining args passed to our function!
				---@diagnostic disable-next-line: redundant-parameter
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
