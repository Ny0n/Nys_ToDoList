--/*******************/ IMPORTS /*************************/--

-- File init
local database = NysTDL.database
NysTDL.database = database -- for IntelliSense

-- Primary aliases
local libs = NysTDL.libs
local core = NysTDL.core
local enums = NysTDL.enums
local widgets = NysTDL.widgets
local migration = NysTDL.migration
local dataManager = NysTDL.dataManager
local resetManager = NysTDL.resetManager

-- Secondary aliases
local L = libs.L
local AceConfigRegistry = libs.AceConfigRegistry
local addonName = core.addonName

--/*******************************************************/--

local private = {}

--/*******************/ TABLES /*************************/--

-- addon themes
database.themes = {
	theme = { 0, 204, 255 }, -- theme
	theme2 = { 0, 204, 102 }, -- theme2
	theme_yellow = { 255, 216, 0 }, -- theme_yellow

	-- colors
	white = { 255, 255, 255 },
	black = { 0, 0, 0 },
	red = { 255, 0, 0 },
	yellow = { 255, 180, 0 },
	green = { 0, 255, 0 },
}

-- AceDB defaults table
database.defaults = {
	global = {
		-- // Version
		latestVersion = "", -- used to update the global saved variables once after each addon update

		-- // GLOBAL DATA
		itemsList = {},
		categoriesList = {},
		tabsList = {
			orderedTabIDs = { -- to have an order in which we display the tabs buttons
				-- tabID, -- [1]
				-- tabID, -- [2]
				-- ... -- [...]
			},
		},

		-- // Global ID
		nextID = "", -- forever increasing, defaults to the current time (time()) in hexadecimal

		-- // Misc
		tuto_progression = 0,
		-- tutorials_progression = {}, TDLATER
		UI_reloading = false,
		warnTimerRemaining = 0,
	},
	profile = {
		-- // Version
		latestVersion = "", -- used to update the profile saved variables once after each addon update, independent for each profile

		-- // PROFILE DATA
		itemsList = {},
		categoriesList = {},
		tabsList = {
			orderedTabIDs = { -- to have an order in which we display the tabs buttons
				-- tabID, -- [1]
				-- tabID, -- [2]
				-- ... -- [...]
			},
		},
		undoTable = {},

		-- // MIGRATION DATA
		migrationData = { -- see private:Failed in migration.lua
			failed = nil,
			saved = nil,
			version = nil,
			errmsg = nil,
			warning = nil,
			tuto = nil,
		},

		-- // Misc
		currentTab = "TOSET", -- currently selected tab ID, set when the default tabs are created
		databrokerMode = enums.databrokerModes.simple,
		lastListVisibility = false,
		lockList = false, -- TDLATER
		lockButton = false, -- TDLATER

		-- // Frame Options
		framePos = { point = "CENTER", relativePoint = "CENTER", xOffset = 0, yOffset = 0 },
		frameSize = { width = enums.tdlFrameDefaultWidth, height = enums.tdlFrameDefaultHeight },
		frameAlpha = 65,
		frameContentAlpha = 100,
		affectDesc = true,
		descFrameAlpha = 65,
		descFrameContentAlpha = 100,

		-- // Addon Options

		--'General' tab
		minimap = { hide = false, minimapPos = 241, lock = false, tooltip = true }, -- for LibDBIcon
		tdlButton = { show = false, red = false, points = { point = "CENTER", relativePoint = "CENTER", xOffset = 0, yOffset = 0 } },
		favoritesColor = { 1, 0.5, 0.6 },
		rainbow = false,
		rainbowSpeed = 2,
		rememberUndo = true,
		highlightOnFocus = true,
		keepOpen = false,
		openByDefault = false,
		descriptionTooltip = true,

		--'Tabs' tab
		instantRefresh = false, -- profile-wide

		--'Chat Messages' tab
		showChatMessages = true,
		showWarnings = false,
		favoritesWarning = true,
		normalWarning = false,
		hourlyReminder = false,
	}, -- profile
}

--/*******************/ DATABASE FUNCTIONS /*************************/--

-- // DB init & change

-- this func is called once in initialize, on the addon load
-- and also everytime we switch profiles
function private:DBInit()
	dataManager.authorized = false -- there's no calling mainFrame funcs while we're tampering with the database!

	local noTabs = not dataManager:IsID(database.ctab())

	-- default tabs creation
	if noTabs then
		private:CreateDefaultTabs()
	end

	migration:Migrate() -- trying to migrate the old vars

	if noTabs then
		-- !! after the (potential) var migration, we rename the tabs to match the locale,
		-- this is a security in case the locale was not correctly done

		-- we find the main tab IDs to rename them
		for tabID,tabData in dataManager:ForEach(enums.tab, false) do -- TDLATER global
			if tabData.name == enums.mainTabs.all then
				dataManager:Rename(tabID, L["All"])
			elseif tabData.name == enums.mainTabs.daily then
				dataManager:Rename(tabID, L["Daily"])
			elseif tabData.name == enums.mainTabs.weekly then
				dataManager:Rename(tabID, L["Weekly"])
			end
		end
	end

	-- // initialization of elements that need to be updated correctly when the profile changes

	-- remember undos
	if not NysTDL.acedb.profile.rememberUndo then
		wipe(NysTDL.acedb.profile.undoTable)
	end

	-- data quantities
	dataManager:UpdateQuantities()

	dataManager.authorized = true
end

function private:ProfileChanged(_, profile)
	-- // here we update (basically in the same order as the core init) everything
	-- that needs an update after a database change

	-- #1 - database (always init a database)
	private:DBInit()

	-- #2 - options
	AceConfigRegistry:NotifyChange(addonName)

	-- #last-1 - widgets (we update che changes to the UI elements)
	widgets:ProfileChanged()

	-- #last - tabs resets
	resetManager:Initialize(true)
end

function private:CreateDefaultTabs()
	-- once per profile, we create the default addon tabs (All, Daily, Weekly)
	local selectedtabID

	for g=1, 1 do -- TDLATER fix ==> 1, 2
		local isGlobal = g == 2

		-- All
		local allTabID = dataManager:CreateTab(enums.mainTabs.all, isGlobal)

		-- Daily
		local dailyTabID, dailyTabData = dataManager:CreateTab(enums.mainTabs.daily, isGlobal)
		if not isGlobal then selectedtabID = dailyTabID end -- default tab

		-- Weekly
		local weeklyTabID, weeklyTabData = dataManager:CreateTab(enums.mainTabs.weekly, isGlobal)

		-- All data
		dataManager:UpdateShownTabID(allTabID, dailyTabID, true)
		dataManager:UpdateShownTabID(allTabID, weeklyTabID, true)

		-- Daily data (isSameEachDay already true)
		for i=1,7 do resetManager:UpdateResetDay(dailyTabID, i, true) end -- every day
		resetManager:RenameResetTime(dailyTabID, dailyTabData.reset.sameEachDay, enums.defaultResetTimeName, L["Daily"])
		resetManager:UpdateTimeData(dailyTabID, dailyTabData.reset.sameEachDay.resetTimes[L["Daily"]], 9, 0, 0)

		-- Weekly data (isSameEachDay already true)
		resetManager:UpdateResetDay(weeklyTabID, 4, true) -- only wednesday
		resetManager:RenameResetTime(weeklyTabID, weeklyTabData.reset.sameEachDay, enums.defaultResetTimeName, L["Weekly"])
		resetManager:UpdateTimeData(weeklyTabID, weeklyTabData.reset.sameEachDay.resetTimes[L["Weekly"]], 9, 0, 0)
	end

	-- then we set the default tab
	database.ctab(selectedtabID)
end

-- // specific functions

---Easy access to that specific database variable.
---@param newTabID string|nil
---@return string ctab
function database.ctab(newTabID)
	-- sets or gets the currently selected tab ID
	if dataManager:IsID(newTabID) then
		NysTDL.acedb.profile.currentTab = newTabID
	end
	return NysTDL.acedb.profile.currentTab
end

--/*******************/ INITIALIZATION /*************************/--

function database:Initialize()
	-- Saved variable database
	NysTDL.acedb = LibStub("AceDB-3.0"):New("NysToDoListDB", database.defaults)
	private:DBInit() -- initialization for some elements of the current acedb

	-- callbacks for database changes
	NysTDL.acedb.RegisterCallback(private, "OnProfileChanged", "ProfileChanged")
	NysTDL.acedb.RegisterCallback(private, "OnProfileCopied", "ProfileChanged")
	NysTDL.acedb.RegisterCallback(private, "OnProfileReset", "ProfileChanged")
	NysTDL.acedb.RegisterCallback(private, "OnDatabaseReset", "ProfileChanged")
end
