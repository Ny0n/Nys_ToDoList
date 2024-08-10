-- Namespace
local addonName = ...

--/*******************/ ADDON LIBS AND DATA HANDLER /*************************/--

-- declaring the different addon tables, one for each file

local LibStub = LibStub

-- //** data **//

NysTDL = LibStub("AceAddon-3.0"):NewAddon(addonName) -- Addon object
NysTDL.acedb = nil -- defined in database.lua

-- //** libraries **//

NysTDL.libs = {
	AceConfig = LibStub("AceConfig-3.0"),
	AceConfigCmd = LibStub("AceConfigCmd-3.0"),
	AceConfigDialog = LibStub("AceConfigDialog-3.0"),
	AceConfigRegistry = LibStub("AceConfigRegistry-3.0"),
	AceDB = LibStub("AceDB-3.0"),
	AceDBOptions = LibStub("AceDBOptions-3.0"),
	AceEvent = LibStub("AceEvent-3.0"),
	AceGUI = LibStub("AceGUI-3.0"),
	AceSerializer = LibStub("AceSerializer-3.0"),
	AceTimer = LibStub("AceTimer-3.0"),

	L = LibStub("AceLocale-3.0"):GetLocale(addonName),
	Locale = GetLocale(),

	LDB = LibStub("LibDataBroker-1.1"),
	LDBIcon = LibStub("LibDBIcon-1.0"),

	LibQTip = LibStub("LibQTip-1.0"),
	LibDeflate = LibStub("LibDeflate"),
}

-- //** files **//

NysTDL.chat = {}
NysTDL.database = {}
NysTDL.dataManager = {}
NysTDL.enums = {}
NysTDL.events = {}
NysTDL.importexport = {}
NysTDL.migration = {}
NysTDL.optionsManager = {}
NysTDL.resetManager = {}
NysTDL.tutorialsManager = {}
NysTDL.utils = {}
NysTDL.databroker = {}
NysTDL.dragndrop = {}
NysTDL.mainFrame = {}
NysTDL.tabsFrame = {}
NysTDL.widgets = {}
NysTDL.core = {}

--/***************************************************************************/--

--/*******************/ IMPORTS /*************************/--

-- File init

local core = NysTDL.core
NysTDL.core = core

-- Primary aliases

local libs = NysTDL.libs
local chat = NysTDL.chat
local utils = NysTDL.utils
local events = NysTDL.events
local widgets = NysTDL.widgets
local database = NysTDL.database
local resetManager = NysTDL.resetManager
local optionsManager = NysTDL.optionsManager

-- Secondary aliases

local L = libs.L

--/*******************************************************/--

-- // LOCALE CHECK //

if libs.Locale == "enGB" then
	libs.Locale = "enUS"
end

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
		["Add"] = true,
	},
	temp = {
		-- checking if each chat command's locale is different, otherwise we won't be able to use them
	}
}

for orig,locale in pairs(libs.L) do
	-- if a locale is empty or only whitespace, we replace it by the original text
	-- and if it is valid, we remove any potential spaces at the start and at the end of the string (had that scenario once)
	-- AND if it is a chat command, we remove ANY spaces we find, because they are forbidden in chat commands

	if type(locale) ~= "string" or #locale == 0 or string.match(locale, "^%s*$") then
		libs.L[orig] = orig
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
		libs.L[orig] = locale
	end
end

-- if a chat command was duplicated (forbidden), we reset them to their original state,
-- and print a message in the chat to notify that there was an error (in chat.lua, check chat.commandLocales.isOK)
chat.commandLocales.temp = nil
if not chat.commandLocales.isOK then
	for orig in pairs(chat.commandLocales.list) do
		libs.L[orig] = orig
	end
end

-- //~ LOCALE CHECK ~//

-- data (from toc file)
core.toc = {}
core.toc.title = C_AddOns.GetAddOnMetadata(addonName, "Title") -- better than "Nys_ToDoList"
core.toc.version = C_AddOns.GetAddOnMetadata(addonName, "Version")

core.toc.isDev = ""
--@do-not-package@
core.toc.isDev = " WIP"
--@end-do-not-package@

-- Variables
core.loaded = false
core.addonUpdated = false
core.addonName = addonName
core.simpleAddonName = string.gsub(core.toc.title, "Ny's ", "")

-- Bindings.xml globals
core.bindings = {}

core.bindings.header = "NysTDL"
core.bindings.toggleList = "NysTDL_ToggleList"

_G["BINDING_HEADER_"..core.bindings.header] = core.toc.title
_G["BINDING_NAME_"..core.bindings.toggleList] = L["Show/Hide the To-Do List"]

--@do-not-package@
-- global variables
NysTDL_BACKDROP_INFO = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = false, tileSize = 1, edgeSize = 10,
	insets = { left = 0, right = 0, top = 0, bottom = 0 }
}
--@end-do-not-package@

-- Events and callbacks
core.Event_OnInitialize_Start = {}
core.Event_OnInitialize_End = {}

--/*******************/ AceAddon callbacks /*************************/--

function NysTDL:OnInitialize()
    -- Called when the addon has finished loading

	NysTDLBackup:ApplyPendingBackup()

	-- start initialization event
	for _,callback in ipairs(core.Event_OnInitialize_Start) do
		if type(callback) == "function" then
			callback()
		end
	end

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

	-- end initialization event
	for _,callback in ipairs(core.Event_OnInitialize_End) do
		if type(callback) == "function" then
			callback()
		end
	end

    -- // addon fully loaded!

    local hex = utils:RGBToHex(database.themes.theme2)
    chat:Print(L["Addon loaded!"].." ("..string.format("|cff%s%s|r", hex, chat.slashCommand.." "..L["info"])..")")

    -- checking for an addon update
    if core.addonUpdated then
		core:AddonUpdated()
		core.addonUpdated = false
    end

    core.loaded = true
end

function NysTDL:OnEnable()
	-- TDLATER
end

function NysTDL:OnDisable()
	-- TDLATER
end

--/*******************/ core /*************************/--

local changelog = {
	-- index table (not key-value), only place here the important changes.
}

---Called once, when the addon gets an update.
---Prints the changelog to the in-game chat. (@see local changelog table)
function core:AddonUpdated()
	if type(changelog) == "table" and #changelog > 0 then
		chat:PrintForced("New in "..core.toc.version..":")
		for _,v in ipairs(changelog) do
			if type(v) == "string" then
				chat:CustomPrintForced(v, true)
			end
		end
	end
end

---The error handler to give as parameter to `xpcall`.
function core.errorhandler(err)
	return "Message: \"" .. tostring(err) .. "\"\n"
		.. "Stack: \"" .. debugstack() .. "\""
end
