-- Namespaces
local _, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local enums = addonTable.enums
local utils = addonTable.utils
local widgets = addonTable.widgets
local migration = addonTable.migration
local mainFrame = addonTable.mainFrame
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
    codes = {}, -- defined later in the file
    failed = {
        savedItemsList = {},
        version = "",
        codes = {}, -- defined later in the file
    },
}

function private:InitMigrationFrame()

end

-- // **************************** // --

function migration:Migrate()
    -- this is for doing specific things ONLY when the addon gets updated and its version changes

    if NysTDL.db.profile.migrationData.failed then
        private:Failed()
    end

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
        private:Failed(errmsg, true)
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
        print("SAFEGUARD -- " .. toVersion)
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

        error()

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

local migrationFrame
local migrationFrameWidgets = {}

function private:Failed(errmsg, original)
    if original then
        print("ORIGINAL")
        local migrationDataSV = NysTDL.db.profile.migrationData
        migrationDataSV.failed = true
        migrationDataSV.savedItemsList = migrationData.failed.savedItemsList
        print(#migrationDataSV.savedItemsList)
        migrationDataSV.version = migrationData.failed.version
        migrationDataSV.errmsg = errmsg
        NysTDL.db.profile.itemsList = {}
    end

    private:CreateMigrationFrame()
end

function private:CreateMigrationFrame()
    if migrationFrame then
        migrationFrame:Hide()
        migrationFrame:ClearAllPoints()
    end

    -- we create the migration frame
    migrationFrame = CreateFrame("Frame", nil, mainFrame.tdlFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)

    -- background
    migrationFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, tileSize = 1, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })

    migrationFrame:SetBackdropColor(0, 0, 0, 1)
    migrationFrame:SetBackdropBorderColor(1, 1, 1, 1)

    -- properties
    migrationFrame:SetClampedToScreen(true)
    migrationFrame:SetFrameStrata("LOW")

    -- we resize the frame
    migrationFrame:SetSize(260, 300)

    -- we reposition the frame
    migrationFrame:ClearAllPoints()
    migrationFrame:SetPoint("TOPLEFT", mainFrame.tdlFrame, "TOPRIGHT", 0, 0)

    -- // CREATING THE CONTENT OF THE FRAME // --

    -- // scroll frame (almost everything will be inside of it using a scroll child frame, see generateFrameContent())

    migrationFrame.ScrollFrame = CreateFrame("ScrollFrame", nil, migrationFrame, "UIPanelScrollFrameTemplate")
    migrationFrame.ScrollFrame:SetPoint("TOPLEFT", migrationFrame, "TOPLEFT", 4, - 4)
    migrationFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", migrationFrame, "BOTTOMRIGHT", - 4, 4)
    migrationFrame.ScrollFrame:SetScript("OnMouseWheel", private.Event_ScrollFrame_OnMouseWheel)
    migrationFrame.ScrollFrame:SetClipsChildren(true)

    -- // outside the scroll frame

    -- scroll bar
    migrationFrame.ScrollFrame.ScrollBar:ClearAllPoints()
    migrationFrame.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", migrationFrame.ScrollFrame, "TOPRIGHT", - 16, - 17)
    migrationFrame.ScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", migrationFrame.ScrollFrame, "BOTTOMRIGHT", - 16, 16)

    -- creating the content, scroll child of ScrollFrame (everything will be inside of it)
    migrationFrame.content = CreateFrame("Frame", nil, migrationFrame.ScrollFrame)
    migrationFrame.content:SetSize(enums.tdlFrameDefaultWidth, 1) -- y is determined by the elements inside of it
    migrationFrame.ScrollFrame:SetScrollChild(migrationFrame.content)

    -- displaying the data to manually migrate
    private:Refresh(NysTDL.db.profile.migrationData.version) -- migrationData.failed.codes call
end

function private:Event_ScrollFrame_OnMouseWheel(delta)
    -- defines how fast we can scroll throught the frame
    local newValue = migrationFrame.ScrollFrame:GetVerticalScroll() - (delta * 20)

    if newValue < 0 then
        newValue = 0
    elseif newValue > migrationFrame.ScrollFrame:GetVerticalScrollRange() then
        newValue = migrationFrame.ScrollFrame:GetVerticalScrollRange()
    end

    migrationFrame.ScrollFrame:SetVerticalScroll(newValue)
end

-- // **************************** // --

local function CreateCategoryWidget(catName)
    local categoryWidget = CreateFrame("Frame", nil, migrationFrame.content, nil)
    categoryWidget:SetSize(1, 1) -- so that its children are visible

    -- / label
    categoryWidget.label = widgets:NoPointsLabel(categoryWidget, nil, catName)
    categoryWidget.label:ClearAllPoints()
    categoryWidget.label:SetPoint("LEFT", categoryWidget, "LEFT", 0, 0)

    -- -- / removeBtn
    -- categoryWidget.removeBtn = widgets:RemoveButton(categoryWidget, categoryWidget)
    -- categoryWidget.removeBtn:SetPoint("LEFT", categoryWidget, "LEFT", 0, -1)
    -- categoryWidget.removeBtn:SetScript("OnClick", function() -- todo put in migration failed code, not here bc diff for everyone
    --     NysTDL.db.profile.migrationData.savedItemsList
    --     private:Refresh(NysTDL.db.profile.migrationData.version)
    -- end)

    return categoryWidget
end

local function CreateItemWidget(itemName, itemData, catName) -- todo same for cat name ? ^
    local itemWidget = CreateFrame("Frame", nil, migrationFrame.content, nil)
    itemWidget:SetSize(1, 1) -- so that its children are visible

    -- / label
    itemWidget.label = widgets:NoPointsLabel(itemWidget, nil, itemName, "GameFontNormal")
    itemWidget.label:ClearAllPoints()
    itemWidget.label:SetPoint("LEFT", itemWidget, "LEFT", 18, 0)

    -- / removeBtn
    itemWidget.removeBtn = widgets:RemoveButton(itemWidget, itemWidget)
    itemWidget.removeBtn:SetPoint("LEFT", itemWidget, "LEFT", 0, -1)
    itemWidget.removeBtn:SetScript("OnClick", function()
        if NysTDL.db.profile.migrationData.savedItemsList[catName] then
            NysTDL.db.profile.migrationData.savedItemsList[catName][itemName] = nil
            if not next(NysTDL.db.profile.migrationData.savedItemsList[catName]) then
                NysTDL.db.profile.migrationData.savedItemsList[catName] = nil
            end
        end
        private:Refresh(NysTDL.db.profile.migrationData.version)
    end)

    -- -- / infoBtn
    -- itemWidget.infoBtn = widgets:RemoveButton(itemWidget, itemWidget)
    -- itemWidget.infoBtn:SetPoint("LEFT", itemWidget, "LEFT", -10, -1)
    -- itemWidget.infoBtn:SetScript("OnClick", function() --[[ TODO ]] end)

    return itemWidget
end

function private:Refresh(version)
    -- first we clear everything
    for _,frame in ipairs(migrationFrameWidgets) do
        frame:Hide()
        frame:ClearAllPoints()
    end
    wipe(migrationFrameWidgets)
    print(version)

    -- then we repopulate (if there are things to show)

    if not next(NysTDL.db.profile.migrationData.savedItemsList) then -- we're done
        NysTDL.db.profile.migrationData.failed = nil
        NysTDL.db.profile.migrationData.savedItemsList = nil
        NysTDL.db.profile.migrationData.version = nil
        NysTDL.db.profile.migrationData.errmsg = nil

        migrationFrame:Hide()
        migrationFrame:ClearAllPoints()
        return
    end

    migrationData.failed.codes[version]()

    -- and finally, this is just to add a space after the last item, just so it looks nice
    local itemWidget = CreateFrame("Frame", nil, migrationFrame.content, nil)
    itemWidget:SetSize(1, 1) -- so that its children are visible

    local spaceLabel = itemWidget:CreateFontString(nil)
    spaceLabel:SetFontObject("GameFontHighlightLarge")
    spaceLabel:SetText(" ")
    spaceLabel:ClearAllPoints()
    spaceLabel:SetPoint("LEFT", itemWidget, "LEFT", 0, 0)

    itemWidget:ClearAllPoints()
    local point, _, relativePoint, ofsx, ofsy = migrationFrameWidgets[#migrationFrameWidgets]:GetPoint()
    itemWidget:SetPoint(point, itemWidget:GetParent(), relativePoint, ofsx, ofsy - 10)
    itemWidget:Show()
    table.insert(migrationFrameWidgets, itemWidget)
end

-- / migration failed from 5.5+ to 6.0+
migrationData.failed.codes["6.0"] = function()
    local y, ydelta, xdelta = 16, 20, 10
    for catName,items in pairs(NysTDL.db.profile.migrationData.savedItemsList) do
        -- categories
        local categoryWidget = CreateCategoryWidget(catName)
        categoryWidget:ClearAllPoints()
        categoryWidget:SetPoint("TOPLEFT", categoryWidget:GetParent(), "TOPLEFT", xdelta, -y)
        table.insert(migrationFrameWidgets, categoryWidget)
        y = y + ydelta

        for itemName,itemData in pairs(items) do
            -- items
            local itemWidget = CreateItemWidget(itemName, itemData, catName)
            itemWidget:ClearAllPoints()
            itemWidget:SetPoint("TOPLEFT", itemWidget:GetParent(), "TOPLEFT", xdelta*2, -y)
            itemWidget:Show()
            table.insert(migrationFrameWidgets, itemWidget)
            y = y + ydelta
        end
    end
end
