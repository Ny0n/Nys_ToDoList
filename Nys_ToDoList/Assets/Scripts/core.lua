-- Namespaces
local addonName, addonTable = ...

-- declaring the different addon tables, one for each file
-- because i don't want to use a global variable
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
core.LDB = LibStub("LibDataBroker-1.1")
core.LDBIcon = LibStub("LibDBIcon-1.0")
core.LibQTip = LibStub('LibQTip-1.0')
-- core.LDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")

-- LOCALE CHECK
-- if a locale is empty or only whitespace, we replace it by the original text
for orig,locale in pairs(core.L) do
  if #locale == 0 or locale:match("^%s*$") then core.L[orig] = orig end
end

-- data (from toc file)
core.toc = {}
core.toc.title = GetAddOnMetadata(addonName, "Title") -- better than "Nys_ToDoList"
core.toc.version = GetAddOnMetadata(addonName, "Version")

-- every addon versions up to the current one, to keep track of them
core.toc.versions = {
  "6.0.2",
  "6.0.1-beta",
  "6.0", -- redid the source code and separated it in different files, started using unique IDs, reworked the migration codes
  "5.7.1",
  "5.7",
  "5.6.2",
  "5.6.1",
  "5.6", -- final source code workflow, started keeping track of the "latestVersion"
  "5.5.2",
  "5.5.1", -- removed due to major bug
  "5.5", -- removed due to major bug
  "5.4",
  "5.3",
  "5.2.1",
  "5.2",
  "5.1",
  "5.0.1",
  "5.0",
  "4.0", -- started using libraries
  "3.0",
  "2.0",
  "1.3",
  "1.2",
  "1.1",
  "1.0",
}

-- Variables
local L = core.L
core.loaded = false
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

    -- checking for an addon update
    if NysTDL.db.global.addonUpdated then
      self:AddonUpdated()
      NysTDL.db.global.addonUpdated = false
    end

    local hex = utils:RGBToHex(database.themes.theme2)
    chat:Print(L["Addon loaded!"].." ("..string.format("|cff%s%s|r", hex, core.slashCommand.." "..L["info"])..")")
    core.loaded = true
end

function NysTDL:AddonUpdated()
  -- called once, when the addon gets an update
end
