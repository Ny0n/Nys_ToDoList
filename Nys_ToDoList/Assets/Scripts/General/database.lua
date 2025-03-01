--/*******************/ IMPORTS /*************************/--

-- File init

local database = NysTDL.database
NysTDL.database = database

-- Primary aliases

local libs = NysTDL.libs
local core = NysTDL.core
local enums = NysTDL.enums
local utils = NysTDL.utils
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
		currentGlobalTab = "", -- updated each time we change tabs

		tutorials_progression = {},
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
		},

		-- // Misc
		currentTabState = false, -- false = profile, true = global
		currentProfileTab = "", -- updated each time we change tabs

		databrokerMode = enums.databrokerModes.simple,
		isInMiniView = false,
		lastListVisibility = false,
		lockList = false,
		lockTdlButton = false,

		-- // Frame Options
		framePos = { point = "CENTER", relativePoint = "CENTER", xOffset = 0, yOffset = 0 },
		frameSize = { width = enums.tdlFrameDefaultWidth, height = enums.tdlFrameDefaultHeight },
		frameStrata = "DIALOG",
		frameAlpha = 75,
		frameContentAlpha = 100,
		affectDesc = true,
		descFrameAlpha = 75,
		descFrameContentAlpha = 100,

		-- // Addon Options

		--'General' tab
		minimap = { hide = false, minimapPos = 241, lock = false, tooltip = true }, -- for LibDBIcon
		tdlButton = { show = false, red = false, points = { point = "CENTER", relativePoint = "CENTER", xOffset = 0, yOffset = 0 } },
		favoritesColor = { 1, 0.5843137254901961, 0.996078431372549 },
		rainbow = false,
		rainbowSpeed = 2,
		rememberUndo = true,
		highlightOnFocus = true,
		descriptionTooltip = true,
		openBehavior = 1,
		frameScale = 1,
		addLast = false,

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
function private:DBInit(profile)
	dataManager.authorized = false -- there's no calling mainFrame funcs while we're tampering with the database!

	-- data quantities
	dataManager:UpdateQuantities()

	database.ctabstate(database.ctabstate()) -- update the state, in case we were focused on global tabs that were deleted when connected on other characters

	-- default tabs creation
	local noTabs = dataManager:GetQuantity(enums.tab, false) <= 0
	if noTabs then
		private:CreateDefaultTabs()
	end

	if not dataManager:IsID(database.ctab()) then
		database.ctab((select(3, dataManager:GetData(false))).orderedTabIDs[1]) -- currentTab was replaced by currentProfileTab, this is a safeguard check that defaults ctab to the first available tab, if none was set
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

	-- WARNING: Right now I'm only using the "profile" var to know if we are coming from a profile change or grom the importexport code,
	-- I don't care about what's inside of it, I only need to know if it is set or not

	-- remember undos
	if profile and not NysTDL.acedb.profile.rememberUndo then
		wipe(NysTDL.acedb.profile.undoTable)
	end

	dataManager.authorized = true
end

function database:ProfileChanged(_, profile)
	-- // here we update (basically in the same order as the core init) everything
	-- that needs an update after a database change

	-- #1 - database (always init a database)
	private:DBInit(profile)

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

		local resetDate = utils:GetWeeklyResetDate()

		-- Daily data (isSameEachDay already true)
		for i=1,7 do resetManager:UpdateResetDay(dailyTabID, i, true) end -- every day
		resetManager:RenameResetTime(dailyTabID, dailyTabData.reset.sameEachDay, enums.defaultResetTimeName, L["Daily"])
		resetManager:UpdateTimeData(dailyTabID, dailyTabData.reset.sameEachDay.resetTimes[L["Daily"]], resetDate.hour, resetDate.min, resetDate.sec)

		-- Weekly data (isSameEachDay already true)
		resetManager:UpdateResetDay(weeklyTabID, resetDate.wday, true) -- only weekly reset day
		resetManager:RenameResetTime(weeklyTabID, weeklyTabData.reset.sameEachDay, enums.defaultResetTimeName, L["Weekly"])
		resetManager:UpdateTimeData(weeklyTabID, weeklyTabData.reset.sameEachDay.resetTimes[L["Weekly"]], resetDate.hour, resetDate.min, resetDate.sec)
	end

	-- then we set the default tab
	database.ctab(selectedtabID)
end

-- // specific functions

---Gives an easy access to the `currentProfileTab & currentGlobalTab` acedb variable, while acting as a getter and a setter.
---@param newTabID string
---@return string currentTabID
function database.ctab(newTabID)
	-- sets or gets the currently selected tab ID
	if dataManager:IsID(newTabID) then
		if dataManager:IsGlobal(newTabID) then
			NysTDL.acedb.global.currentGlobalTab = newTabID
			database.ctabstate(true)
		else
			NysTDL.acedb.profile.currentProfileTab = newTabID
			database.ctabstate(false)
		end
	end

	if database.ctabstate() then
		if not dataManager:IsID(NysTDL.acedb.global.currentGlobalTab) then
			database.ctab(dataManager:GetTabsLoc(true)[1] or dataManager:GetTabsLoc(false)[1])
		end
		return NysTDL.acedb.global.currentGlobalTab
	else
		if not dataManager:IsID(NysTDL.acedb.profile.currentProfileTab) then
			database.ctab(dataManager:GetTabsLoc(false)[1])
		end
		return NysTDL.acedb.profile.currentProfileTab
	end
end

---Same as database.ctab, but for `currentTabState`.
---@param newTabState boolean
---@return boolean currentTabState
function database.ctabstate(newTabState)
	-- sets or gets the currently selected tab state
	if newTabState ~= nil then
		newTabState = not not newTabState -- cast to boolean
		if newTabState and not dataManager:HasGlobalData() then -- we can't be in a global state if we don't have global data
			newTabState = false
		end
		NysTDL.acedb.profile.currentTabState = newTabState
	end

	return NysTDL.acedb.profile.currentTabState
end

--/*******************/ INITIALIZATION /*************************/--

function database:Initialize()
	-- Saved variable database
	NysTDL.acedb = LibStub("AceDB-3.0"):New("NysToDoListDB", database.defaults)
	private:DBInit(true) -- initialization for some elements of the current acedb

	-- callbacks for database changes
	NysTDL.acedb.RegisterCallback(database, "OnProfileChanged", "ProfileChanged")
	NysTDL.acedb.RegisterCallback(database, "OnProfileCopied", "ProfileChanged")
	NysTDL.acedb.RegisterCallback(database, "OnProfileReset", "ProfileChanged")
	NysTDL.acedb.RegisterCallback(database, "OnDatabaseReset", "ProfileChanged")
end
