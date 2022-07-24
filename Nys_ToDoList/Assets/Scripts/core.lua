-- Namespaces
local addonName, addonTable = ...

--/*******************/ ADDON LIBS AND DATA HANDLER /*************************/--

-- declaring the different addon tables, one for each file
-- (that way everything is private and inaccessible in-game)

local LibStub = LibStub

-- addon object
NysTDL = LibStub("AceAddon-3.0"):NewAddon(addonName)

-- libs
addonTable.libs = {
	AceConfig = LibStub("AceConfig-3.0"),
	AceConfigCmd = LibStub("AceConfigCmd-3.0"),
	AceConfigDialog = LibStub("AceConfigDialog-3.0"),
	AceConfigRegistry = LibStub("AceConfigRegistry-3.0"),
	AceDB = LibStub("AceDB-3.0"),
	AceDBOptions = LibStub("AceDBOptions-3.0"),
	AceEvent = LibStub("AceEvent-3.0"),
	AceGUI = LibStub("AceGUI-3.0"),
	AceTimer = LibStub("AceTimer-3.0"),

	L = LibStub("AceLocale-3.0"):GetLocale(addonName),
	Locale = GetLocale(),

	LDB = LibStub("LibDataBroker-1.1"),
	LDBIcon = LibStub("LibDBIcon-1.0"),

	LibQTip = LibStub('LibQTip-1.0'),
}

-- files
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

--/***************************************************************************/--

-- addonTable aliases
local libs = addonTable.libs
local core = addonTable.core
local chat = addonTable.chat
local utils = addonTable.utils
local events = addonTable.events
local widgets = addonTable.widgets
local database = addonTable.database
local resetManager = addonTable.resetManager
local optionsManager = addonTable.optionsManager

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

local L = libs.L

-- data (from toc file)
core.toc = {}
core.toc.title = GetAddOnMetadata(addonName, "Title") -- better than "Nys_ToDoList"
core.toc.version = GetAddOnMetadata(addonName, "Version")

-- Variables
core.loaded = false
core.addonUpdated = false
core.simpleAddonName = string.gsub(core.toc.title, "Ny's ", "")

-- Bindings.xml globals
BINDING_HEADER_NysTDL = core.toc.title
BINDING_NAME_NysTDL_ToggleFrame = L["Show/Hide the To-Do List"]

--@do-not-package@
-- global variables
NysTDL_BACKDROP_INFO = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = false, tileSize = 1, edgeSize = 10,
	insets = { left = 0, right = 0, top = 0, bottom = 0 }
}
--@end-do-not-package@

--/*******************/ AceAddon callbacks /*************************/--

function NysTDL:OnInitialize()
    -- Called when the addon has finished loading

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

--/*******************/ Addon Updated /*************************/--

function core:AddonUpdated()
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
