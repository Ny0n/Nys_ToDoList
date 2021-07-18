-- Namespaces
local addonName, addonTable = ...

-- declaring the different addon tables, one for each file
-- because i don't want to use a global variable
addonTable.chat = {}
addonTable.database = {}
addonTable.enums = {}
addonTable.events = {}
addonTable.optionsManager = {}
addonTable.resetManager = {}
addonTable.utils = {}
addonTable.databroker = {}
addonTable.dataManager = {}
addonTable.mainFrame = {}
addonTable.tutorialsManager = {}
addonTable.widgets = {}
addonTable.core = {}

-- addonTable aliases
local core = addonTable.core
local chat = addonTable.chat
local utils = addonTable.utils
local events = addonTable.events
local widgets = addonTable.widgets
local database = addonTable.database
local databroker = addonTable.databroker
local optionsManager = addonTable.optionsManager

--/*******************/ ADDON LIBS AND DATA HANDLER /*************************/--

-- libs
NysTDL = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceTimer-3.0", "AceEvent-3.0")
core.AceGUI = LibStub("AceGUI-3.0")
core.L = LibStub("AceLocale-3.0"):GetLocale(addonName)
core.LDB = LibStub("LibDataBroker-1.1")
core.LDBIcon = LibStub("LibDBIcon-1.0")
core.LDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")

-- data (from toc file)
core.toc = {}
core.toc.title = GetAddOnMetadata(addonName, "Title") -- better than "Nys_ToDoList"
core.toc.version = GetAddOnMetadata(addonName, "Version")

-- Variables
local L = core.L
core.loaded = false

-- Bindings.xml globals
BINDING_HEADER_NysTDL = core.toc.title
BINDING_NAME_NysTDL = L["Show/Hide the To-Do List"]

--/*******************/ INITIALIZATION /*************************/--

function NysTDL:OnInitialize()
    -- Called when the addon has finished loading

    -- Register new Slash Command
    SLASH_NysTDL1 = "/tdl"
    SlashCmdList.NysTDL = chat.HandleSlashCommands

    -- database #1
    database:Initialize()

    -- options #2
    optionsManager:Initialize()

    -- events
    events:Initialize()

    -- we create every visual element #last
    widgets:Initialize()

    -- // addon fully loaded!

    -- checking for an addon update
    if NysTDL.db.global.addonUpdated then
      self:AddonUpdated()
      NysTDL.db.global.addonUpdated = false
    end

    local hex = utils:RGBToHex(database.themes.theme2)
    chat:Print(L["addon loaded!"]..' ('..string.format("|cff%s%s|r", hex, "/tdl "..L["info"])..')')
    core.loaded = true
end

function NysTDL:AddonUpdated()
  -- called once, when the addon gets an update
  print("wait what no way")
end
