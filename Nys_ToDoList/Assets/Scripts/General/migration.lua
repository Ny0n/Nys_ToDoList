--/*******************/ IMPORTS /*************************/--

-- File init

local migration = NysTDL.migration
NysTDL.migration = migration

-- Primary aliases

local libs = NysTDL.libs
local core = NysTDL.core
local enums = NysTDL.enums
local utils = NysTDL.utils
local widgets = NysTDL.widgets
local database = NysTDL.database
local mainFrame = NysTDL.mainFrame
local dataManager = NysTDL.dataManager
local resetManager = NysTDL.resetManager
local tutorialsManager = NysTDL.tutorialsManager

-- Secondary aliases

local L = libs.L
local LibQTip = libs.LibQTip

--/*******************************************************/--

local private = {}

local migrationData = {
    versions = {
        "2.0",
        "4.0",
        "5.0",
        "5.5",
        "6.0"
    },
    codes = {}, -- defined later in the file
    failed = {
        saved = {},
        version = "",
        codes = {}, -- defined later in the file
    },
}

-- // **************************** // --

---Checks if the addon got an update, and if so (and depending on the update version),
---it will apply the changes and try to migrate the saved variables to the new ones.
function migration:Migrate()
    -- this is for doing specific things ONLY when the addon gets updated and its version changes

    if NysTDL.acedb.profile.migrationData.failed then -- the migration was not completed last session, so we recreate the recovery list
        private:Failed()
    end

    -- checking for an addon update, globally
    if NysTDL.acedb.global.latestVersion ~= core.toc.version then
        private:GlobalNewVersion()
        NysTDL.acedb.global.latestVersion = core.toc.version
        core.addonUpdated = true
    end

    -- checking for an addon update, for the profile that was just loaded
    if NysTDL.acedb.profile.latestVersion ~= core.toc.version then
        private:ProfileNewVersion()
        NysTDL.acedb.profile.latestVersion = core.toc.version
    end
end

-- // **************************** // --

-- these two functions are called only once, each time there is an addon update
function private:GlobalNewVersion()
    -- // updates the global saved variables once after an update

    if utils:IsVersionOlderThan(NysTDL.acedb.global.latestVersion, "7.0-alpha") then
        local oldProgression = NysTDL.acedb.global.tuto_progression
        local newProgression = NysTDL.acedb.global.tutorials_progression

        local oldNeeds = type(oldProgression) == "number" and oldProgression > 2 or false
        local newNeeds = (type(newProgression) == "number" and newProgression > 2) or type(newProgression) == "boolean"
		if oldNeeds or newNeeds then
            NysTDL.acedb.global.tutorials_progression["introduction"] = 2 -- restart the tuto from the moment where we add new items
        end
	end

	if utils:IsVersionOlderThan(NysTDL.acedb.global.latestVersion, "7.2.4") then
		pcall(function() -- it's okay if we don't manage to change the default daily and weekly reset date, ppl can do it themselves
			local dailyTabID = dataManager:FindFirstIDByName(L["Daily"], enums.tab, false)
			local _, _, dailyTabData = dataManager:Find(dailyTabID)

			local weeklyTabID = dataManager:FindFirstIDByName(L["Weekly"], enums.tab, false)
			local _, _, weeklyTabData = dataManager:Find(weeklyTabID)

			local dailyResetTimeTable = dailyTabData.reset.sameEachDay.resetTimes[L["Daily"]]
			local weeklyResetTimeTable = weeklyTabData.reset.sameEachDay.resetTimes[L["Weekly"]]

			local function hasOnlyOneKey(tbl, key)
				return next(tbl) == key and not next(tbl, key)
			end

			-- also don't forget to take into account the previous addon version's hour retargetting from 9 to 6
			local isSetToDefault = 	(dailyResetTimeTable.hour == 6 or dailyResetTimeTable.hour == 9)
									and (weeklyResetTimeTable.hour == 6 or weeklyResetTimeTable.hour == 9)
									and hasOnlyOneKey(weeklyTabData.reset.days, 4)

			if isSetToDefault then
				-- so basically all this code does is check if the user changed anything about the reset times or if they are still set to the addon's default,
				-- if he touched something, we won't do anything, but if it's still set to the (erroneous) default,
				-- we update it now to the real daily and weekly reset times, that corresponds to the user's region (EU, US, etc...)

				local resetDate = utils:GetWeeklyResetDate()

				resetManager:UpdateTimeData(dailyTabID, dailyResetTimeTable, resetDate.hour, resetDate.min, resetDate.sec)
				resetManager:UpdateTimeData(weeklyTabID, weeklyResetTimeTable, resetDate.hour, resetDate.min, resetDate.sec)
				resetManager:UpdateResetDay(weeklyTabID, 4, false)
				resetManager:UpdateResetDay(weeklyTabID, resetDate.wday, true)
			end
		end)
	end
end

function private:ProfileNewVersion()
    -- // updates each profile saved variables once after an update

    -- by default after each update, we empty the undo table
    wipe(NysTDL.acedb.profile.undoTable)

    -- var version migration
    private:CheckVarsMigration()
end

-- // **************************** // --

function private:CheckVarsMigration()
    -- // VAR VERSIONS MIGRATION
    local success, errmsg = xpcall(private.ExecVarsMigration, core.errorhandler) -- xpcall(<err?>)
    if not success then -- oh boy
        private:Failed(errmsg, true)
    end
end

function private:ExecVarsMigration()
    for _,version in ipairs(migrationData.versions) do -- ORDERED
        private:TryToMigrate(version) -- <err?>
    end
end

function private:TryToMigrate(toVersion)
    -- this func will only call the right migrations, depending on the current and last version of the addon
    if utils:IsVersionOlderThan(NysTDL.acedb.profile.latestVersion, toVersion) then
        -- the safeguard, second part is at the start of each migration code (saving the data)
        migrationData.failed.version = toVersion

        --[[
            WARNING:
            here is the line where i call the migration code,
            it CAN in theory throw an error if an automatic migration failed.

            Of course, i'm always testing as much as i can the migration codes,
            but sometimes, since it's directly attacking the saved variables and the database,
            MAYBE some players will have specific lists or databases that are different than mine, or different than those that i tested,
            and those will crash the migration code, leading to a complete loss of data.
            (this happened to me once, so now i'm trying everything that i can to avoid the same scenario)

            The thing is that i can't test everything, and even though a crash should never happen,
            the fact that i can't retry the migration or know where it came from, it only leads in a scenario where the
            player will lose his data, or will try to un-update, which will do nothing good.
            ==> All of that means that my only chance to fix the problem, is to do something when the crash happens.

            And that's what i'm doing now, a whole system where IF the automatic migration failed,
            the data WON'T be lost (even though it's not usable by the list in this state).
            And with this data, i will create a new frame that will display it to the player,
            so that he can migrate manually the data.
        ]]
        migrationData.codes[toVersion]() -- <err?>

        NysTDL.acedb.profile.latestVersion = toVersion -- success, onto the next one
    end
end

-- // **************************** // --

-- / migration from 1.0+ to 2.0+
local ToDoListSV_transfert
migrationData.codes["2.0"] = function()

    -- (potential) saved variables in 1.0+ : ToDoListSV_checkedButtons, ToDoListSV_itemsList, ToDoListSV_autoReset, ToDoListSV_lastLoadedTab
    -- saved variables in 2.0+ : ToDoListSV
    if ToDoListSV_checkedButtons or ToDoListSV_itemsList or ToDoListSV_autoReset or ToDoListSV_lastLoadedTab then
        migrationData.failed.saved = {}
        migrationData.failed.saved.itemsList = utils:Deepcopy(ToDoListSV_itemsList)
        migrationData.failed.saved.checkedButtons = utils:Deepcopy(ToDoListSV_checkedButtons)

        -- // == start migration == // --

        ToDoListSV_transfert = {
            -- we only care about those two to be transfered to 6.0+
            itemsList = ToDoListSV_itemsList or { ["Daily"] = {}, ["Weekly"] = {} },
            checkedButtons = ToDoListSV_checkedButtons or {},
        }

        -- // bye bye
        ToDoListSV_checkedButtons = nil
        ToDoListSV_itemsList = nil
        ToDoListSV_autoReset = nil
        ToDoListSV_lastLoadedTab = nil
    end
end

-- / migration from 2.0+ to 4.0+
migrationData.codes["4.0"] = function()
    local profile = NysTDL.acedb.profile

    -- saved variables in 2.0+ : ToDoListSV
    -- saved variables in 4.0+ : NysToDoListDB (AceDB)
    if ToDoListSV or ToDoListSV_transfert then -- // double check
        ToDoListSV_transfert = ToDoListSV_transfert or ToDoListSV

        migrationData.failed.saved = {}
        migrationData.failed.saved.itemsList = utils:Deepcopy(ToDoListSV_transfert.itemsList)
        migrationData.failed.saved.checkedButtons = utils:Deepcopy(ToDoListSV_transfert.checkedButtons)

        -- // == start migration == // --

        -- again, only those two are useful
        profile.itemsList = utils:Deepcopy(ToDoListSV_transfert.itemsList) or { ["Daily"] = {}, ["Weekly"] = {} }
        profile.checkedButtons = utils:Deepcopy(ToDoListSV_transfert.checkedButtons) or {}

        -- // bye bye
        ToDoListSV = nil
        ToDoListSV_transfert = nil
    end
end

-- / migration from 4.0+ to 5.0+
migrationData.codes["5.0"] = function()
    local profile = NysTDL.acedb.profile

    -- this test may not be bulletproof, but it's the closest safeguard I could think of
    -- 5.5+ format
    local nextFormat = false -- // double check
    local catName = next(profile.itemsList) -- catName, itemNames
    if catName then
        local _, itemData = next(profile.itemsList[catName])
        if type(itemData) == "table" then
            nextFormat = true
        end
    end

    if profile.itemsList and (profile.itemsList["Daily"] and profile.itemsList["Weekly"]) and not nextFormat then -- // triple check

        migrationData.failed.saved = {}
        migrationData.failed.saved.itemsList = utils:Deepcopy(profile.itemsList)
        migrationData.failed.saved.checkedButtons = utils:Deepcopy(profile.checkedButtons)

        -- // == start migration == // --

        -- we only extract the daily and weekly tables to be on their own
        profile.itemsDaily = utils:Deepcopy(profile.itemsList["Daily"]) or {}
        profile.itemsWeekly = utils:Deepcopy(profile.itemsList["Weekly"]) or {}

        -- // bye bye
        profile.itemsList["Daily"] = nil
        profile.itemsList["Weekly"] = nil
    end
end

-- / migration from 5.0+ to 5.5+
migrationData.codes["5.5"] = function()
    local profile = NysTDL.acedb.profile

    -- every var here will be transfered INSIDE the items data
    if profile.itemsDaily or profile.itemsWeekly or profile.itemsFavorite or profile.itemsDesc or profile.checkedButtons then -- // double check

        migrationData.failed.saved = {}
        migrationData.failed.saved.itemsList = utils:Deepcopy(profile.itemsList)
        migrationData.failed.saved.checkedButtons = utils:Deepcopy(profile.checkedButtons)
        migrationData.failed.saved.itemsDaily = utils:Deepcopy(profile.itemsDaily)
        migrationData.failed.saved.itemsWeekly = utils:Deepcopy(profile.itemsWeekly)
        migrationData.failed.saved.itemsFavorite = utils:Deepcopy(profile.itemsFavorite)
        migrationData.failed.saved.itemsDesc = utils:Deepcopy(profile.itemsDesc)

        -- // == start migration == // --

        -- we need to change the saved variables to the new format
        local oldItemsList = utils:Deepcopy(profile.itemsList)
        profile.itemsList = {}

        for catName, itemNames in pairs(oldItemsList) do -- for every cat we had
            profile.itemsList[catName] = {}
            for _, itemName in pairs(itemNames) do -- and for every item we had
                -- first we get the previous data elements from the item

                -- / tabName
                -- no need for the locale here, I actually DID force-use the english names in my previous code,
                -- the shown names being the only ones different
                local tabName = enums.mainTabs.all
                if (utils:HasValue(profile.itemsDaily, itemName)) then
                    tabName = enums.mainTabs.daily
                elseif (utils:HasValue(profile.itemsWeekly, itemName)) then
                    tabName = enums.mainTabs.weekly
                end

                -- / checked
                local checked = utils:HasValue(profile.checkedButtons, itemName)

                -- / favorite
                local favorite = nil
                if (utils:HasValue(profile.itemsFavorite, itemName)) then
                    favorite = true
                end

                -- / description
                local description = nil
                if (utils:HasKey(profile.itemsDesc, itemName)) then
                    description = profile.itemsDesc[itemName]
                end

                -- then we replace it by the new var
                profile.itemsList[catName][itemName] = {
                    ["tabName"] = tabName,
                    ["checked"] = checked,
                    ["favorite"] = favorite,
                    ["description"] = description,
                }
            end
        end

        -- // bye bye
        profile.itemsDaily = nil
        profile.itemsWeekly = nil
        profile.itemsFavorite = nil
        profile.itemsDesc = nil
        profile.checkedButtons = nil
    end
end

-- / migration from 5.5+ to 6.0+
-- !! IMPORTANT !! profile.latestVersion was introduced in 5.6, so every migration from further on won't need double checks
migrationData.codes["6.0"] = function()
    local profile = NysTDL.acedb.profile
    migrationData.failed.saved = utils:Deepcopy(profile.itemsList)

    -- // == start migration == // --

    -- first we get the itemsList and delete it, so that we can start filling it correctly
    local itemsList = profile.itemsList -- saving it for use
    profile.itemsList = nil -- reset
    profile.itemsList = {}

    -- we get the necessary tab IDs
    local allTabID, allTabData, dailyTabID, dailyTabData, weeklyTabID, weeklyTabData
    for tabID,tabData in dataManager:ForEach(enums.tab, false) do
        if tabData.name == enums.mainTabs.all then
            allTabID, allTabData = tabID, tabData
        elseif tabData.name == enums.mainTabs.daily then
            dailyTabID, dailyTabData = tabID, tabData
        elseif tabData.name == enums.mainTabs.weekly then
            weeklyTabID, weeklyTabData = tabID, tabData
        end
    end

    -- // we recreate every cat, and every item
    local contentTabs = {}
    for catName,items in pairs(itemsList) do
        -- first things first, we do a loop to get every tab the cat is in (by checking the items data)
        wipe(contentTabs)
        for _,itemData in pairs(items) do
            if not utils:HasValue(contentTabs, itemData.tabName) then
                table.insert(contentTabs, itemData.tabName)
            end
        end

        -- then we add the cat to each of those found tabs
        local allCatID, dailyCatID, weeklyCatID
        for _,tabName in pairs(contentTabs) do
            local cID, tID
            if tabName == enums.mainTabs.all then
                allCatID = dataManager:CreateCategory(catName, allTabID)
                cID, tID = allCatID, allTabID
            elseif tabName == enums.mainTabs.daily then
                dailyCatID = dataManager:CreateCategory(catName, dailyTabID)
                cID, tID = dailyCatID, dailyTabID
            elseif tabName == enums.mainTabs.weekly then
                weeklyCatID = dataManager:CreateCategory(catName, weeklyTabID)
                cID, tID = weeklyCatID, weeklyTabID
            end

            -- was it closed?
            if profile.closedCategories and cID and tID then
                if utils:HasValue(profile.closedCategories[catName], tabName) then
                    dataManager:ToggleClosed(cID, tID, false)
                end
            end
        end

        for itemName,itemData in pairs(items) do -- for every item, again
            -- tab & cat
            local itemTabID, itemCatID
            if itemData.tabName == enums.mainTabs.all then
                itemTabID = allTabID
                itemCatID = allCatID
            elseif itemData.tabName == enums.mainTabs.daily then
                itemTabID = dailyTabID
                itemCatID = dailyCatID
            elseif itemData.tabName == enums.mainTabs.weekly then
                itemTabID = weeklyTabID
                itemCatID = weeklyCatID
            end

            -- / creation
            local itemID = dataManager:CreateItem(itemName, itemTabID, itemCatID)

            -- checked
            if itemData.checked then
                dataManager:ToggleChecked(itemID)
            end

            -- favorite
            if itemData.favorite then
                dataManager:ToggleFavorite(itemID)
            end

            -- description
            if itemData.description then
                dataManager:UpdateDescription(itemID, itemData.description)
            end
        end
    end

    -- // we also update the tabs in accordance with the tabs SV

    if profile.deleteAllTabItems then
        allTabData.deleteCheckedItems = true
        allTabData.hideCheckedItems = false
    end

    if profile.showOnlyAllTabItems then
        dataManager:UpdateShownTabID(allTabID, dailyTabID, false)
        dataManager:UpdateShownTabID(allTabID, weeklyTabID, false)
    end

    if profile.hideDailyTabItems then
        dailyTabData.hideCheckedItems = true
        dailyTabData.deleteCheckedItems = false
    end

    if profile.hideWeeklyTabItems then
        weeklyTabData.hideCheckedItems = true
        weeklyTabData.deleteCheckedItems = false
    end

    -- // bye bye
    profile.closedCategories = nil
    profile.lastLoadedTab = nil
    profile.weeklyDay = nil
    profile.dailyHour = nil
    profile.deleteAllTabItems = nil
    profile.showOnlyAllTabItems = nil
    profile.hideDailyTabItems = nil
    profile.hideWeeklyTabItems = nil
end

-- / future migrations... (I hope not :D)

-- // **************/ AUTOMATIC MIGRATION FAILED /************** // --

local recoveryList = {
    frame = nil,
    warningFrame = nil,
    tutoFrame = nil,
    tooltip = nil,
    content = nil, -- shortcut to recoveryList.frame.body.list
    copyBox = nil, -- shortcut to recoveryList.frame.footer.copyBox
    widgets = {},

    -- info
    width = 260,
    height = 320,
    topSize = 40,
    bottomSize = 60,
}

function private:CheckSaved()
    -- returns false if migrationData or migrationData.saved are empty
    return not (not next(NysTDL.acedb.profile.migrationData) or type(NysTDL.acedb.profile.migrationData.saved) ~= "table" or not next(NysTDL.acedb.profile.migrationData.saved))
end

function private:Failed(errmsg, original)
    if original then
        -- we save the fail data to the database so that we can keep it between sessions
        local migrationDataSV = NysTDL.acedb.profile.migrationData
        migrationDataSV.failed = true
        migrationDataSV.saved = migrationData.failed.saved
        migrationDataSV.version = migrationData.failed.version
        migrationDataSV.errmsg = errmsg
        migrationDataSV.warning = true

        -- and then, we reset once the list, the catList, and the tabs content, just so that we start with a clean state,
        -- this is in case the error created corrupted data (unusable/wrong/incomplete)
        NysTDL.acedb.profile.itemsList = {}
        NysTDL.acedb.profile.categoriesList = {}
        for _,tabData in dataManager:ForEach(enums.tab) do
            tabData.orderedCatIDs = {}
        end
    end

    private:CreateRecoveryList()
    private:CreateWarning()
    if NysTDL.acedb.profile.migrationData.warning then
        recoveryList.frame:Hide()
    else
        recoveryList.warningFrame:Hide()
    end

    if original then
        -- because I don't want the warning frame to be movable, and it needs to be mouse enabled,
        -- I reset the main frame's size and pos to the default values, just one time.

        -- size
        NysTDL.acedb.profile.frameSize.width = enums.tdlFrameDefaultWidth
        NysTDL.acedb.profile.frameSize.height = enums.tdlFrameDefaultHeight

        -- pos
        local points, _ = NysTDL.acedb.profile.framePos, nil
        points.point, _, points.relativePoint, points.xOffset, points.yOffset = "CENTER", nil, "CENTER", 0, 0

        -- we only need to update the saved vars, so that when the tdlFrame initializes, it uses them and updates accordingly.
    end
end

function private:CreateRecoveryList()
    if recoveryList.frame then
        recoveryList.frame:Hide()
        recoveryList.frame:ClearAllPoints()
    end

    -- we create the recovery frame
    recoveryList.frame = CreateFrame("Frame", "NysTDL_recoveryList", mainFrame.tdlFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    local frame = recoveryList.frame

	-- tuto
	tutorialsManager:SetPoint("migration", "explainFrame", "BOTTOM", frame, "TOP", 0, 20)

    -- background
    frame:SetBackdrop(enums.backdrop)
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:SetBackdropBorderColor(1, 1, 1, 1)

    -- properties
    frame:SetClampedToScreen(true)
    frame:SetFrameLevel(1000)
	frame:HookScript("OnUpdate", private.Event_recoveryFrame_OnUpdate)

    -- we resize the frame
    frame:SetSize(recoveryList.width, recoveryList.height)

    -- we reposition the frame
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", mainFrame.tdlFrame, "TOPRIGHT", 0, 0)

    -- // CREATING THE CONTENT OF THE FRAME // --

    --[[
        The frame is organised in 3 parts:
            - header    => the title
            - body      => the content (scroll frame & scroll bar & list)
            - footer    => the copy edit box
    ]]

    local linesTheme = database.themes.white
    frame.topLine = widgets:ThemeLine(frame, linesTheme, 0.7)
    frame.topLine:SetStartPoint("TOPLEFT", 3, -recoveryList.topSize+1) -- +lineThickness/2
    frame.topLine:SetEndPoint("TOPLEFT", recoveryList.width-3, -recoveryList.topSize+1)
    frame.bottomLine = widgets:ThemeLine(frame, linesTheme, 0.7)
    frame.bottomLine:SetStartPoint("BOTTOMLEFT", 3, recoveryList.bottomSize-1) -- -lineThickness/2
    frame.bottomLine:SetEndPoint("BOTTOMLEFT", recoveryList.width-3, recoveryList.bottomSize-1)

    -- // part 1: the header
    frame.header = CreateFrame("Frame", nil, frame)
    local header = frame.header

    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, -recoveryList.topSize)

    -- /-> title
    header.title = widgets:NoPointsLabel(header, nil, L["Recovery List"])
    header.title:SetPoint("TOP", header, "TOP", 0, -12)

    -- /-> clearButton
    header.clearButton = widgets:IconTooltipButton(header, "NysTDL_ClearButton", L["Clear everything"].."\n"..L["Only do this when you are done"].."!\n("..L["Double Right-Click"]..")")
    header.clearButton:SetPoint("RIGHT", header, "RIGHT", -10, 0)
    header.clearButton:SetSize(26, 26)
    header.clearButton:RegisterForClicks("RightButtonUp") -- only responds to right-clicks
    header.clearButton:SetScript("OnDoubleClick", function(self, button)
        if button == "RightButton" then
            if type(NysTDL.acedb.profile.migrationData) == "table" and type(NysTDL.acedb.profile.migrationData.saved) == "table" then
                wipe(NysTDL.acedb.profile.migrationData.saved)
                NysTDL.acedb.profile.migrationData.saved = nil
            end
            private:Refresh()
        end
    end)

    -- /-> warningButton
    header.warningButton = widgets:IconTooltipButton(header, "NysTDL_CopyButton", L["Reopen error message"])
    header.warningButton:SetNormalTexture("Interface\\CHATFRAME\\UI-ChatIcon-Chat-Up")
    header.warningButton:SetPushedTexture("Interface\\CHATFRAME\\UI-ChatIcon-Chat-Down")
    header.warningButton:SetPoint("LEFT", header, "LEFT", 10, 0)
    header.warningButton:SetSize(26, 26)
    header.warningButton:SetScript("OnClick", function()
        recoveryList.frame:Hide()
        recoveryList.warningFrame:Show()
        NysTDL.acedb.profile.migrationData.warning = true
    end)

    -- // part 2: the body
    frame.body = CreateFrame("Frame", nil, frame)
    local body = frame.body

    body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -recoveryList.topSize)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, recoveryList.bottomSize)

    -- /-> scroll frame
    body.ScrollFrame = CreateFrame("ScrollFrame", nil, body, "UIPanelScrollFrameTemplate")
    body.ScrollFrame:SetPoint("TOPLEFT", body, "TOPLEFT", 3, -1) -- exclusive
    body.ScrollFrame:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -3, 1) -- exclusive
    body.ScrollFrame:SetScript("OnMouseWheel", private.Event_ScrollFrame_OnMouseWheel)
    body.ScrollFrame:SetClipsChildren(true)

    -- /-> scroll bar
    body.ScrollFrame.ScrollBar:ClearAllPoints()
    body.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", body.ScrollFrame, "TOPRIGHT", - 18, - 18)
    body.ScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", body.ScrollFrame, "BOTTOMRIGHT", - 18, 17)

    -- /-> list
    -- creating the list, scroll child of ScrollFrame
    body.list = CreateFrame("Frame")
    body.list:SetSize(recoveryList.width-20, 1) -- y is determined by the elements inside of it
    body.ScrollFrame:SetScrollChild(body.list)
    recoveryList.content = body.list -- shortcut

    -- // part 3: the copy edit box
    frame.footer = CreateFrame("Frame", nil, frame)
    local footer = frame.footer

    footer:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, recoveryList.bottomSize)
    footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    -- /-> copy edit box
    footer.copyBox = CreateFrame("ScrollFrame", nil, frame, "NysTDL_InputScrollFrameTemplate")
    footer.copyBox:SetPoint("TOPLEFT", footer, "TOPLEFT", 10, -10)
    footer.copyBox:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -10, 10)
    footer.copyBox.EditBox:SetFontObject("ChatFontNormal")
    footer.copyBox.EditBox:SetAutoFocus(false)
	footer.copyBox.ScrollBar.Forward:ClearAllPoints()
	footer.copyBox.ScrollBar.Forward:SetPoint("BOTTOMRIGHT", footer.copyBox, "BOTTOMRIGHT", -1, 0)

    -- /--> char count
    footer.copyBox.EditBox:SetMaxLetters(enums.maxDescriptionCharCount)
    footer.copyBox.CharCount:Hide() -- TDLATER polish

    -- /--> hint
    footer.copyBox.EditBox.Instructions:SetFontObject("GameFontNormal")
    footer.copyBox.EditBox.Instructions:SetText(L["Ctrl+C"].."...")

    -- /--> scripts
    footer:SetScript("OnUpdate", function() -- don't ask me why
        footer.copyBox.EditBox:SetWidth(footer.copyBox:GetWidth() - 25)
        -- footer.copyBox.ScrollBar:Hide()
		footer.copyBox.ScrollBar.Back:Hide()
		footer.copyBox.ScrollBar.Track.Thumb:Hide()
    end)
    widgets:SetHyperlinksEnabled(footer.copyBox.EditBox, true)
    recoveryList.copyBox = footer.copyBox.EditBox -- shortcut

    -- /-> copy btn (select all btn)
    footer.copyBtn = widgets:IconTooltipButton(footer, "NysTDL_CopyButton", L["Ctrl+A"])
    footer.copyBtn:SetSize(30, 30)
    footer.copyBtn:SetPoint("TOPRIGHT", footer, "TOPRIGHT", -5, -6)
    footer.copyBtn:SetScript("OnClick", function()
        widgets:SetFocusEditBox(recoveryList.copyBox, true)
    end)

    -- // finishing: displaying the data to manually migrate
    private:Refresh(NysTDL.acedb.profile.migrationData.version) -- migrationData.failed.codes call
end

function private:Event_ScrollFrame_OnMouseWheel(delta)
    -- defines how fast we can scroll through the frame
    local ScrollFrame, speed = self, 20

    local newValue = ScrollFrame:GetVerticalScroll() - (delta * speed)

    if newValue < 0 then
        newValue = 0
    elseif newValue > ScrollFrame:GetVerticalScrollRange() then
        newValue = ScrollFrame:GetVerticalScrollRange()
    end

    ScrollFrame:SetVerticalScroll(newValue)
end

function private:Event_recoveryFrame_OnUpdate()
	if not next(NysTDL.acedb.profile.migrationData) then
        recoveryList.frame:Hide()
        recoveryList.frame:ClearAllPoints()
        return
	end
end

function private:CreateWarning()
    if recoveryList.warningFrame then
        recoveryList.warningFrame:Hide()
        recoveryList.warningFrame:ClearAllPoints()
    end

    -- we create the recovery frame
    recoveryList.warningFrame = CreateFrame("Frame", "NysTDL_recoveryList_warningFrame", mainFrame.tdlFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    local frame = recoveryList.warningFrame

    -- background
    frame:SetBackdrop(enums.backdrop)
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:SetBackdropBorderColor(1, 1, 1, 1)

    -- properties
    frame:SetClampedToScreen(true)
    frame:SetFrameLevel(1000)
    frame:EnableMouse(true)

    -- we resize the frame
    frame:SetSize(enums.tdlFrameDefaultWidth, enums.tdlFrameDefaultHeight)

    -- we reposition the frame
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", mainFrame.tdlFrame, "TOPLEFT", 0, 0)

    -- // CREATING THE CONTENT OF THE FRAME // --

    local msgWidth = 280

    -- /-> close button
    frame.closeButton = CreateFrame("Button", nil, frame, "NysTDL_CloseButton")
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.closeButton:SetScript("onClick", function() mainFrame.tdlFrame:Hide() end)

    -- /-> scroll frame
    frame.ScrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.ScrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
    frame.ScrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
    frame.ScrollFrame:SetScript("OnMouseWheel", private.Event_ScrollFrame_OnMouseWheel)
    frame.ScrollFrame:SetClipsChildren(true)

    -- /-> scroll bar
    frame.ScrollFrame.ScrollBar:ClearAllPoints()
    frame.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", frame.ScrollFrame, "TOPRIGHT", - 16, - 36)
    frame.ScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", frame.ScrollFrame, "BOTTOMRIGHT", - 16, 16)

    -- /-> content
    frame.content = CreateFrame("Frame")
    frame.content:SetPoint("TOPLEFT", frame.ScrollFrame, "TOPLEFT")
    frame.content:SetWidth(frame:GetWidth()-30)
    frame.ScrollFrame:SetScrollChild(frame.content)
    local content = frame.content

    content:SetAllPoints(frame)

    -- /-> title
    local titlePos = -20
    content.title = widgets:NoPointsLabel(content, nil, utils:ColorText(database.themes.red, L["Warning"]:upper()))
    content.title:SetPoint("TOP", content, "TOP", 0, titlePos)

    -- /-> sorryMsg
    local sorryMsgPos = titlePos - 30
    content.sorryMsg = widgets:NoPointsLabel(content, nil, L["An unexpected error was detected during the addon update, you will have to manually add your items back using the recovery list"])
    content.sorryMsg:SetPoint("TOP", content, "TOP", 0, sorryMsgPos)
    content.sorryMsg:SetWidth(msgWidth)

    -- /-> doNotMsg
    local doNotMsgPos = sorryMsgPos - content.sorryMsg:GetHeight() - 15
    content.doNotMsg = widgets:NoPointsLabel(content, nil, utils:ColorText(database.themes.yellow, L["Don't go back to the last version, it won't solve the problem"]))
    content.doNotMsg:SetPoint("TOP", content, "TOP", 0, doNotMsgPos)
    content.doNotMsg:SetWidth(msgWidth)

    -- /-> errMsg
    local errMsgPos = doNotMsgPos - content.doNotMsg:GetHeight() - 15
    content.errMsg = widgets:NoPointsLabel(content, nil, L["Please copy and post this error message as an issue on GitHub so that I can fix this problem as quickly as possible"]..":")
    content.errMsg:SetPoint("TOP", content, "TOP", 0, errMsgPos)
    content.errMsg:SetWidth(msgWidth)

    -- /-> errMsgField
    local errMsgFieldPos = errMsgPos - content.errMsg:GetHeight() - 8
    content.errMsgField = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    content.errMsgField:SetSize(200, 32)
    content.errMsgField:SetFontObject("GameFontHighlightLarge")
    content.errMsgField:SetAutoFocus(false)
    content.errMsgField:SetPoint("TOP", content, "TOP", -25, errMsgFieldPos)

    -- /-> errMsgCopyBtn (select all btn)
    content.errMsgCopyBtn = widgets:IconTooltipButton(content, "NysTDL_CopyButton", L["Ctrl+A"])
    content.errMsgCopyBtn:SetSize(32, 32)
    content.errMsgCopyBtn:SetPoint("LEFT", content.errMsgField, "RIGHT", 2, 0)
    content.errMsgCopyBtn:SetScript("OnClick", function()
        widgets:SetFocusEditBox(content.errMsgField, true)
    end)

    -- /-> errMsgResetBtn
    content.errMsgResetBtn = widgets:IconTooltipButton(content, "NysTDL_UndoButton", L["Reset"])
    content.errMsgResetBtn:SetSize(32, 32)
    content.errMsgResetBtn:SetPoint("LEFT", content.errMsgCopyBtn, "RIGHT", -2, 0)
    content.errMsgResetBtn:SetScript("OnClick", function()
        content.errMsgField:SetText(NysTDL.acedb.profile.migrationData.errmsg or "")
        content.errMsgField:SetCursorPosition(0)
        content.errMsgCopyBtn:GetScript("OnClick")()
    end)

    -- /--> init errMsgField
    content.errMsgResetBtn:GetScript("OnClick")()
    content.errMsgField:HighlightText(0, 0)

    -- /-> openListBtn
    local openListBtnPos = errMsgFieldPos - 50
    content.openListBtn = widgets:Button(nil, content, L["Open Recovery List"])
    content.openListBtn:SetPoint("TOP", content, "TOP", 0, openListBtnPos)
    content.openListBtn:SetScript("OnClick", function()
        frame:Hide()
        recoveryList.frame:Show()
        NysTDL.acedb.profile.migrationData.warning = false
    end)

    frame.content:SetHeight(-openListBtnPos + content.openListBtn:GetHeight() + 25)
    frame.ScrollFrame:SetVerticalScroll(1) -- this fixes a positionning bug
    frame.ScrollFrame:SetVerticalScroll(0)
end

-- // **************************** // --

local currentY, deltaY, deltaX

function private:Refresh(version)
    -- first we clear everything
    for _,frame in ipairs(recoveryList.widgets) do
        frame:Hide()
        frame:ClearAllPoints()
    end
    wipe(recoveryList.widgets)
    currentY, deltaY, deltaX = 16, 20, 10

	if not recoveryList.frame then
		return
	end

    -- then we repopulate (if there are things to show)

    if not private:CheckSaved() then -- if there are no items left to migrate
        -- we're done, so we clear every migration data
        wipe(NysTDL.acedb.profile.migrationData)

        -- and we hide the recovery list once and for all
        recoveryList.frame:Hide()
        recoveryList.frame:ClearAllPoints()
        return
    end

    if not version then
        return
    end

    migrationData.failed.codes[version]()

    -- and finally, this is just to add a space after the last item, just so it looks nice
    local itemWidget = CreateFrame("Frame", nil, recoveryList.content, nil)
    itemWidget:SetSize(1, 1) -- so that its children are visible

    local spaceLabel = itemWidget:CreateFontString(nil)
    spaceLabel:SetFontObject("GameFontHighlightLarge")
    spaceLabel:SetText(" ")
    spaceLabel:ClearAllPoints()
    spaceLabel:SetPoint("LEFT", itemWidget, "LEFT", 0, 0)

    itemWidget:ClearAllPoints()
    local point, _, relativePoint, ofsx, ofsy = recoveryList.widgets[#recoveryList.widgets]:GetPoint()
    itemWidget:SetPoint(point, itemWidget:GetParent(), relativePoint, ofsx, ofsy - 10)
    itemWidget:Show()
    table.insert(recoveryList.widgets, itemWidget)
end

function private:NewCategoryWidget(catName)
    local categoryWidget = CreateFrame("Frame", nil, recoveryList.content, nil)
    categoryWidget:SetSize(1, 1) -- so that its children are visible

    -- / label
    categoryWidget.label = CreateFrame("Button", nil, categoryWidget, "NysTDL_CustomListButton")
	categoryWidget.label.Highlight:SetDesaturated(true)
	categoryWidget.label:SetNormalFontObject("GameFontHighlightLarge")
	categoryWidget.label:SetText(catName)
	categoryWidget.label:SetSize(widgets:GetWidth(catName, "GameFontHighlightLarge"), 15)
	categoryWidget.label:SetScript("OnClick", function(self)
        recoveryList.copyBox:SetText(self:GetText())
        widgets:SetFocusEditBox(recoveryList.copyBox, true)
	end)
    categoryWidget.label:HookScript("OnEnter", function(self)
        local i = self:GetParent().i
        local allTab, dailyTab, weeklyTab = i.allTab, i.dailyTab, i.weeklyTab -- those are set dynamically

        -- <!> tooltip content <!>

        local tabName, last = nil, false
        if allTab then
            tabName = L["All"]
            last = true
        end
        if dailyTab then
            if last then
                tabName = tabName .. ", " .. L["Daily"]
            else
                tabName = L["Daily"]
            end
            last = true
        end
        if weeklyTab then
            if last then
                tabName = tabName .. ", " .. L["Weekly"]
            else
                tabName = L["Weekly"]
            end
        end

        recoveryList.tooltip = widgets:AcquireTooltip("NysTDL_Tooltip_RecoveryList", self)

		local customFont = CreateFont("NysTDL_Font_TooltipHeader")
		customFont:CopyFontObject("GameTooltipHeaderText")
		customFont:SetTextColor(unpack(utils:ThemeDownTo01(database.themes.theme_yellow)))
		recoveryList.tooltip:SetFont(customFont)

		recoveryList.tooltip:AddLine(L["Tab"]..": " .. (type(tabName) == "string" and tabName or "--"))
    end)
    categoryWidget.label:HookScript("OnLeave", function(self)
        LibQTip:Release(recoveryList.tooltip)
        recoveryList.tooltip = nil
    end)
    categoryWidget.label:ClearAllPoints()
    categoryWidget.label:SetPoint("LEFT", categoryWidget, "LEFT", 0, 0)

    categoryWidget.i = {} -- free space

    -- /-> position
    categoryWidget:ClearAllPoints()
    categoryWidget:SetPoint("TOPLEFT", categoryWidget:GetParent(), "TOPLEFT", deltaX, -currentY)
    table.insert(recoveryList.widgets, categoryWidget)
    currentY = currentY + deltaY

    return categoryWidget
end

function private:NewItemWidget(itemName, removeBtnFunc)

    local itemWidget = CreateFrame("Frame", nil, recoveryList.content, nil)
    itemWidget:SetSize(1, 1) -- so that its children are visible

    -- / label
    itemWidget.label = CreateFrame("Button", nil, itemWidget, "NysTDL_CustomListButton")
	itemWidget.label:SetText(itemName)
	itemWidget.label:SetSize(widgets:GetWidth(itemName, "GameFontNormalSmall"), 15)
	itemWidget.label:SetScript("OnClick", function(self)
        recoveryList.copyBox:SetText(self:GetText())
        widgets:SetFocusEditBox(recoveryList.copyBox, true)
	end)
    itemWidget.label:ClearAllPoints()
    itemWidget.label:SetPoint("LEFT", itemWidget, "LEFT", 36, 0)

    -- / removeBtn
    itemWidget.removeBtn = widgets:ValidButton(itemWidget)
    itemWidget.removeBtn:SetPoint("LEFT", itemWidget, "LEFT", 0, -1)
    itemWidget.removeBtn:HookScript("OnClick", removeBtnFunc)

    -- / infoBtn
    itemWidget.infoBtn = widgets:HelpButton(itemWidget)
    itemWidget.infoBtn:SetPoint("LEFT", itemWidget, "LEFT", 24, -1)
    itemWidget.infoBtn:SetScale(0.6)
    itemWidget.infoBtn:HookScript("OnClick", function(self)
        recoveryList.copyBox:SetText(self:GetParent().i.description or ("<"..L["No description"]..">"))
        widgets:SetFocusEditBox(recoveryList.copyBox, true)
    end)
    itemWidget.infoBtn:HookScript("OnEnter", function(self)
        local i = self:GetParent().i
        local tabName, checked, favorite, description = i.tabName, i.checked, i.favorite, i.description -- those are set dynamically

        -- <!> tooltip content <!>

        recoveryList.tooltip = widgets:AcquireTooltip("NysTDL_Tooltip_RecoveryList", self)

		local customFont = CreateFont("NysTDL_Font_TooltipHeader")
		customFont:CopyFontObject("GameTooltipHeaderText")
		customFont:SetTextColor(unpack(utils:ThemeDownTo01(database.themes.theme_yellow)))
		recoveryList.tooltip:SetFont(customFont)

        tabName = L[tabName]
		recoveryList.tooltip:AddLine(L["Tab"]..": " .. (type(tabName) == "string" and tabName or "--"))

		recoveryList.tooltip:SetFont("GameTooltipText")

        if checked then
            recoveryList.tooltip:AddLine(L["Checked"]..": "..tostring(YES))
        end
        if favorite then
            recoveryList.tooltip:AddLine(L["Favorite"]..": "..tostring(YES))
        end
        if description then
            recoveryList.tooltip:AddLine(L["Description"]..": "..L["Click to copy"])
        end
    end)
    itemWidget.infoBtn:HookScript("OnLeave", function(self)
        LibQTip:Release(recoveryList.tooltip)
        recoveryList.tooltip = nil
    end)

    -- /-> position
	itemWidget:ClearAllPoints()
	itemWidget:SetPoint("TOPLEFT", itemWidget:GetParent(), "TOPLEFT", deltaX*2, -currentY)
	table.insert(recoveryList.widgets, itemWidget)
	currentY = currentY + deltaY

    itemWidget.i = {} -- free space

    return itemWidget
end

-- // **************************** // --

-- / migration failed from 1.0+ to 2.0+
migrationData.failed.codes["2.0"] = function()
    local removeBtnFunc = function(self)
        if not private:CheckSaved() then
            private:Refresh()
            return
        end

        -- ===================== --

        local catName, itemName = self:GetParent().i.catName, self:GetParent().i.itemName
        local list = NysTDL.acedb.profile.migrationData.saved.itemsList

        if list[catName] then
            table.remove(list[catName], (select(2, utils:HasValue(list[catName], itemName))))
            if not next(list[catName]) then
                list[catName] = nil
            end
        end

        local finished = true
        for catName in pairs(list) do
            if catName ~= "Daily" and catName ~= "Weekly" then
                finished = false
                break
            end
        end

        if finished then
            NysTDL.acedb.profile.migrationData.saved = nil
        end

        -- ===================== --

        private:Refresh(NysTDL.acedb.profile.migrationData.version)
    end

    local saved = NysTDL.acedb.profile.migrationData.saved
    for catName,items in pairs(saved.itemsList) do
        if catName ~= "Daily" and catName ~= "Weekly" then -- oh yea

            -- == cat == --
            local catWidget = private:NewCategoryWidget(catName)
            -- ========= --

            for _,itemName in ipairs(items) do

                -- == item == --
                local itemWidget = private:NewItemWidget(itemName, removeBtnFunc)
                itemWidget.i.catName = catName
                itemWidget.i.itemName = itemName

                -- custom data
                if utils:HasValue(saved.itemsList["Daily"], itemName) then
                    itemWidget.i.tabName = "Daily"
                elseif utils:HasValue(saved.itemsList["Weekly"], itemName) then
                    itemWidget.i.tabName = "Weekly"
                else
                    itemWidget.i.tabName = "All"
                end
                itemWidget.i.checked = utils:HasValue(saved.checkedButtons, itemName)

                if itemWidget.i.tabName == "All" then
                    catWidget.i.allTab = true
                elseif itemWidget.i.tabName == "Daily" then
                    catWidget.i.dailyTab = true
                elseif itemWidget.i.tabName == "Weekly" then
                    catWidget.i.weeklyTab = true
                end
                -- ========== --

            end

        end
    end
end

-- / migration failed from 2.0+ to 4.0+
migrationData.failed.codes["4.0"] = function()
    migrationData.failed.codes["2.0"]() -- pretty much the same thing, though the saved is populated differently in the migrationData.codes["4.0"]
end

-- / migration failed from 4.0+ to 5.0+
migrationData.failed.codes["5.0"] = function()
    migrationData.failed.codes["4.0"]() -- again, same thing
end

-- / migration failed from 5.0+ to 5.5+
migrationData.failed.codes["5.5"] = function()
    local removeBtnFunc = function(self)
        if not private:CheckSaved() then
            private:Refresh()
            return
        end

        -- ===================== --

        local catName, itemName = self:GetParent().i.catName, self:GetParent().i.itemName
        local list = NysTDL.acedb.profile.migrationData.saved.itemsList

        if list[catName] then
            table.remove(list[catName], (select(2, utils:HasValue(list[catName], itemName))))
            if not next(list[catName]) then
                list[catName] = nil
            end
        end

        if not next(list) then
            NysTDL.acedb.profile.migrationData.saved = nil
        end

        -- ===================== --

        private:Refresh(NysTDL.acedb.profile.migrationData.version)
    end

    local saved = NysTDL.acedb.profile.migrationData.saved
    for catName,items in pairs(saved.itemsList) do

        -- == cat == --
        local catWidget = private:NewCategoryWidget(catName)
        -- ========= --

        for _,itemName in ipairs(items) do

            -- == item == --
            local itemWidget = private:NewItemWidget(itemName, removeBtnFunc)
            itemWidget.i.catName = catName
            itemWidget.i.itemName = itemName

            -- custom data
            if utils:HasValue(saved.itemsDaily, itemName) then
                itemWidget.i.tabName = "Daily"
            elseif utils:HasValue(saved.itemsWeekly, itemName) then
                itemWidget.i.tabName = "Weekly"
            else
                itemWidget.i.tabName = "All"
            end
            itemWidget.i.checked = utils:HasValue(saved.checkedButtons, itemName)
            itemWidget.i.favorite = utils:HasValue(saved.itemsFavorite, itemName)
            itemWidget.i.description = type(saved.itemsDesc) == "table" and saved.itemsDesc[itemName] or nil

            if itemWidget.i.tabName == "All" then
                catWidget.i.allTab = true
            elseif itemWidget.i.tabName == "Daily" then
                catWidget.i.dailyTab = true
            elseif itemWidget.i.tabName == "Weekly" then
                catWidget.i.weeklyTab = true
            end
            -- ========== --

        end

    end
end

-- / migration failed from 5.5+ to 6.0+
migrationData.failed.codes["6.0"] = function()
    local removeBtnFunc = function(self)
        if not private:CheckSaved() then
            private:Refresh()
            return
        end

        -- ===================== --

        local catName, itemName = self:GetParent().i.catName, self:GetParent().i.itemName
        local list = NysTDL.acedb.profile.migrationData.saved

        if list[catName] then
            list[catName][itemName] = nil
            if not next(list[catName]) then
                list[catName] = nil
            end
        end

        -- ===================== --

        private:Refresh(NysTDL.acedb.profile.migrationData.version)
    end

    for catName,items in pairs(NysTDL.acedb.profile.migrationData.saved) do -- categories

        -- == cat == --
        local catWidget = private:NewCategoryWidget(catName)
        -- ========= --

        for itemName,itemData in pairs(items) do -- items

            -- == item == --
            local itemWidget = private:NewItemWidget(itemName, removeBtnFunc)
            itemWidget.i.catName = catName
            itemWidget.i.itemName = itemName
            if type(itemData) == "table" then -- custom data
                itemWidget.i.tabName = itemData.tabName
                itemWidget.i.checked = itemData.checked
                itemWidget.i.favorite = itemData.favorite
                itemWidget.i.description = itemData.description

                if itemWidget.i.tabName == "All" then
                    catWidget.i.allTab = true
                elseif itemWidget.i.tabName == "Daily" then
                    catWidget.i.dailyTab = true
                elseif itemWidget.i.tabName == "Weekly" then
                    catWidget.i.weeklyTab = true
                end
            end
            -- ========== --

        end
    end
end

--@do-not-package@

-- // **************************** // --

function migration:TestFunc()
    local migrationDataSV = NysTDL.acedb.profile.migrationData
	table.wipe(migrationDataSV)

    migrationDataSV.failed = true
    migrationDataSV.saved = {["Cat1"] = {["Item1"] = {["tabName"] = "Daily", ["favorite"] = true, ["description"] = "Hi there"}}}
    migrationDataSV.version = "6.0"
    migrationDataSV.errmsg = "Custom"
    migrationDataSV.warning = false

    if IsAltKeyDown() then
		tutorialsManager:ResetTuto("migration")
	end

    private:Failed(nil, false)
end

--@end-do-not-package@
