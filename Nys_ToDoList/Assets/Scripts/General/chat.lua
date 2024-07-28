--/*******************/ IMPORTS /*************************/--

-- File init

local chat = NysTDL.chat
NysTDL.chat = chat

-- Primary aliases

local libs = NysTDL.libs
local core = NysTDL.core
local enums = NysTDL.enums
local utils = NysTDL.utils
local database = NysTDL.database
local mainFrame = NysTDL.mainFrame
local dataManager = NysTDL.dataManager
local resetManager = NysTDL.resetManager
local tutorialsManager = NysTDL.tutorialsManager

-- Secondary aliases

local L = libs.L

--/*******************************************************/--

--/*******************/ CHAT RELATED FUNCTIONS /*************************/--

---Prints the arguments only if `showChatMessages` is true.
---@see chat:PrintForced(...)
---@param ... any
function chat:Print(...)
	if not NysTDL.acedb.profile.showChatMessages then return end -- we don't print anything if the user chose to deactivate this
	self:PrintForced(...)
end

local T_PrintForced = {}
---Prints the given arguments to the `DEFAULT_CHAT_FRAME`.
---@param ... any
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

---Controls wether or not we add the addon prefix to the message.
---@param str string Can either be a string, or anything that is `tostring()`-able
---@param noprefix boolean
function chat:CustomPrintForced(str, noprefix)
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

---Warning function
function chat:Warn()
	if NysTDL.acedb.profile.showWarnings then -- if the option is checked
		if not resetManager:autoResetedThisSessionGET() then -- we don't want to show this warning if it's the first log in of the day, only if it is the next ones
			local haveWarned = false
			local warn = "--------------| |cffff0000"..L["Warning"]:upper().."|r |--------------"

			if NysTDL.acedb.profile.favoritesWarning then -- and the user allowed this functionnality
				local uncheckedFav = dataManager:GetRemainingNumbers().uncheckedFav
				if uncheckedFav > 0 then
					local msg = ""

					local maxTime = time() + 86400
					dataManager:DoIfFoundTabMatch(maxTime, "uncheckedFav", function(tabID, tabData)
						local nb = dataManager:GetRemainingNumbers(nil, tabID).uncheckedFav
						if msg ~= "" then
							msg = msg.." + "
						end
						msg = msg..tostring(nb).." ("..tostring(tabData.name)..")"
					end, true)

					if msg ~= "" then
						local hex = utils:RGBToHex({ NysTDL.acedb.profile.favoritesColor[1]*255, NysTDL.acedb.profile.favoritesColor[2]*255, NysTDL.acedb.profile.favoritesColor[3]*255} )
						msg = string.format("|cff%s%s|r", hex, msg)
						if not haveWarned then chat:PrintForced(warn) haveWarned = true end
						chat:PrintForced(utils:SafeStringFormat(L["You still have %s favorite item(s) to do before the next reset"]..".", msg))
					end
				end
			end

			if NysTDL.acedb.profile.normalWarning then
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

			-- -- TDLATER maybe also do this if I ever want to redo this system
			-- if haveWarned then
			-- 	local timeUntil = resetManager:GetTimeUntilReset()
			-- 	local msg = utils:SafeStringFormat(L["Time remaining: %i hours %i min"], timeUntil.hour, timeUntil.min + 1)
			-- 	chat:PrintForced(msg)
			-- end
		end
	end
end

--/*******************/ CHAT COMMANDS /*************************/--

chat.slashCommand = "/tdl"

chat.commands = {
	[""] = function()
		mainFrame:Toggle()
	end,

	[L["info"]] = function()
		local hex = utils:RGBToHex(database.themes.theme2)
		local slashCommand = chat.slashCommand..' '

		local str = L["Here are a few commands to help you"]..":\n"

		str = str.." -- "..string.format("|cff%s%s|r", hex, slashCommand..L["toggle"])
		str = str.." -- "..string.format("|cff%s%s|r", hex, slashCommand..L["categories"])
		str = str.." -- "..string.format("|cff%s%s|r", hex, slashCommand..L["hyperlinks"])
		str = str.." -- "..string.format("|cff%s%s|r", hex, slashCommand..L["editmode"])
		str = str.." -- "..string.format("|cff%s%s|r", hex, slashCommand..L["favorites"])
		str = str.." -- "..string.format("|cff%s%s|r", hex, slashCommand..L["descriptions"])
		str = str.." -- "..string.format("|cff%s%s|r", hex, slashCommand..L["tutorial"])
		str = str.." -- "..string.format("|cff%s%s|r", hex, slashCommand..string.lower(L["Add"]))
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
		chat:CustomPrintForced("- "..utils:SafeStringFormat(L["The %s command"], "\""..chat.slashCommand.."\""), true)
		chat:CustomPrintForced("- "..L["Databroker plugin (e.g. Titan Panel)"], true)
		chat:CustomPrintForced("- "..L["Key binding"], true)
		chat:CustomPrintForced(L["You can go to the addon options in the game's interface settings to customize this"]..".", true)
	end,

	[L["categories"]] = function()
		chat:CustomPrintForced(L["Information on categories"]..":")
		chat:CustomPrintForced("- "..L["Left-click on the category names to expand or shrink their content"]..".", true)
		chat:CustomPrintForced("- "..utils:SafeStringFormat(L["To add elements in a category, hover the name and press the %s icon"], enums.icons.add.texHyperlinkChat).." ("..string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), L["Left-Click"])..utils:GetMinusStr()..L["Add an item"]..", "..string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), L["Right-Click"])..utils:GetMinusStr()..L["Add a category"]..").", true)
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
		chat:CustomPrintForced("- "..L["Automatically saved"], true)
		chat:CustomPrintForced("- "..utils:SafeStringFormat(L["You can write up to %i characters"], enums.maxDescriptionCharCount), true)
	end,

	[L["hyperlinks"]] = function()
		chat:CustomPrintForced(L["You can add hyperlinks in the list!"])
		chat:CustomPrintForced(L["It works the same way as when you link items or other things in the chat, just shift-click"]..".", true)
	end,

	[L["editmode"]] = function()
		chat:CustomPrintForced(L["Either right-click anywhere on the list, or click on the dedicated button to toggle the edit mode"]..".")
		chat:CustomPrintForced("- "..L["Everything hidden becomes visible"], true)
		chat:CustomPrintForced("- "..L["Delete items and categories"], true)
		chat:CustomPrintForced("- "..L["Favorite and add descriptions on items"], true)
		chat:CustomPrintForced("- "..L["Rename items and categories"].." ("..L["Double-Click"]..")", true)
		chat:CustomPrintForced("- "..L["Reorder/Sort the list"].." ("..L["Drag and Drop"]..")", true)
		chat:CustomPrintForced("- "..L["Resize"].." ("..L["Button in the bottom-right"]..")", true)
		chat:CustomPrintForced("- "..L["Access new buttons"].." (\""..L["Tab actions"].."\", \""..L["Undo last remove"].."\", \""..L["Open addon options"].."\")", true)
		tutorialsManager:Validate("introduction", "editmodeChat")
	end,

	[L["tutorial"]] = function()
		tutorialsManager:Reset()
		chat:CustomPrintForced(L["All tutorials have been reset"])
	end,

	[string.lower(L["Add"])] = function(...)
		dataManager:CreateByCommand(false, ...)
	end,

	[string.lower(L["Add"].."*")] = function(...)
		dataManager:CreateByCommand(true, ...)
	end,
}

---Command catcher
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

--/*******************/ INITIALIZATION /*************************/--

-- Register new Slash Commands
SLASH_NysTDL1 = chat.slashCommand
SlashCmdList.NysTDL = chat.HandleSlashCommands
