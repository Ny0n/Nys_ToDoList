-- Namespaces
local addonName, addonTable = ...

-- declaring the different addon tables, one for each file
-- because I don't want to use a global variable (after careful thinking, this will probably change soon :D)
addonTable.chat = {}
addonTable.database = {}
addonTable.dataManager = {}
addonTable.enums = {}
addonTable.events = {}
addonTable.migration = {}
addonTable.optionsManager = {}
addonTable.resetManager = {}
addonTable.tutorialsManager = {}
addonTable.utils = {}
addonTable.databroker = {}
addonTable.dragndrop = {}
addonTable.mainFrame = {}
addonTable.tabsFrame = {}
addonTable.widgets = {}
addonTable.core = {}

-- addonTable aliases
local core = addonTable.core
local chat = addonTable.chat
local utils = addonTable.utils
local events = addonTable.events
local widgets = addonTable.widgets
local database = addonTable.database
local resetManager = addonTable.resetManager
local optionsManager = addonTable.optionsManager

--/*******************/ ADDON LIBS AND DATA HANDLER /*************************/--

-- libs
NysTDL = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceTimer-3.0", "AceEvent-3.0")
core.AceGUI = LibStub("AceGUI-3.0")

core.L = LibStub("AceLocale-3.0"):GetLocale(addonName)
core.Locale = GetLocale()
if core.Locale == "enGB" then
	core.Locale = "enUS"
end

core.LDB = LibStub("LibDataBroker-1.1")
core.LDBIcon = LibStub("LibDBIcon-1.0")
core.LibQTip = LibStub('LibQTip-1.0')
-- core.LDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")

-- // LOCALE CHECK

chat.commandLocales = {
	isOK = true,
	list = {
		["info"] = true,
		["toggle"] = true,
		["categories"] = true,
		["hyperlinks"] = true,
		["editmode"] = true,
		["favorites"] = true,
		["descriptions"] = true,
		["tutorial"] = true,
	},
	temp = {
		-- checking if each chat command's locale is different, otherwise we won't be able to use them
	}
}

for orig,locale in pairs(core.L) do
	-- if a locale is empty or only whitespace, we replace it by the original text
	-- and if it is valid, we remove any potential spaces at the start and at the end of the string (had that scenario once)
	-- AND if it is a chat command, we remove ANY spaces we find, because they are forbidden in chat commands

	if type(locale) ~= "string" or #locale == 0 or string.match(locale, "^%s*$") then
		core.L[orig] = orig
	else
		if chat.commandLocales.list[orig] then
			-- we are a chat command
			locale = string.gsub(locale, "%s*", "")
			if not chat.commandLocales.temp[locale] then
				chat.commandLocales.temp[locale] = true
			else
				chat.commandLocales.isOK = false
			end
		else
			-- we are not a chat command
			locale = string.gsub(locale, "^%s*", "")
			locale = string.gsub(locale, "%s*$", "")
		end
		core.L[orig] = locale
	end
end

-- if a chat command was duplicated (forbidden), we reset them to their original state,
-- and print a message in the chat to notify that there was an error (in chat.lua, check chat.commandLocales.isOK)
chat.commandLocales.temp = nil
if not chat.commandLocales.isOK then
	for orig in pairs(chat.commandLocales.list) do
		core.L[orig] = orig
	end
end

-- //~ LOCALE CHECK

-- data (from toc file)
core.toc = {}
core.toc.title = GetAddOnMetadata(addonName, "Title") -- better than "Nys_ToDoList"
core.toc.version = GetAddOnMetadata(addonName, "Version")

-- Variables
local L = core.L
core.loaded = false
core.addonUpdated = false
core.slashCommand = "/tdl"
core.simpleAddonName = string.gsub(core.toc.title, "Ny's ", "")

-- Bindings.xml globals
BINDING_HEADER_NysTDL = core.toc.title
BINDING_NAME_NysTDL = L["Show/Hide the To-Do List"]

-- global variables
--@do-not-package@
NysTDL_BACKDROP_INFO = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = false, tileSize = 1, edgeSize = 10,
	insets = { left = 0, right = 0, top = 0, bottom = 0 }
}
--@end-do-not-package@

--/*******************/ INITIALIZATION /*************************/--

function NysTDL:OnInitialize()
    -- Called when the addon has finished loading

    -- Register new Slash Command
    SLASH_NysTDL1 = core.slashCommand
    SlashCmdList.NysTDL = chat.HandleSlashCommands

    -- #1 - database
    database:Initialize()

    -- #2 - options
    optionsManager:Initialize()

    -- events
    events:Initialize()

    -- #last-1 - widgets (we create every visual element)
    widgets:Initialize()

    -- #last - tabs resets
    resetManager:Initialize()

    -- // addon fully loaded!

    local hex = utils:RGBToHex(database.themes.theme2)
    chat:Print(L["Addon loaded!"].." ("..string.format("|cff%s%s|r", hex, core.slashCommand.." "..L["info"])..")")

    -- checking for an addon update
    if core.addonUpdated then
		NysTDL:AddonUpdated()
		core.addonUpdated = false
    end

    core.loaded = true
end

function NysTDL:AddonUpdated()
	-- called once, when the addon gets an update

	local changelog = {
		-- index table (not key-value)
	}

	if type(changelog) == "table" and #changelog > 0 then
		chat:PrintForced("New in "..core.toc.version..":")
		for _,v in ipairs(changelog) do
			if type(v) == "string" then
				chat:CustomPrintForced(v, true)
			end
		end
	end
end
