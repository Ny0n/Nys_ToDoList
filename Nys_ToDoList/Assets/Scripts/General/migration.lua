-- Namespaces
local _, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local enums = addonTable.enums
local utils = addonTable.utils
local widgets = addonTable.widgets
local database = addonTable.database
local migration = addonTable.migration
local mainFrame = addonTable.mainFrame
local dataManager = addonTable.dataManager

-- Variables
local L = core.L
local LibQTip = core.LibQTip

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
        saved = {},
        version = "",
        codes = {}, -- defined later in the file
    },
}

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
function private:GlobalNewVersion()
    -- // updates the global saved variables once after an update

    if utils:IsVersionOlderThan(NysTDL.db.global.latestVersion, "6.0") then -- if we come from before 6.0
        if NysTDL.db.global.tuto_progression > 5 then -- if we already completed the tutorial
            -- we go to the new part of the edit mode button
            NysTDL.db.global.tuto_progression = 5
        end
    end
end

function private:ProfileNewVersion()
    -- // updates each profile saved variables once after an update

    -- by default after each update, we empty the undo table
    wipe(NysTDL.db.profile.undoTable)

    -- var version migration
    private:CheckVarsMigration()
end

-- // **************************** // --

local xpcall = xpcall

local function errorhandler(err)
	return "Message: \"" .. err .. "\"\n"
		.. "Stack: \"" .. debugstack() .. "\""
end

function private:CheckVarsMigration()
    -- // VAR VERSIONS MIGRATION
    local success, errmsg = xpcall(private.ExecVarsMigration, errorhandler) -- xpcall(<err?>)
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
    if utils:IsVersionOlderThan(NysTDL.db.profile.latestVersion, toVersion) then
        -- the safeguard
        print("SAFEGUARD -- " .. toVersion)
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

        NysTDL.db.profile.latestVersion = toVersion -- success, onto the next one
    end
    print("SAFEGUARD -- FINISHED OK")
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
    migrationData.failed.saved = utils:Deepcopy(profile.itemsList)

    -- ================== --

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

        error("je suis l'erreur")

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
    return not (not next(NysTDL.db.profile.migrationData) or type(NysTDL.db.profile.migrationData.saved) ~= "table" or not next(NysTDL.db.profile.migrationData.saved))
end

function private:Failed(errmsg, original)
    if original then
        local migrationDataSV = NysTDL.db.profile.migrationData
        migrationDataSV.failed = true
        migrationDataSV.saved = migrationData.failed.saved
        migrationDataSV.version = migrationData.failed.version
        migrationDataSV.errmsg = errmsg
        migrationDataSV.tuto = true
        NysTDL.db.profile.itemsList = {}
    end

    private:CreateRecoveryList()
end

function private:CreateRecoveryList()
    if recoveryList.frame then
        recoveryList.frame:Hide()
        recoveryList.frame:ClearAllPoints()
    end

    -- we create the recovery frame
    recoveryList.frame = CreateFrame("Frame", "NysTDL_recoveryList", mainFrame.tdlFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    local frame = recoveryList.frame

    -- as well as the tuto frame
    if NysTDL.db.profile.migrationData.tuto then
        recoveryList.tutoFrame = widgets:TutorialFrame("NysTDL_recoveryList_tutoFrame", true, "DOWN", "You can click on any name to put it in the input field below, you can then Ctrl+C/Ctrl+V", 200, 50)
        recoveryList.tutoFrame.closeButton:SetScript("OnClick", function()
            recoveryList.tutoFrame:Hide()
            recoveryList.tutoFrame:ClearAllPoints()
            NysTDL.db.profile.migrationData.tuto = nil
        end)

        recoveryList.tutoFrame:SetParent(frame)

        recoveryList.tutoFrame:ClearAllPoints()
        recoveryList.tutoFrame:SetPoint("BOTTOM", frame, "TOP", 0, 20)

        recoveryList.tutoFrame:Show()
    end

    -- background
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, tileSize = 1, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })

    frame:SetBackdropColor(0, 0, 0, 1)
    frame:SetBackdropBorderColor(1, 1, 1, 1)

    -- properties
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
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

    header.title = widgets:NoPointsLabel(header, nil, "Recovery List")
    header.title:SetPoint("TOP", header, "TOP", 0, -12)

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
    footer.copyBox = CreateFrame("ScrollFrame", nil, frame, "InputScrollFrameTemplate")
    footer.copyBox:SetPoint("TOPLEFT", footer, "TOPLEFT", 10, -10)
    footer.copyBox:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -10, 10)
    footer.copyBox.EditBox:SetFontObject("ChatFontNormal")
    footer.copyBox.EditBox:SetAutoFocus(false)
    footer.copyBox.ScrollBar.ScrollDownButton:ClearAllPoints()
    footer.copyBox.ScrollBar.ScrollDownButton:SetPoint("BOTTOMRIGHT", footer.copyBox, "BOTTOMRIGHT", -1, 0)

    -- /--> char count
    footer.copyBox.EditBox:SetMaxLetters(enums.maxDescriptionCharCount)
    footer.copyBox.CharCount:Hide() -- TDLATER polish

    -- /--> hint
    footer.copyBox.EditBox.Instructions:SetFontObject("GameFontNormal")
    footer.copyBox.EditBox.Instructions:SetText("Ctrl+C...")

    -- /--> scripts
    footer:SetScript("OnUpdate", function() -- don't ask me why
        footer.copyBox.EditBox:SetWidth(footer.copyBox:GetWidth() - 25)
        -- footer.copyBox.ScrollBar:Hide()
        footer.copyBox.ScrollBar.ScrollUpButton:Hide()
        footer.copyBox.ScrollBar.ThumbTexture:Hide()
    end)
    widgets:SetHyperlinksEnabled(footer.copyBox.EditBox, true)
    recoveryList.copyBox = footer.copyBox.EditBox -- shortcut

    -- /-> copy btn (select all btn)
    footer.copyBtn = CreateFrame("Button", nil, footer, "NysTDL_CopyButton")
    footer.copyBtn.tooltip = "Ctrl+A"
    footer.copyBtn:SetSize(30, 30)
    footer.copyBtn:SetPoint("TOPRIGHT", footer, "TOPRIGHT", -5, -6)
    footer.copyBtn:SetScript("OnClick", function()
        widgets:SetFocusEditBox(recoveryList.copyBox, true)
    end)

    -- // finishing: displaying the data to manually migrate
    private:Refresh(NysTDL.db.profile.migrationData.version) -- migrationData.failed.codes call
end

function private:Event_ScrollFrame_OnMouseWheel(delta)
    -- defines how fast we can scroll throught the frame
    local ScrollFrame, speed = recoveryList.frame.body.ScrollFrame, 20

    local newValue = ScrollFrame:GetVerticalScroll() - (delta * speed)

    if newValue < 0 then
        newValue = 0
    elseif newValue > ScrollFrame:GetVerticalScrollRange() then
        newValue = ScrollFrame:GetVerticalScrollRange()
    end

    ScrollFrame:SetVerticalScroll(newValue)
end

function private:Event_recoveryFrame_OnUpdate()
	if not next(NysTDL.db.profile.migrationData) then
        recoveryList.frame:Hide()
        recoveryList.frame:ClearAllPoints()
        return
	end
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
        wipe(NysTDL.db.profile.migrationData)

        -- and we hide the recovery list once and for all
        recoveryList.frame:Hide()
        recoveryList.frame:ClearAllPoints()
        return
    end

    print("Refresh - " .. version)

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
    categoryWidget.label:ClearAllPoints()
    categoryWidget.label:SetPoint("LEFT", categoryWidget, "LEFT", 0, 0)

    -- -- / removeBtn
    -- categoryWidget.removeBtn = widgets:ValidButton(categoryWidget)
    -- categoryWidget.removeBtn:SetPoint("LEFT", categoryWidget, "LEFT", 0, -1)
    -- -- OnClick set later

    categoryWidget.i = {} -- free space

    -- /-> position
    categoryWidget:ClearAllPoints()
    categoryWidget:SetPoint("TOPLEFT", categoryWidget:GetParent(), "TOPLEFT", deltaX, -currentY)
    table.insert(recoveryList.widgets, categoryWidget)
    currentY = currentY + deltaY

    return categoryWidget
end

function private:NewItemWidget(itemName)

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
    -- OnClick set later

    -- / infoBtn
    itemWidget.infoBtn = widgets:HelpButton(itemWidget)
    itemWidget.infoBtn.tooltip = nil
    itemWidget.infoBtn:SetPoint("LEFT", itemWidget, "LEFT", 24, -1)
    itemWidget.infoBtn:SetScale(0.6)
    itemWidget.infoBtn:HookScript("OnClick", function(self)
        recoveryList.copyBox:SetText(self:GetParent().i.description or "<no description>")
        widgets:SetFocusEditBox(recoveryList.copyBox, true)
    end)
    itemWidget.infoBtn:HookScript("OnEnter", function(self)
        local i = self:GetParent().i
        local tabName, checked, favorite, description = i.tabName, i.checked, i.favorite, i.description -- those are set dynamically

        -- <!> tooltip content <!>

        recoveryList.tooltip = LibQTip:Acquire("NysTDL_recoveryList_tooltip", 1)
        local tooltip = recoveryList.tooltip

        tooltip:SmartAnchorTo(self)
        tooltip:ClearAllPoints()
        tooltip:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, 0)

        tooltip:AddHeader("Tab: " .. (tabName or "--"))
        tooltip:SetLineTextColor(1, unpack(database.themes.theme_yellow))

        if checked then
            tooltip:AddLine("Checked: yes")
        end
        if favorite then
            tooltip:AddLine("Favorite: yes")
        end
        if description then
            tooltip:AddLine("Description: Click to copy")
        end

        tooltip:Show()
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

-- / migration failed from 5.5+ to 6.0+
migrationData.failed.codes["6.0"] = function()
    local removeBtnFunc = function(self)
        local catName, itemName = self:GetParent().i.catName, self:GetParent().i.itemName
        local list = NysTDL.db.profile.migrationData.saved

        if not private:CheckSaved() then
            private:Refresh(NysTDL.db.profile.migrationData.version)
            return
        end

        if list[catName] then
            list[catName][itemName] = nil
            if not next(list[catName]) then
                list[catName] = nil
            end
        end

        private:Refresh(NysTDL.db.profile.migrationData.version)
    end

    for catName,items in pairs(NysTDL.db.profile.migrationData.saved) do -- categories

        -- == cat ==
        local catWidget = private:NewCategoryWidget(catName)
        -- =========

        for itemName,itemData in pairs(items) do -- items

            -- == item ==
            local itemWidget = private:NewItemWidget(itemName)
            itemWidget.removeBtn:HookScript("OnClick", removeBtnFunc)
            itemWidget.i.catName = catName
            itemWidget.i.itemName = itemName
            if type(itemData) == "table" then -- custom data
                itemWidget.i.tabName = itemData.tabName
                itemWidget.i.checked = itemData.checked
                itemWidget.i.favorite = itemData.favorite
                itemWidget.i.description = itemData.description
            end
            -- ==========

        end
    end
end
