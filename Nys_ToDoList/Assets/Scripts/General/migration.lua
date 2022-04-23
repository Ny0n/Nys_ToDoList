-- Namespaces
local _, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local enums = addonTable.enums
local utils = addonTable.utils
local migration = addonTable.migration
local dataManager = addonTable.dataManager

-- Variables
local L = core.L

-- // **************************** // --

local private = {}

local migrationData = {
    versions = {
        "2.0",
        "4.0",
        "5.0",
        "5.5",
        "6.0"
    },
    codes = {}, -- defined at the end of the file
    failed = {
        savedItemsList = {},
        version = "",
    },
}

function private:InitMigrationFrame()

end

-- // **************************** // --

function migration:Migrate()
    -- this is for doing specific things ONLY when the addon gets updated and its version changes

    -- checking for an addon update, globally
    if NysTDL.db.global.latestVersion ~= core.toc.version then
        private:GlobalNewVersion()
        NysTDL.db.global.latestVersion = core.toc.version
        NysTDL.db.global.addonUpdated = true
    end

    -- checking for an addon update, for the profile that was just loaded
    if NysTDL.db.profile.latestVersion ~= core.toc.version then
        private:ProfileNewVersion()
        NysTDL.db.profile.latestVersion = core.toc.version
    end
end

-- // **************************** // --

-- these two functions are called only once, each time there is an addon update
function private:GlobalNewVersion() -- global
    -- // updates the global saved variables once after an update

    if utils:IsVersionOlderThan(NysTDL.db.global.latestVersion, "6.0") then -- if we come from before 6.0
        if NysTDL.db.global.tuto_progression > 5 then -- if we already completed the tutorial
            -- we go to the new part of the edit mode button
            NysTDL.db.global.tuto_progression = 5
        end
    end
end

function private:ProfileNewVersion() -- profile
    -- // updates each profile saved variables once after an update

    -- by default after each update, we empty the undo table
    wipe(NysTDL.db.profile.undoTable)

    -- var version migration
    local success, errmsg = pcall(private.CheckVarsMigration) -- pcall(<err>)
    if not success then -- oh boy
        private:Failed(errmsg)
    end
end

-- // **************************** // --

function private:CheckVarsMigration()
    -- // VAR VERSIONS MIGRATION
    for _,version in ipairs(migrationData.versions) do -- ORDERED
        private:TryToMigrate(version) -- <err>
    end
end

function private:TryToMigrate(toVersion)
    -- this func will only call the right migrations, depending on the current and last version of the addon
    if utils:IsVersionOlderThan(NysTDL.db.profile.latestVersion, toVersion) then
        -- the safeguard
        migrationData.failed.savedItemsList = utils:Deepcopy(NysTDL.db.profile.itemsList)
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
        migrationData.codes[toVersion]() -- <err>

        NysTDL.db.profile.latestVersion = toVersion -- success, onto the next one
    end
end

-- // **************************** // --

-- / migration from 1.0+ to 2.0+
local ToDoListSV_transfert
migrationData.codes["2.0"] = function()
        -- (potential) saved variables in 1.0+ : ToDoListSV_checkedButtons, ToDoListSV_itemsList, ToDoListSV_autoReset, ToDoListSV_lastLoadedTab
        -- saved variables in 2.0+ : ToDoListSV
        if ToDoListSV_checkedButtons or ToDoListSV_itemsList or ToDoListSV_autoReset or ToDoListSV_lastLoadedTab then
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
    local profile = NysTDL.db.profile

    -- saved variables in 2.0+ : ToDoListSV
    -- saved variables in 4.0+ : NysToDoListDB (AceDB)
    if ToDoListSV or ToDoListSV_transfert then -- // double check
        ToDoListSV_transfert = ToDoListSV_transfert or ToDoListSV
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
    local profile = NysTDL.db.profile

    -- this test may not be bulletproof, but it's the closest safeguard i could think of
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
    local profile = NysTDL.db.profile

    -- every var here will be transfered INSIDE the items data
    if profile.itemsDaily or profile.itemsWeekly or profile.itemsFavorite or profile.itemsDesc or profile.checkedButtons then -- // double check
        -- we need to change the saved variables to the new format
        local oldItemsList = utils:Deepcopy(profile.itemsList)
        profile.itemsList = {}

        for catName, itemNames in pairs(oldItemsList) do -- for every cat we had
            profile.itemsList[catName] = {}
            for _, itemName in pairs(itemNames) do -- and for every item we had
                -- first we get the previous data elements from the item

                -- / tabName
                -- no need for the locale here, i actually DID force-use the english names in my previous code,
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
    local profile = NysTDL.db.profile

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

function private:Failed(errmsg)
    
end