-- Namespaces
local addonName, tdlTable = ...;
tdlTable.itemsFrame = {}; -- adds itemsFrame table to addon namespace

local config = tdlTable.config;
local itemsFrame = tdlTable.itemsFrame;

-- Variables declaration --
local AceGUI = config.AceGUI;
local L = config.L;

local itemsFrameUI;
local AllTab, DailyTab, WeeklyTab, CurrentTab;

-- reset variables
local remainingCheckAll, remainingCheckDaily, remainingCheckWeekly = 0, 0, 0;
local clearing, undoing = false, { ["clear"] = false, ["clearnb"] = 0, ["single"] = false, ["singleok"] = true};

local dontHideMePls = {};
local checkBtn = {};
local removeBtn = {};
local addBtn = {};
local label = {};
local editBox = {};
local sbBtn = {};
local labelHover = {};
local addACategoryClosed = true;
local optionsClosed = true;

-- these are for code comfort (sort of)
local addACategoryItems = {}
local optionsItems = {}
local currentDBItemsList;
local categoryNameWidthMax = 220;
local itemNameWidthMax = 240;
local editBoxAddItemWidth = 270;
local sbBtnDistFromLabel = 1;
local centerXOffset = 165;
local lineOffset = 120;

local All = {};

local ItemsFrame_Update;
local ItemsFrame_UpdateTime;
local Tab_OnClick;

local updateRate = 0.05;
local refreshRate = 1;

--------------------------------------
-- General functions
--------------------------------------

function itemsFrame:Toggle()
  -- changes the visibility of the ToDoList frame
  if (not itemsFrameUI:IsShown()) then -- We update the frame if we are about to show it
    ItemsFrame_UpdateTime();
    ItemsFrame_Update();
  end
  itemsFrameUI:SetShown(not itemsFrameUI:IsShown());
end

-- actions
local function ScrollFrame_OnMouseWheel(self, delta)
  -- defines how fast we can scroll throught the tabs (here: 35)
  local newValue = self:GetVerticalScroll() - (delta * 35);

  if (newValue < 0) then
    newValue = 0;
  elseif (newValue > self:GetVerticalScrollRange()) then
    newValue = self:GetVerticalScrollRange();
  end

  self:SetVerticalScroll(newValue);
end

local function FrameAlphaSlider_OnValueChanged(self, value)
  NysTDL.db.profile.frameAlpha = value;
  itemsFrameUI.frameAlphaSliderValue:SetText(value);
  itemsFrameUI:SetBackdropColor(0, 0, 0, value/100);
end

local function FrameContentAlphaSlider_OnValueChanged(self, value)
  NysTDL.db.profile.frameContentAlpha = value;
  itemsFrameUI.frameContentAlphaSliderValue:SetText(value);
  itemsFrameUI.ScrollFrame:SetAlpha((value)/100);
  itemsFrameUI.closeButton:SetAlpha((value)/100);
  for i = 1, 3 do
      _G["ToDoListUIFrameTab"..i]:SetAlpha((value-(100-value)*0.8)/100);
      _G["ToDoListUIFrameTab"..i].content:SetAlpha((value)/100);
  end
end

-- frame functions
function itemsFrame:ResetBtns(tabName, auto)
  -- this function's goal is to reset (uncheck) every item in the given tab
  -- "auto" is to differenciate the user pressing the uncheck button and the auto reset
  local uncheckedSomething = false;

  for i = 1, #All do
    if (tabName == "All") then
      if (config:HasItem(All, checkBtn[All[i]]:GetName())) then -- the All table isn't in the saved variable
        if (checkBtn[All[i]]:GetChecked()) then
          uncheckedSomething = true;
        end

        checkBtn[All[i]]:SetChecked(false);
      end
    elseif (config:HasItem(NysTDL.db.profile.itemsList[tabName], checkBtn[All[i]]:GetName())) then
      if (checkBtn[All[i]]:GetChecked()) then
        uncheckedSomething = true;
      end

      checkBtn[All[i]]:SetChecked(false);
    end
  end
  ItemsFrame_Update();

  if (uncheckedSomething) then -- so that we print this message only if there was checked items before the uncheck
    if (tabName == "All") then
      config:Print(L["Unchecked everything!"]);
    else
      config:Print(L["Unchecked %s tab!"]:format(L[tabName]));
    end
  elseif (not auto) then -- we print this message only if it was the user's action that triggered this function (not the auto reset)
    config:Print(L["Nothing to uncheck here!"]);
  end
end

local function inChatIsDone(all, daily, weekly)
  -- we tell the player if he's the best c:
  if (all == 0 and remainingCheckAll ~= 0 and next(All) ~= nil) then
    config:Print(L["Nice job, you did everything on the list for this week!"]);
  elseif (daily == 0 and remainingCheckDaily ~= 0 and next(NysTDL.db.profile.itemsList["Daily"]) ~= nil) then
    config:Print(L["Everything's done for today!"]);
  elseif (weekly == 0 and remainingCheckWeekly ~= 0 and next(NysTDL.db.profile.itemsList["Weekly"]) ~= nil) then
    config:Print(L["Everything's done for this week!"]);
  end
end

local function updateRemainingNumber()
  -- we get how many things there is left to do in every tab
  local numberAll, numberDaily, numberWeekly = 0, 0, 0;
  for i = 1, #All do
    if (not checkBtn[All[i]]:GetChecked()) then
      if (config:HasItem(NysTDL.db.profile.itemsList["Daily"], checkBtn[All[i]]:GetName())) then
        numberDaily = numberDaily + 1;
      end
      if (config:HasItem(NysTDL.db.profile.itemsList["Weekly"], checkBtn[All[i]]:GetName())) then
        numberWeekly = numberWeekly + 1;
      end
      numberAll = numberAll + 1;
    end
  end

  -- we say in the chat gg if we completed everything for any tab
  -- (and we were not in a clear)
  if (not clearing) then inChatIsDone(numberAll, numberDaily, numberWeekly); end

  -- we update the number of remaining things to do for the current tab
  local tab = itemsFrameUI.remainingNumber:GetParent();
  if (tab == AllTab) then
    itemsFrameUI.remainingNumber:SetText("|cffffffff"..numberAll.."|r");
  elseif (tab == DailyTab) then
    itemsFrameUI.remainingNumber:SetText("|cffffffff"..numberDaily.."|r");
  elseif (tab == WeeklyTab) then
    itemsFrameUI.remainingNumber:SetText("|cffffffff"..numberWeekly.."|r");
  end

  -- and update the "last" remainings for EACH tab (for the inChatIsDone function)
  remainingCheckAll = numberAll;
  remainingCheckDaily = numberDaily;
  remainingCheckWeekly = numberWeekly;
end

local function updateCheckButtons()
  -- we color the items wether they're checked or not
  for i = 1, #All do
    if (checkBtn[All[i]]:GetChecked()) then
      checkBtn[All[i]].text:SetTextColor(0, 1, 0);
    else
      checkBtn[All[i]].text:SetTextColor(unpack(config:ThemeDownTo01(config.database.theme_yellow)));
    end
  end
end

-- Saved variable functions

local function loadSavedVariable()
  -- checks all the saved checked items
  for i = 1, #All do
    if (config:HasItem(NysTDL.db.profile.checkedButtons, checkBtn[All[i]]:GetName())) then
      checkBtn[All[i]]:SetChecked(true);
    end
  end
end

local function saveSavedVariable()
  -- we update the checked items table
  for i = 1, #All do
    local isPresent, pos = config:HasItem(NysTDL.db.profile.checkedButtons, checkBtn[All[i]]:GetName());

    if (checkBtn[All[i]]:GetChecked() and not isPresent) then
      table.insert(NysTDL.db.profile.checkedButtons, checkBtn[All[i]]:GetName());
    end

    if (not checkBtn[All[i]]:GetChecked() and isPresent) then
      table.remove(NysTDL.db.profile.checkedButtons, pos);
    end
  end
end

function itemsFrame:autoReset()
  if time() > NysTDL.db.profile.autoReset["Weekly"] then
    NysTDL.db.profile.autoReset["Daily"] = config:GetSecondsToReset().daily;
    NysTDL.db.profile.autoReset["Weekly"] = config:GetSecondsToReset().weekly;
    itemsFrame:ResetBtns("Daily", true);
    itemsFrame:ResetBtns("Weekly", true);
  elseif time() > NysTDL.db.profile.autoReset["Daily"] then
    NysTDL.db.profile.autoReset["Daily"] = config:GetSecondsToReset().daily;
    itemsFrame:ResetBtns("Daily", true);
  end
end

-- Items modifications

local function updateAllTable()
  All = {}
  -- Completing the All table
  for k, val in pairs(NysTDL.db.profile.itemsList) do
    if (k ~= "Daily" and k ~= "Weekly") then
      for _, v in pairs(val) do
        table.insert(All, v);
      end
    end
  end
  table.sort(All); -- so that every item will be sorted alphabetically in the list
end

local function refreshTab(cat, name, action, modif, checked)
  -- if the last tab we were on is getting an update
  -- because of an add or remove of an item, we re-update it

  if (modif) then
    -- Removing case
    if (action == "Remove") then
      if (cat == nil) then
        local isPresent, pos = config:HasItem(NysTDL.db.profile.checkedButtons, checkBtn[name]:GetName());
        if (checked and isPresent) then
          table.remove(NysTDL.db.profile.checkedButtons, pos);
        end

        checkBtn[name]:Hide(); -- get out of my view mate
        removeBtn[name] = nil;
        checkBtn[name] = nil;
      end

      Tab_OnClick(_G[NysTDL.db.profile.lastLoadedTab]); -- we reload the tab to instantly display the changes
    end

    -- Adding case
    if (action == "Add") then
      -- we create the new check button
      if (checkBtn[name] == nil) then
        checkBtn[name] = CreateFrame("CheckButton", name, itemsFrameUI, "UICheckButtonTemplate");
        checkBtn[name].text:SetText(name);
        checkBtn[name].text:SetFontObject("GameFontNormalLarge");
        checkBtn[name]:SetChecked(checked);
        checkBtn[name]:SetScript("OnClick", ItemsFrame_Update);

        removeBtn[name] = config:CreateRemoveButton(checkBtn[name]);
        removeBtn[name]:SetScript("OnClick", function(self) itemsFrame:RemoveItem(self) end);
      end
      -- we create the corresponding label (if it is a new one)
      if (label[cat] == nil) then
        -- category label
        label[cat] = config:CreateNoPointsLabel(itemsFrameUI, cat, tostring(cat));
        -- associated edit box and add button
        editBox[cat] = config:CreateNoPointsLabelEditBox(cat);
        editBox[cat]:SetScript("OnEnterPressed", function(self) itemsFrame:AddItem(addBtn[self:GetName()]) end); -- if we press enter, it's like we clicked on the add button
        addBtn[cat] = config:CreateAddButton(editBox[cat]);
        addBtn[cat]:SetScript("OnClick", function(self) itemsFrame:AddItem(self) end);
        -- associated show box button
        sbBtn[cat] = config:CreateNoPointsShowBoxButton('sbBtn'..cat);
        sbBtn[cat]:SetScript("OnClick", function(self)
          editBox[cat]:SetShown(not editBox[cat]:IsShown());
          self.Icon:SetRotation(-(select(1,self.Icon:GetRotation())));
          local point, relativeFrame, relativePoint = self:GetPoint(); -- and we change just a bit his position so that is looks better, depending on the way he is facing
          if (editBox[cat]:IsShown()) then
            self:SetPoint(point, relativeFrame, relativePoint, sbBtnDistFromLabel + 5, 0);
          else
            self:SetPoint(point, relativeFrame, relativePoint, sbBtnDistFromLabel, 0);
          end
        end)
      end

      Tab_OnClick(_G[NysTDL.db.profile.lastLoadedTab]); -- we reload the tab to instantly display the changes
    end
  end
end

local function addCategory()
  -- the big function to add categories

  local db = {}
  db.cat = itemsFrameUI.categoryEditBox:GetText();

  local check = db.cat:lower()
  if (check == "") then
    config:Print(L["Please enter a category name!"])
    return;
  elseif (check == "weekly" or check == "daily") then
    config:Print(L["The category name cannot be '%s' or '%s', sorry! (there are tabs for that!)"]:format("daily", "weekly"))
    return;
  end

  local l = config:CreateNoPointsLabel(itemsFrameUI, nil, db.cat);
  if (l:GetWidth() > categoryNameWidthMax) then
    config:Print(L["This categoty name is too big!"])
    return;
  end

  db.name = itemsFrameUI.nameEditBox:GetText();
  if (db.name == "") then
    config:Print(L["Please enter the name of the item!"])
    return;
  end

  local l = config:CreateNoPointsLabel(itemsFrameUI, nil, db.name);
  if (l:GetWidth() > itemNameWidthMax) then
    config:Print(L["This item name is too big!"])
    return;
  end

  db.case = itemsFrameUI.categoryButton:GetParent():GetName();
  db.checked = false;

  -- this one is for clearing the text of both edit boxes IF the adding is a success
  db.form = true;

  itemsFrame:AddItem(nil, db);
end

function itemsFrame:AddItem(self, db)
  -- the big big function to add items

  local stop = false; -- we can't use return; here, so we do it manually (but it's horrible yes)
  local name, case, cat, checked;
  local new = false;
  local addResult = {"", false}; -- message to be displayed in result of the function and wether there was an adding or not

  if (type(db) ~= "table") then
    name = self:GetParent():GetText(); -- we get the name the player entered
    case = self:GetParent():GetParent():GetName(); -- we get the tab we're on
    cat = self:GetParent():GetName(); -- we get the category we're adding the item in
    checked = false;

    local l = config:CreateNoPointsLabel(itemsFrameUI, nil, name);
    if (l:GetWidth() > itemNameWidthMax) then -- is it too big?
      config:Print(L["This item name is too big!"])
      return;
    end
  else
    name = db.name;
    case = db.case;
    cat = db.cat;
    checked = db.checked;
  end

  if case == "All" then
    case = nil;
  end

  if (name ~= "") then -- if we typed something
    local isPresent0, isPresent1, isPresent2, isPresent3, hasKey;

    isPresent1 = (select(1, config:HasItem(All, name))); -- does it already exists in All?

    hasKey = config:HasKey(NysTDL.db.profile.itemsList, cat);
    if (not hasKey) then NysTDL.db.profile.itemsList[cat] = {}; new = true; end -- that means we'll be adding something to a new category, so we create the table to hold all theses shiny new items

    if (case == nil) then
      isPresent0 = (select(1, config:HasItem(NysTDL.db.profile.itemsList[cat], name)));-- does it already exists in the typed category?
    else
      isPresent0 = (select(1, config:HasItem(NysTDL.db.profile.itemsList[case], name)));-- does it already exists in Daily/Weekly?
      isPresent3 = (select(1, config:HasItem(NysTDL.db.profile.itemsList[cat], name)));-- does it already exists in the typed category?
      if (isPresent1 and not isPresent3) then -- if it already exists but not in this category
        addResult = {L["This item name already exists!"], false};
        stop = true;
      end
    end

    if (not stop) then
      if (not isPresent0) then
        if (case == "Daily") then
          isPresent2 = (select(1, config:HasItem(NysTDL.db.profile.itemsList["Weekly"], name)));
        elseif (case == "Weekly") then
          isPresent2 = (select(1, config:HasItem(NysTDL.db.profile.itemsList["Daily"], name)));
        else
          stop = true;
          if (not isPresent1) then
            table.insert(NysTDL.db.profile.itemsList[cat], name);
            addResult = {L["\"%s\" added to %s! ('All' tab item)"]:format(name, cat), true};
          else
            addResult = {L["This item name already exists!"], false};
          end
        end
        if (not stop) then
          if (not isPresent1) then
            table.insert(NysTDL.db.profile.itemsList[cat], name);
            table.insert(NysTDL.db.profile.itemsList[case], name);
            addResult = {L["\"%s\" added to %s! (%s item)"]:format(name, cat, L[case]), true};
          elseif (not isPresent2) then
            table.insert(NysTDL.db.profile.itemsList[case], name);
            addResult = {L["\"%s\" added to %s! (%s item)"]:format(name, cat, L[case]), true};
          else
            addResult = {L["No item can be daily and weekly!"], false};
          end
        end
      else
        addResult = {L["This item is already here in this category!"], false};
      end
    end
  else
    addResult = {L["Please enter the name of the item!"], false};
  end

  if (new and not addResult[2]) then -- if we didn't add anything and it was supposed to create a new category, we cancel our move and nil this false new empty category
    NysTDL.db.profile.itemsList[cat] = nil;
  end

  -- okay so we print only if we're not in a clear undo process / single undo process but failed
  if (undoing["single"]) then undoing["singleok"] = addResult[2]; end
  if (not undoing["clear"] and not (undoing["single"] and not undoing["singleok"])) then config:Print(addResult[1]);
  elseif (addResult[2]) then undoing["clearnb"] = undoing["clearnb"] + 1; end

  if (addResult[2]) then
    if (type(db) ~= "table") then -- if we come from the edit box to add an item net to the category name label
      dontHideMePls[cat] = true; -- then the ending refresh must not hide the edit box
      self:GetParent():SetText(""); -- but we clear it since our query was succesful
    elseif (type(db) == "table" and db.form) then -- if we come from the Add a new category form
      itemsFrameUI.categoryEditBox:SetText("");
      itemsFrameUI.nameEditBox:SetText("");
    end
  end

  refreshTab(cat, name, "Add", addResult[2], checked);
end

function itemsFrame:RemoveItem(self)
  -- the big big function to remove items

  local modif = false;
  local isPresent, pos;

  name = self:GetParent():GetName(); -- we get the name of the tied check button
  cat = (select(2, self:GetParent():GetPoint())):GetName(); -- we get the category we're in

  -- undo part
  local db = {
    ["name"] = name;
    ["cat"] = cat;
    ["case"] = "All";
    ["checked"] = self:GetParent():GetChecked();
  }

  -- All part
  table.remove(NysTDL.db.profile.itemsList[cat], (select(2, config:HasItem(NysTDL.db.profile.itemsList[cat], name))));
  -- Daily part
  isPresent, pos = config:HasItem(NysTDL.db.profile.itemsList["Daily"], name);
  if (isPresent) then
    db.case = "Daily";
    table.remove(NysTDL.db.profile.itemsList["Daily"], pos);
  end
  -- Weekly part
  isPresent, pos = config:HasItem(NysTDL.db.profile.itemsList["Weekly"], name);
  if (isPresent) then
    db.case = "Weekly";
    table.remove(NysTDL.db.profile.itemsList["Weekly"], pos);
  end

  if (not clearing) then
    config:Print(L["\"%s\" removed!"]:format(name));
    dontHideMePls[cat] = true; -- we don't hide the edit box at the next refresh for the category we just deleted an item from
  end
  modif = true;

  table.insert(NysTDL.db.profile.undoTable, db);

  refreshTab(case, name, "Remove", modif, db.checked);
end

function itemsFrame:ClearTab(tabName)
  if (tabName == nil) then tabName = "All"; end

  local items = {};
  if (tabName == "All") then items = All; end
  if (tabName == "Daily") then items = NysTDL.db.profile.itemsList["Daily"]; end
  if (tabName == "Weekly") then items = NysTDL.db.profile.itemsList["Weekly"]; end

  if (next(items) ~= nil) then
    -- we start the clear
    clearing = true;

    -- we keep in mind what tab we were on when we started the clear (just so that we come back to it after the job is done)
    local last = NysTDL.db.profile.lastLoadedTab;

    -- we now go throught each of the tabs (weekly / daily / all) successively to remove every item there are, and in their correct tabs
    local nb = #items; -- but before (if we want to undo it) we keep in mind how many items there were

    Tab_OnClick(_G["ToDoListUIFrameTab1"]); -- we put ourselves in the All tab so that evey item is loaded

    for k, v in pairs(removeBtn) do
      if (config:HasItem(items, v:GetParent():GetName())) then -- if the item is in the tab we want to clear
        itemsFrame:RemoveItem(v);
      end
    end

    table.insert(NysTDL.db.profile.undoTable, nb);

    -- we refresh and go back to the tab we were on
    Tab_OnClick(_G[last]);

    clearing = false;
    config:Print(L["Clear succesful! (%s tab, %i items)"]:format(L[tabName], nb));
  else
    config:Print(L["Nothing to clear here!"]);
  end
end

function itemsFrame:UndoRemove()
  -- function to undo the last removes we did
  if (next(NysTDL.db.profile.undoTable)) then -- if there's something to undo
    if (type(NysTDL.db.profile.undoTable[#NysTDL.db.profile.undoTable]) ~= "table") then -- if it was a clear command
      -- we start undoing it
      undoing["clear"] = true;
      local nb = NysTDL.db.profile.undoTable[#NysTDL.db.profile.undoTable];
      table.remove(NysTDL.db.profile.undoTable, #NysTDL.db.profile.undoTable);
      for i = 1, nb do
        itemsFrame:AddItem(nil, NysTDL.db.profile.undoTable[#NysTDL.db.profile.undoTable]);
        table.remove(NysTDL.db.profile.undoTable, #NysTDL.db.profile.undoTable);
      end
      config:Print(L["Clear undo succesful! (%i items added back)"]:format(undoing["clearnb"]));
      undoing["clearnb"] = 0;
      undoing["clear"] = false;
    else -- if it was a simple remove
      undoing["single"] = true;
      itemsFrame:AddItem(nil, NysTDL.db.profile.undoTable[#NysTDL.db.profile.undoTable]);
      table.remove(NysTDL.db.profile.undoTable, #NysTDL.db.profile.undoTable);
      local pass = undoing["singleok"];
      undoing["singleok"] = true;
      undoing["single"] = false;
      if (not pass) then itemsFrame:UndoRemove() end -- if the single undo failed (because of the user AAAAH :D) we just do it one more time
    end
  else
    config:Print(L["No remove/clear to undo!"]);
  end
end

-- Frame update: --
ItemsFrame_Update = function(...)
  -- updates everything about the frame once everytime we call this function
  updateAllTable();
  updateRemainingNumber();
  updateCheckButtons();
  saveSavedVariable();
end

ItemsFrame_UpdateTime = function()
  -- updates things about time
  itemsFrame:autoReset();
end

local function ItemsFrame_CheckLabels()
  -- update for the labels:
  for k, i in pairs(NysTDL.db.profile.itemsList) do
    if (k ~= "Daily" and k ~= "Weekly") then
      if (label[k]:IsMouseOver()) then -- for every label in the current tab, if our mouse is over one of them,
        label[k]:SetTextColor(0, 0.8, 1, 1); -- we change its visual
        local isPresent, pos = config:HasItem(labelHover, k);
        if (not isPresent) then
          table.insert(labelHover, k); -- we add its category name in a table variable
        end
      else
        local isPresent, pos = config:HasItem(labelHover, k);
        if (isPresent) then
          table.remove(labelHover, pos); -- if we're not hovering it, we delete it from that table
        end
        label[k]:SetTextColor(1, 1, 1, 1); -- back to the default color
      end
    end
  end
end

local function ItemsFrame_OnMouseUp()
  -- if we're here, it means we've clicked somewhere on the frame
  if (next(labelHover)) then -- if we are mouse hovering one of the category labels
    local name = tostringall(unpack(labelHover)); -- we get the name of that label
    if (config:HasKey(NysTDL.db.profile.closedCategories, name) and NysTDL.db.profile.closedCategories[name] ~= nil) then -- if this is a category that is closed in certain tabs
      local isPresent, pos = config:HasItem(NysTDL.db.profile.closedCategories[name], CurrentTab:GetName()); -- we get if it is closed in the current tab
      if (isPresent) then -- if it is
        table.remove(NysTDL.db.profile.closedCategories[name], pos); -- then we remove it from the saved variable
        if (#NysTDL.db.profile.closedCategories[name] == 0) then -- and btw check if it was the only tab remaining where it was closed
          NysTDL.db.profile.closedCategories[name] = nil; -- in which case we nil the table variable for that category
        end
      else  -- if it is opened in the current tab
        table.insert(NysTDL.db.profile.closedCategories[name], CurrentTab:GetName()); -- then we close it by adding it to the saved variable
      end
    else -- if this category was closed nowhere
      NysTDL.db.profile.closedCategories[name] = {CurrentTab:GetName()}; -- then we create its table variable and initialize it with the current tab (we close the category in the current tab)
    end
    Tab_OnClick(_G[NysTDL.db.profile.lastLoadedTab]); -- we reload the frame to display the changes
  end
end

local function ItemsFrame_OnVisibilityUpdate()
  -- things to do when we hide/show the list
  addACategoryClosed = true;
  optionsClosed = true;
  Tab_OnClick(_G[NysTDL.db.profile.lastLoadedTab]);
end

local function ItemsFrame_OnUpdate(self, elapsed)
  -- called every frame
  self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed;
  self.timeSinceLastRefresh = self.timeSinceLastRefresh + elapsed;

  while (self.timeSinceLastUpdate > updateRate) do -- every 0.05 sec (instead of every frame which is every 1/144 (0.007) sec for a 144hz display... optimization :D)
    ItemsFrame_CheckLabels();
    self.timeSinceLastUpdate = self.timeSinceLastUpdate - updateRate;
  end

  while (self.timeSinceLastRefresh > refreshRate) do -- every one second
    ItemsFrame_UpdateTime();
    self.timeSinceLastRefresh = self.timeSinceLastRefresh - refreshRate;
  end
end

----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------

--------------------------------------
-- frame creation and functions
--------------------------------------

local function loadMovable()
  -- All items transformed as checkboxes
  for i = 1, #All, 1 do
    checkBtn[All[i]] = CreateFrame("CheckButton", All[i], itemsFrameUI, "UICheckButtonTemplate");
    checkBtn[All[i]].text:SetText(All[i]);
    checkBtn[All[i]].text:SetFontObject("GameFontNormalLarge");
    checkBtn[All[i]]:SetScript("OnClick", ItemsFrame_Update);

    removeBtn[All[i]] = config:CreateRemoveButton(checkBtn[All[i]]);
    removeBtn[All[i]]:SetScript("OnClick", function(self) itemsFrame:RemoveItem(self) end);
  end

  -- Category labels
  for k, i in pairs(NysTDL.db.profile.itemsList) do
    if (k ~= "Daily" and k ~= "Weekly") then
      -- category label
      label[k] = config:CreateNoPointsLabel(itemsFrameUI, k, tostring(k));
      -- associated edit box and add button
      editBox[k] = config:CreateNoPointsLabelEditBox(k);
      editBox[k]:SetScript("OnEnterPressed", function(self) itemsFrame:AddItem(addBtn[self:GetName()]) end); -- if we press enter, it's like we clicked on the add button
      addBtn[k] = config:CreateAddButton(editBox[k]);
      addBtn[k]:SetScript("OnClick", function(self) itemsFrame:AddItem(self) end);
      -- associated show box button
      sbBtn[k] = config:CreateNoPointsShowBoxButton('sbBtn'..k);
      sbBtn[k]:SetScript("OnClick", function(self)
        editBox[k]:SetShown(not editBox[k]:IsShown()); -- we change the visibily of the corresponding edit box
        self.Icon:SetRotation(-(select(1,self.Icon:GetRotation()))); -- we change its rotation so that he is looking the other way
        local point, relativeFrame, relativePoint = self:GetPoint(); -- and we change just a bit his position so that is looks better, depending on the way he is facing
        if (editBox[k]:IsShown()) then
          self:SetPoint(point, relativeFrame, relativePoint, sbBtnDistFromLabel + 5, 0);
        else
          self:SetPoint(point, relativeFrame, relativePoint, sbBtnDistFromLabel, 0);
        end
      end)
    end
  end
end

-- boom
local function loadCategories(tab, category, categoryLabel, constraint, catName, lastData, once)
  if (once) then -- doing that only one time
    -- we hide every checkboxes
    for i = 1, #All do
      checkBtn[All[i]]:Hide();
      checkBtn[All[i]]:SetParent(tab);
      checkBtn[All[i]]:ClearAllPoints();
    end
    once = false;
  end

  -- if we are not in the all tab, we modify the category variable
  -- (which is a table containig every item in this tab)
  -- so that there will only be the items respective to the category
  if (constraint ~= nil) then
    local cat = {}
    for i = 1, #category do
      if (select(1, config:HasItem(constraint, category[i]))) then
        table.insert(cat, category[i]);
      end
    end
    category = cat;
  end

  if (config:HasAtLeastOneItem(All, category)) then -- litterally, for this tab
    -- category label
    if (lastData == nil) then
      lastLabel = itemsFrameUI.dummyLabel;
      l = 0;
    else
      lastLabel = lastData["categoryLabel"];
      if ((select(1, config:HasKey(NysTDL.db.profile.closedCategories, lastData["catName"]))) and (select(1, config:HasItem(NysTDL.db.profile.closedCategories[lastData["catName"]], CurrentTab:GetName())))) then -- if the last category was a closed one in this tab
        l = 1;
      else
        l = #lastData["category"] + 1;
      end
    end

    if (l == 0) then m = 0; else m = 1; end -- just for a proper clean height
    categoryLabel:SetParent(tab);
    categoryLabel:SetPoint("TOPLEFT", lastLabel, "TOPLEFT", 0, (-l * 22) - (m * 5)); -- here
    categoryLabel:Show();

    -- edit box
    editBox[categoryLabel:GetName()]:SetParent(tab);
    -- edit box width (adapt to the category label's length)
    local labelWidth = tonumber(string.format("%i", categoryLabel:GetWidth()));
    labelWidth = labelWidth + 20; -- 20 is approximatively the width of the showEditBox button to the right of the label)
    local distanceFromLabelWhenOk = 160;
    if (labelWidth + 120 > editBoxAddItemWidth) then
    editBox[categoryLabel:GetName()]:SetPoint("LEFT", categoryLabel, "RIGHT", 10 + 20, 0);
      editBox[categoryLabel:GetName()]:SetWidth(editBoxAddItemWidth - labelWidth);
    else
      editBox[categoryLabel:GetName()]:SetPoint("LEFT", categoryLabel, "LEFT", distanceFromLabelWhenOk, 0);
    end

    -- show edit box button
    sbBtn[categoryLabel:GetName()]:SetParent(tab);
    sbBtn[categoryLabel:GetName()]:Show();

    -- we keep the edit box for this category shown if we just added an item with it
    if (not dontHideMePls[categoryLabel:GetName()]) then
      sbBtn[categoryLabel:GetName()].Icon:SetRotation(-1.5); -- radians (-90°, facing right, by default)
      sbBtn[categoryLabel:GetName()]:SetPoint("LEFT", categoryLabel, "RIGHT", sbBtnDistFromLabel, 0);
      editBox[categoryLabel:GetName()]:Hide();
    else
      dontHideMePls[categoryLabel:GetName()] = nil;
      -- we do not change its points, he's still here and anchored to the label (which may have moved, but will update the button as well on its own)
    end

    if (not (select(1, config:HasKey(NysTDL.db.profile.closedCategories, catName))) or not (select(1, config:HasItem(NysTDL.db.profile.closedCategories[catName], CurrentTab:GetName())))) then -- if the category is opened in this tab, we display all of its items
      -- checkboxes
      local buttonsLength = 0;
      for i = 1, #All do
        if ((select(1, config:HasItem(category, checkBtn[All[i]]:GetName())))) then
          buttonsLength = buttonsLength + 1;

          checkBtn[All[i]]:SetParent(tab);
          checkBtn[All[i]]:SetPoint("TOPLEFT", categoryLabel, "TOPLEFT", 30, - 22 * buttonsLength + 5);
          checkBtn[All[i]]:Show();
        end
      end
    else
      -- if not, we still need to put them at their right place, anchors and parents (but we keep them hidden)
      -- especially for when we load the All tab, for the clearing
      for i = 1, #All do
        if ((select(1, config:HasItem(category, checkBtn[All[i]]:GetName())))) then
          checkBtn[All[i]]:SetParent(tab);
          checkBtn[All[i]]:SetPoint("TOPLEFT", categoryLabel, "TOPLEFT");
        end
      end
    end
  else
    -- if the current label has no reason to be visible in this tab, we hide it (and for the checkboxes, they have already been hidden in the first call to this func).
    -- so first we hide them to be sure they are gone from our view, and then it's a bit more complicated:
    -- we reset their parent to be the current tab, so that we're sure that they are all on the same tab, and then
    -- ClearAllPoints is pretty magical here since a hidden label CAN be clicked on and still manages to fire OnEnter and everything else, so :Hide() is not enough,
    -- so with this API we clear their points so that they have nowhere to go and they don't fire events anymore.
    label[catName]:Hide();
    sbBtn[catName]:Hide();
    editBox[catName]:Hide();
    label[catName]:SetParent(tab);
    sbBtn[catName]:SetParent(tab);
    editBox[catName]:SetParent(tab);
    label[catName]:ClearAllPoints();
    sbBtn[catName]:ClearAllPoints();
    editBox[catName]:ClearAllPoints();
    dontHideMePls[catName] = nil;

    if (not next(NysTDL.db.profile.itemsList[catName])) then -- if there is no more item in a category, we delete the corresponding elements
      -- we destroy them
      addBtn[catName] = nil;
      editBox[catName] = nil;
      sbBtn[catName] = nil;
      label[catName] = nil;

      -- and we nil them in the saved variable
      NysTDL.db.profile.itemsList[catName] = nil;
      if (config:HasKey(NysTDL.db.profile.closedCategories, catName) and NysTDL.db.profile.closedCategories[catName] ~= nil) then -- we verify if it was a closed category (can happen with the clear command)
        NysTDL.db.profile.closedCategories[catName] = nil;
      end
    end

    if (config:HasKey(NysTDL.db.profile.closedCategories, catName) and NysTDL.db.profile.closedCategories[catName] ~= nil) then
      local isPresent, pos = config:HasItem(NysTDL.db.profile.closedCategories[catName], CurrentTab:GetName()); -- we get if it is closed in the current tab
      if (isPresent) then -- if it is
        table.remove(NysTDL.db.profile.closedCategories[catName], pos); -- then we remove it from the saved variable
        if (#NysTDL.db.profile.closedCategories[catName] == 0) then -- and btw check if it was the only tab remaining where it was closed
          NysTDL.db.profile.closedCategories[catName] = nil; -- in which case we nil the table variable for that category
        end
      end
    end

    return lastData, once; -- if we are here, lastData shall not be changed or there will be consequences! (so we end the function prematurely)
  end

  lastData = {
    ["tab"] = tab,
    ["category"] = category,
    ["categoryLabel"] = categoryLabel,
    ["constraint"] = constraint,
    ["catName"] = catName,
  }
  return lastData, once;
end

-------------------------------------------------------------------------------------------
-- Contenting:<3 --------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

-- generating the list items
local function generateTab(tab, case)
  -- We sort all of the categories in alphabetical order
  local tempTable = {}
  for t in pairs(NysTDL.db.profile.itemsList) do table.insert(tempTable, t) end
  table.sort(tempTable);

  -- we load everything
  local lastData, once = nil, true;
  for _, n in pairs(tempTable) do
    if (n ~= "Daily" and n ~= "Weekly") then
      lastData, once = loadCategories(tab, NysTDL.db.profile.itemsList[n], label[n], case, n, lastData, once);
    end
  end
end

----------------------------

local function loadAddACategory(tab)
  itemsFrameUI.categoryButton:SetParent(tab);
  itemsFrameUI.categoryButton:SetPoint("RIGHT", itemsFrameUI.optionsButton, "LEFT", 2, 0);

  itemsFrameUI.categoryTitle:SetParent(tab);
  itemsFrameUI.categoryTitle:SetPoint("TOP", itemsFrameUI.title, "TOP", 0, - 59);

  itemsFrameUI.labelCategoryName:SetParent(tab);
  itemsFrameUI.labelCategoryName:SetPoint("TOPLEFT", itemsFrameUI.categoryTitle, "TOP", -140, - 35);
  itemsFrameUI.categoryEditBox:SetParent(tab);
  itemsFrameUI.categoryEditBox:SetPoint("RIGHT", itemsFrameUI.labelCategoryName, "LEFT", 280, 0);

  itemsFrameUI.labelFirstItemName:SetParent(tab);
  itemsFrameUI.labelFirstItemName:SetPoint("TOPLEFT", itemsFrameUI.labelCategoryName, "TOPLEFT", 0, - 25);
  itemsFrameUI.nameEditBox:SetParent(tab);
  itemsFrameUI.nameEditBox:SetPoint("RIGHT", itemsFrameUI.labelFirstItemName, "LEFT", 280, 0);

  itemsFrameUI.addBtn:SetParent(tab);
  itemsFrameUI.addBtn:SetPoint("TOP", itemsFrameUI.labelFirstItemName, "TOPLEFT", 140, - 30);
end

local function loadOptions(tab)
  itemsFrameUI.optionsButton:SetParent(tab);
  itemsFrameUI.optionsButton:SetPoint("TOPRIGHT", itemsFrameUI.title, "TOP", 140, - 22);

  --/************************************************/--

  itemsFrameUI.optionsTitle:SetParent(tab);
  itemsFrameUI.optionsTitle:SetPoint("TOP", itemsFrameUI.title, "TOP", 0, - 59);

  local l = itemsFrameUI.optionsTitle:GetWidth();
  itemsFrameUI.menuTitleLineLeft:SetStartPoint("TOPLEFT", centerXOffset-lineOffset, -78)
  itemsFrameUI.menuTitleLineLeft:SetEndPoint("TOPLEFT", centerXOffset-l/2 - 10, -78)
  itemsFrameUI.menuTitleLineRight:SetStartPoint("TOPLEFT", centerXOffset+l/2 + 10, -82)
  itemsFrameUI.menuTitleLineRight:SetEndPoint("TOPLEFT", centerXOffset+lineOffset + 4, -82)

  --/************************************************/--

  itemsFrameUI.btnUncheck:SetParent(tab);
  itemsFrameUI.btnUncheck:SetPoint("TOP", itemsFrameUI.optionsTitle, "TOP", 0, - 35);

  itemsFrameUI.btnClear:SetParent(tab);
  itemsFrameUI.btnClear:SetPoint("TOP", itemsFrameUI.btnUncheck, "TOP", 0, -45);

  --/************************************************/--

  itemsFrameUI.frameAlphaSlider:SetParent(tab);
  itemsFrameUI.frameAlphaSlider:SetPoint("TOP", itemsFrameUI.btnClear, "TOP", 0, -60);

  itemsFrameUI.frameAlphaSliderValue:SetParent(tab);
  itemsFrameUI.frameAlphaSliderValue:SetPoint("TOP", itemsFrameUI.frameAlphaSlider, "BOTTOM", 0, 0);

  --/************************************************/--

  itemsFrameUI.frameContentAlphaSlider:SetParent(tab);
  itemsFrameUI.frameContentAlphaSlider:SetPoint("TOP", itemsFrameUI.frameAlphaSlider, "TOP", 0, -50);

  itemsFrameUI.frameContentAlphaSliderValue:SetParent(tab);
  itemsFrameUI.frameContentAlphaSliderValue:SetPoint("TOP", itemsFrameUI.frameContentAlphaSlider, "BOTTOM", 0, 0);

  --/************************************************/--

  itemsFrameUI.btnAddonOptions:SetParent(tab);
  itemsFrameUI.btnAddonOptions:SetPoint("TOP", itemsFrameUI.frameContentAlphaSlider, "TOP", 0, - 45);
end

-- loading the content (top to bottom)
local function loadTab(tab, case)
  itemsFrameUI.title:SetParent(tab);
  itemsFrameUI.title:SetPoint("TOP", tab, "TOPLEFT", centerXOffset, - 10);

  local l = itemsFrameUI.title:GetWidth()
  itemsFrameUI.titleLineLeft:SetParent(tab)
  itemsFrameUI.titleLineRight:SetParent(tab)
  itemsFrameUI.titleLineLeft:SetStartPoint("TOPLEFT", centerXOffset-lineOffset, -18)
  itemsFrameUI.titleLineLeft:SetEndPoint("TOPLEFT", centerXOffset-l/2 -10, -18)
  itemsFrameUI.titleLineRight:SetStartPoint("TOPLEFT", centerXOffset+l/2 +10, -18)
  itemsFrameUI.titleLineRight:SetEndPoint("TOPLEFT", centerXOffset+lineOffset, -18)

  itemsFrameUI.remaining:SetParent(tab);
  itemsFrameUI.remaining:SetPoint("TOPLEFT", itemsFrameUI.title, "TOP", - 140, - 30);
  itemsFrameUI.remainingNumber:SetParent(tab);
  itemsFrameUI.remainingNumber:SetPoint("LEFT", itemsFrameUI.remaining, "RIGHT", 6, 0);

  itemsFrameUI.undoButton:SetParent(tab);
  itemsFrameUI.undoButton:SetPoint("RIGHT", itemsFrameUI.categoryButton, "LEFT", 2, 0);

  -- loading the "add a new category" menu
  loadAddACategory(tab);

  -- loading the "options" menu
  loadOptions(tab);

  -- loading the bottom line at the correct place (a bit special)
  itemsFrameUI.lineBottom:SetParent(tab);

  -- and the menu title lines (a bit complicated too)
  itemsFrameUI.menuTitleLineLeft:SetParent(tab)
  itemsFrameUI.menuTitleLineRight:SetParent(tab)
  if (addACategoryClosed and optionsClosed) then
    itemsFrameUI.menuTitleLineLeft:Hide()
    itemsFrameUI.menuTitleLineRight:Hide()
  else
    if (not addACategoryClosed) then
      l = itemsFrameUI.categoryTitle:GetWidth()
    elseif (not optionsClosed) then
      l = itemsFrameUI.optionsTitle:GetWidth()
    end
    if ((l/2 + 15) <= lineOffset) then
      itemsFrameUI.menuTitleLineLeft:SetStartPoint("TOPLEFT", centerXOffset-lineOffset, -78)
      itemsFrameUI.menuTitleLineLeft:SetEndPoint("TOPLEFT", centerXOffset-l/2 - 10, -78)
      itemsFrameUI.menuTitleLineRight:SetStartPoint("TOPLEFT", centerXOffset+l/2 + 10, -78)
      itemsFrameUI.menuTitleLineRight:SetEndPoint("TOPLEFT", centerXOffset+lineOffset, -78)
      itemsFrameUI.menuTitleLineLeft:Show()
      itemsFrameUI.menuTitleLineRight:Show()
    else
      itemsFrameUI.menuTitleLineLeft:Hide()
      itemsFrameUI.menuTitleLineRight:Hide()
    end
  end

  -- first we check which one of the buttons is pressed (if there is one) for pre-processing something
  if (addACategoryClosed) then -- if the creation of new categories is closed
    -- we hide every component of the "add a new category"
    for _, v in pairs(addACategoryItems) do
      v:Hide();
    end
  end

  if (optionsClosed) then -- if the options menu is closed
    -- then we hide every component of the "options"
    for _, v in pairs(optionsItems) do
      v:Hide();
    end
  end

  -- then we decide where to place the bottom line
  if (addACategoryClosed) then -- if the creation of new categories is closed
    if (optionsClosed) then -- if the options menu is closed too
       -- we place the line just below the buttons
      itemsFrameUI.lineBottom:SetStartPoint("TOPLEFT", centerXOffset-lineOffset, -78)
      itemsFrameUI.lineBottom:SetEndPoint("TOPLEFT", centerXOffset+lineOffset, -78)
    else
      -- or else we show and adapt the height of every component of the "options"
      local height = 0;
      for _, v in pairs(optionsItems) do
        v:Show();
        height = height + (select(5, v:GetPoint()));
      end

      -- and show the line below them
      itemsFrameUI.lineBottom:SetStartPoint("TOPLEFT", centerXOffset-lineOffset, height - 62)
      itemsFrameUI.lineBottom:SetEndPoint("TOPLEFT", centerXOffset+lineOffset, height - 62)
    end
  else
    -- or else we show and adapt the height of every component of the "add a category"
    local height = 0;
    for _, v in pairs(addACategoryItems) do
      v:Show();
      height = height + (select(5, v:GetPoint()));
    end

    -- and show the line below the elements of the "add a new category"
    itemsFrameUI.lineBottom:SetStartPoint("TOPLEFT", centerXOffset-lineOffset, height - 62)
    itemsFrameUI.lineBottom:SetEndPoint("TOPLEFT", centerXOffset+lineOffset, height - 62)
  end

  -- Nothing label:
  itemsFrameUI.nothingLabel:SetParent(tab);
  if (next(case) ~= nil) then -- if there is something to show in the tab we're in
    itemsFrameUI.nothingLabel:Hide();
  else
    itemsFrameUI.nothingLabel:SetPoint("TOP", itemsFrameUI.lineBottom, "TOP", 0, - 20); -- to correctly center this text on diffent screen sizes
    itemsFrameUI.nothingLabel:Show();
  end

  itemsFrameUI.dummyLabel:SetParent(tab);
  itemsFrameUI.dummyLabel:SetPoint("TOPLEFT", itemsFrameUI.lineBottom, "TOPLEFT", - 35, - 20);

  -- generating all of the content (items, checkboxes, editboxes, category labels...)
  generateTab(tab, case);
end

----------------------------

local function generateAddACategory()
  itemsFrameUI.categoryButton = CreateFrame("Button", "categoryButton", itemsFrameUI, "CategoryButton");
  itemsFrameUI.categoryButton.tooltip = L["Add a new category"];
  itemsFrameUI.categoryButton:SetScript("onClick", function(self)
    optionsClosed = true;
    addACategoryClosed = not addACategoryClosed;
    Tab_OnClick(_G[NysTDL.db.profile.lastLoadedTab]); -- we reload the frame to display the changes
  end);

  --/************************************************/--

  itemsFrameUI.categoryTitle = config:CreateNoPointsLabel(itemsFrameUI, nil, string.format("|cff%s%s|r", config:RGBToHex(config.database.theme), "/ "..L["Add a new category"].." \\"));
  table.insert(addACategoryItems, itemsFrameUI.categoryTitle);

  --/************************************************/--

  itemsFrameUI.labelCategoryName = itemsFrameUI:CreateFontString(nil); -- info label 2
  itemsFrameUI.labelCategoryName:SetFontObject("GameFontHighlightLarge");
  itemsFrameUI.labelCategoryName:SetText(L["Category name:"]);
  table.insert(addACategoryItems, itemsFrameUI.labelCategoryName);

  itemsFrameUI.categoryEditBox = CreateFrame("EditBox", nil, itemsFrameUI, "InputBoxTemplate"); -- edit box to put the new category name
  local l = config:CreateNoPointsLabel(itemsFrameUI, nil, itemsFrameUI.labelCategoryName:GetText());
  itemsFrameUI.categoryEditBox:SetSize(280 - l:GetWidth() - 20, 30);
  itemsFrameUI.categoryEditBox:SetAutoFocus(false);
  itemsFrameUI.categoryEditBox:SetScript("OnKeyDown", function(self, key) if (key == "TAB") then itemsFrameUI.nameEditBox:SetFocus() end end) -- to switch easily between the two edit boxes
  itemsFrameUI.categoryEditBox:SetScript("OnEnterPressed", addCategory); -- if we press enter, it's like we clicked on the add button
  table.insert(addACategoryItems, itemsFrameUI.categoryEditBox);

  itemsFrameUI.labelFirstItemName = itemsFrameUI:CreateFontString(nil); -- info label 3
  itemsFrameUI.labelFirstItemName:SetFontObject("GameFontHighlightLarge");
  itemsFrameUI.labelFirstItemName:SetText(L["1st item name:"]);
  table.insert(addACategoryItems, itemsFrameUI.labelFirstItemName);

  itemsFrameUI.nameEditBox = CreateFrame("EditBox", nil, itemsFrameUI, "InputBoxTemplate"); -- edit box tp put the name of the first item
  l = config:CreateNoPointsLabel(itemsFrameUI, nil, itemsFrameUI.labelFirstItemName:GetText());
  itemsFrameUI.nameEditBox:SetSize(280 - l:GetWidth() - 20, 30);
  itemsFrameUI.nameEditBox:SetAutoFocus(false);
  itemsFrameUI.nameEditBox:SetScript("OnKeyDown", function(self, key) if (key == "TAB") then itemsFrameUI.categoryEditBox:SetFocus() end end)
  itemsFrameUI.nameEditBox:SetScript("OnEnterPressed", addCategory); -- if we press enter, it's like we clicked on the add button
  table.insert(addACategoryItems, itemsFrameUI.nameEditBox);

  itemsFrameUI.addBtn = config:CreateTransparentButton("addButton", itemsFrameUI, 35, L["Add category"]);
  itemsFrameUI.addBtn:SetScript("onClick", addCategory);
  table.insert(addACategoryItems, itemsFrameUI.addBtn);
end

local function generateOptions()
  itemsFrameUI.optionsButton = CreateFrame("Button", "optionsButton", itemsFrameUI, "OptionsButton");
  itemsFrameUI.optionsButton.tooltip = L["Frame options"];
  itemsFrameUI.optionsButton:SetScript("onClick", function(...)
    addACategoryClosed = true;
    optionsClosed = not optionsClosed;
    Tab_OnClick(_G[NysTDL.db.profile.lastLoadedTab]); -- we reload the frame to display the changes
  end);

  --/************************************************/--

  itemsFrameUI.optionsTitle = config:CreateNoPointsLabel(itemsFrameUI, nil, string.format("|cff%s%s|r", config:RGBToHex(config.database.theme), "/ "..L["Frame options"].." \\"));
  table.insert(optionsItems, itemsFrameUI.optionsTitle);

  --/************************************************/--

  itemsFrameUI.btnUncheck = config:CreateTransparentButton("uncheckButton", itemsFrameUI, 35, L["Uncheck tab"]);
  itemsFrameUI.btnUncheck:SetScript("onClick", function(self)
    local tabName = self:GetParent():GetName();
    itemsFrame:ResetBtns(tabName);
  end);
  table.insert(optionsItems, itemsFrameUI.btnUncheck);

  itemsFrameUI.btnClear = config:CreateTransparentButton("clearButton", itemsFrameUI, 35, L["Clear tab"]);
  itemsFrameUI.btnClear:SetScript("onClick", function(self)
    local tabName = self:GetParent():GetName();
    itemsFrame:ClearTab(tabName);
  end);
  table.insert(optionsItems, itemsFrameUI.btnClear);

  --/************************************************/--

  itemsFrameUI.frameAlphaSlider = CreateFrame("Slider", "frameAlphaSlider", itemsFrameUI, "OptionsSliderTemplate");
  itemsFrameUI.frameAlphaSlider:SetWidth(200);
  -- itemsFrameUI.frameAlphaSlider:SetHeight(17);
  -- itemsFrameUI.frameAlphaSlider:SetOrientation('HORIZONTAL');

  itemsFrameUI.frameAlphaSlider:SetMinMaxValues(0, 100);
  itemsFrameUI.frameAlphaSlider:SetValue(NysTDL.db.profile.frameAlpha);
  itemsFrameUI.frameAlphaSlider:SetValueStep(1);
  itemsFrameUI.frameAlphaSlider:SetObeyStepOnDrag(true);

  itemsFrameUI.frameAlphaSlider.tooltipText = L["Change the background opacity"]; --Creates a tooltip on mouseover.
  _G[itemsFrameUI.frameAlphaSlider:GetName() .. 'Low']:SetText((select(1,itemsFrameUI.frameAlphaSlider:GetMinMaxValues()))..'%'); --Sets the left-side slider text (default is "Low").
  _G[itemsFrameUI.frameAlphaSlider:GetName() .. 'High']:SetText((select(2,itemsFrameUI.frameAlphaSlider:GetMinMaxValues()))..'%'); --Sets the right-side slider text (default is "High").
  _G[itemsFrameUI.frameAlphaSlider:GetName() .. 'Text']:SetText(L["Frame opacity"]); --Sets the "title" text (top-centre of slider).
  itemsFrameUI.frameAlphaSlider:SetScript("OnValueChanged", FrameAlphaSlider_OnValueChanged);
  table.insert(optionsItems, itemsFrameUI.frameAlphaSlider);

  itemsFrameUI.frameAlphaSliderValue = itemsFrameUI.frameAlphaSlider:CreateFontString("frameAlphaSliderValue"); -- the font string to see the current value
  itemsFrameUI.frameAlphaSliderValue:SetFontObject("GameFontNormalSmall");
  itemsFrameUI.frameAlphaSliderValue:SetText(itemsFrameUI.frameAlphaSlider:GetValue());
  table.insert(optionsItems, itemsFrameUI.frameAlphaSliderValue);

  --/************************************************/--

  itemsFrameUI.frameContentAlphaSlider = CreateFrame("Slider", "frameContentAlphaSlider", itemsFrameUI, "OptionsSliderTemplate");
  itemsFrameUI.frameContentAlphaSlider:SetWidth(200);
  -- itemsFrameUI.frameContentAlphaSlider:SetHeight(17);
  -- itemsFrameUI.frameContentAlphaSlider:SetOrientation('HORIZONTAL');

  itemsFrameUI.frameContentAlphaSlider:SetMinMaxValues(60, 100);
  itemsFrameUI.frameContentAlphaSlider:SetValue(NysTDL.db.profile.frameContentAlpha);
  itemsFrameUI.frameContentAlphaSlider:SetValueStep(1);
  itemsFrameUI.frameContentAlphaSlider:SetObeyStepOnDrag(true);

  itemsFrameUI.frameContentAlphaSlider.tooltipText = L["Change the opacity for texts, buttons and other elements"]; --Creates a tooltip on mouseover.
  _G[itemsFrameUI.frameContentAlphaSlider:GetName() .. 'Low']:SetText((select(1,itemsFrameUI.frameContentAlphaSlider:GetMinMaxValues()))..'%'); --Sets the left-side slider text (default is "Low").
  _G[itemsFrameUI.frameContentAlphaSlider:GetName() .. 'High']:SetText((select(2,itemsFrameUI.frameContentAlphaSlider:GetMinMaxValues()))..'%'); --Sets the right-side slider text (default is "High").
  _G[itemsFrameUI.frameContentAlphaSlider:GetName() .. 'Text']:SetText(L["Frame content opacity"]); --Sets the "title" text (top-centre of slider).
  itemsFrameUI.frameContentAlphaSlider:SetScript("OnValueChanged", FrameContentAlphaSlider_OnValueChanged);
  table.insert(optionsItems, itemsFrameUI.frameContentAlphaSlider);

  itemsFrameUI.frameContentAlphaSliderValue = itemsFrameUI.frameContentAlphaSlider:CreateFontString("frameContentAlphaSliderValue"); -- the font string to see the current value
  itemsFrameUI.frameContentAlphaSliderValue:SetFontObject("GameFontNormalSmall");
  itemsFrameUI.frameContentAlphaSliderValue:SetText(itemsFrameUI.frameContentAlphaSlider:GetValue());
  table.insert(optionsItems, itemsFrameUI.frameContentAlphaSliderValue);

  --/************************************************/--

  itemsFrameUI.btnAddonOptions = config:CreateTransparentButton("addonOptionsButton", itemsFrameUI, 35, L["Open addon options"]);
  itemsFrameUI.btnAddonOptions:SetScript("OnClick", function() if (not NysTDL:ToggleOptions(true)) then itemsFrameUI:Hide(); end end);
  table.insert(optionsItems, itemsFrameUI.btnAddonOptions);
end

-- generating the content (top to bottom)
local function generateFrameContent()
  -- title
  itemsFrameUI.title = config:CreateNoPointsLabel(itemsFrameUI, nil, string.gsub(config.toc.title, "Ny's ", ""));
  itemsFrameUI.title:SetFontObject("GameFontNormalLarge");

  -- remaining label
  itemsFrameUI.remaining = config:CreateNoPointsLabel(itemsFrameUI, nil, L["Remaining:"]);
  itemsFrameUI.remaining:SetFontObject("GameFontNormalLarge");
  itemsFrameUI.remainingNumber = config:CreateNoPointsLabel(itemsFrameUI, nil, "...");
  itemsFrameUI.remainingNumber:SetFontObject("GameFontNormalLarge");

  -- undo button
  itemsFrameUI.undoButton = CreateFrame("Button", "undoButton", itemsFrameUI, "UndoButton");
  itemsFrameUI.undoButton.tooltip = L["Undo"];
  itemsFrameUI.undoButton:SetScript("onClick", itemsFrame.UndoRemove);

  -- add a new category button
  generateAddACategory();

  -- options button
  generateOptions();

  itemsFrameUI.titleLineLeft = config:CreateNoPointsLine(itemsFrameUI, 2, unpack(config:ThemeDownTo01(config:DimTheme(config.database.theme_yellow, 0.8))))
  itemsFrameUI.titleLineRight = config:CreateNoPointsLine(itemsFrameUI, 2, unpack(config:ThemeDownTo01(config:DimTheme(config.database.theme_yellow, 0.8))))
  itemsFrameUI.menuTitleLineLeft = config:CreateNoPointsLine(itemsFrameUI, 2, unpack(config:ThemeDownTo01(config:DimTheme(config.database.theme, 0.7))))
  itemsFrameUI.menuTitleLineRight = config:CreateNoPointsLine(itemsFrameUI, 2, unpack(config:ThemeDownTo01(config:DimTheme(config.database.theme, 0.7))))
  itemsFrameUI.lineBottom = config:CreateNoPointsLine(itemsFrameUI, 2, unpack(config:ThemeDownTo01(config:DimTheme(config.database.theme, 0.7))))

  itemsFrameUI.nothingLabel = config:CreateNothingLabel(itemsFrameUI);

  itemsFrameUI.dummyLabel = config:CreateDummy(itemsFrameUI.lineBottom, 0, 0);
end

----------------------------------
-- Creating the frame and tabs
----------------------------------

--Selecting the tab
Tab_OnClick = function(self)
  PanelTemplates_SetTab(self:GetParent(), self:GetID());

  local scrollChild = itemsFrameUI.ScrollFrame:GetScrollChild();
  if (scrollChild) then
    scrollChild:Hide();
  end

  itemsFrameUI.ScrollFrame:SetScrollChild(self.content);

  -- we update the frame before loading the tab if there are changes pending (especially in the All variable)
  ItemsFrame_Update();

  CurrentTab = self.content;

  -- Loading the good tab
  if (self:GetName() == "ToDoListUIFrameTab1") then loadTab(AllTab, All) end
  if (self:GetName() == "ToDoListUIFrameTab2") then loadTab(DailyTab, NysTDL.db.profile.itemsList["Daily"]) end
  if (self:GetName() == "ToDoListUIFrameTab3") then loadTab(WeeklyTab, NysTDL.db.profile.itemsList["Weekly"]) end

  -- we update the frame after loading the tab to refresh the display
  ItemsFrame_Update();

  NysTDL.db.profile.lastLoadedTab = self:GetName();

  self.content:Show();
end

--Creating the tabs
local function SetTabs(frame, numTabs, ...)
  frame.numTabs = numTabs;

  local contents = {};
  local frameName = frame:GetName();

  for i = 1, numTabs do
    local tab = CreateFrame("Button", frameName.."Tab"..i, frame, "CharacterFrameTabButtonTemplate");

    tab:SetID(i);
    tab:SetText(select(i, ...));
    tab:SetScript("OnClick", Tab_OnClick);

    local name = ""
    if (tab:GetName() == "ToDoListUIFrameTab1") then name = "All"
    elseif (tab:GetName() == "ToDoListUIFrameTab2") then name = "Daily"
    elseif (tab:GetName() == "ToDoListUIFrameTab3") then name = "Weekly" end
    tab.content = CreateFrame("Frame", name, itemsFrameUI.ScrollFrame);
    tab.content:SetSize(308, 1); -- y is determined by number of elements inside of it
    tab.content:Hide();

    table.insert(contents, tab.content);

    if (i == 1) then -- position
      tab:SetPoint("TOPLEFT", itemsFrameUI, "BOTTOMLEFT", 5, 2);
    else
      tab:SetPoint("TOPLEFT", _G[frameName.."Tab"..(i - 1)], "TOPRIGHT", - 14, 0);
    end
  end

  return unpack(contents);
end

function itemsFrame:ResetContent()
  -- considering I don't want to reload the UI when we change the current profile,
  -- we have to reset all the frame ourserves, so that means:

  -- 1 - having to hide everything in it (since elements don't dissapear even
  -- when we nil them, that's how wow and lua works)
  for i = 1, #All, 1 do
    checkBtn[All[i]]:Hide()
  end

  for k, i in pairs(currentDBItemsList) do
    if (k ~= "Daily" and k ~= "Weekly") then
      label[k]:Hide()
      editBox[k]:Hide()
      sbBtn[k]:Hide()
    end
  end

  -- 2 - reset every content variable to their default value
  remainingCheckAll, remainingCheckDaily, remainingCheckWeekly = 0, 0, 0;
  clearing, undoing = false, { ["clear"] = false, ["clearnb"] = 0, ["single"] = false, ["singleok"] = true};

  dontHideMePls = {};
  checkBtn = {};
  removeBtn = {};
  addBtn = {};
  label = {};
  editBox = {};
  sbBtn = {};
  labelHover = {};
  addACategoryClosed = true;
  optionsClosed = true;
end

--Frame init
function itemsFrame:Init()
  -- this one is for keeping track of the old itemsList when we reset,
  -- so that we can hide everything when we change profiles
  currentDBItemsList = NysTDL.db.profile.itemsList;

  -- we reposition the frame to match the saved variable
  local points = NysTDL.db.profile.framePos;
  itemsFrameUI:ClearAllPoints();
  itemsFrameUI:SetPoint(points.point, points.relativeTo, points.relativePoint, points.xOffset, points.yOffset);
  -- and update its elements opacity to match the saved variable
  FrameContentAlphaSlider_OnValueChanged(nil, NysTDL.db.profile.frameContentAlpha);

  -- Generating the core --
  updateAllTable();
  loadMovable();
  loadSavedVariable();

  -- Updating everything once and hiding the UI
  ItemsFrame_UpdateTime(); -- for the auto reset check (we could wait 1 sec, but nah we don't have the time man)

  -- We load the good tab
  Tab_OnClick(_G[NysTDL.db.profile.lastLoadedTab]);

  -- and we reload the saved variables needing an update
  itemsFrameUI.frameAlphaSlider:SetValue(NysTDL.db.profile.frameAlpha);
  itemsFrameUI.frameContentAlphaSlider:SetValue(NysTDL.db.profile.frameContentAlpha);
end

---Creating the main window---
function itemsFrame:CreateItemsFrame()

  itemsFrameUI = CreateFrame("Frame", "ToDoListUIFrame", UIParent);
  -- itemsFrameUI = CreateFrame("Frame", "ToDoListUIFrame", UIParent, "UIPanelDialogTemplate");
  itemsFrameUI:SetSize(340, 400);

  -- background
  itemsFrameUI:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = false, tileSize = 1, edgeSize = 10, insets = { left = 1, right = 1, top = 1, bottom = 1 }});
  itemsFrameUI:SetBackdropColor(0, 0, 0, NysTDL.db.profile.frameAlpha/100);

  -- properties
  -- itemsFrameUI:SetResizable(true);
  -- itemsFrameUI:SetMinResize(215, 200);
  itemsFrameUI:SetMovable(true);
  itemsFrameUI:SetClampedToScreen(true);
  itemsFrameUI:EnableMouse(true);

  itemsFrameUI:HookScript("OnUpdate", ItemsFrame_OnUpdate);
  itemsFrameUI:HookScript("OnMouseUp", ItemsFrame_OnMouseUp);
  itemsFrameUI:HookScript("OnShow", ItemsFrame_OnVisibilityUpdate);
  itemsFrameUI:HookScript("OnHide", ItemsFrame_OnVisibilityUpdate);

  itemsFrameUI:RegisterForDrag("LeftButton"); -- to move the frame
  itemsFrameUI:SetScript("OnDragStart", itemsFrameUI.StartMoving);
  itemsFrameUI:SetScript("OnDragStop", function() -- we save its position
    itemsFrameUI:StopMovingOrSizing()
    local points = NysTDL.db.profile.framePos
    points.point, points.relativeTo, points.relativePoint, points.xOffset, points.yOffset = itemsFrameUI:GetPoint()
  end);

  itemsFrameUI.timeSinceLastUpdate = 0;
  itemsFrameUI.timeSinceLastRefresh = 0;

  -- // CONTENT OF THE FRAME // --

  -- itemsFrameUI.descriptionEditBox = CreateFrame("ScrollFrame", nil, itemsFrameUI, "InputScrollFrameTemplate");
  -- itemsFrameUI.descriptionEditBox:SetSize(270, 80);
  -- itemsFrameUI.descriptionEditBox.EditBox:SetWidth(250);
  -- itemsFrameUI.descriptionEditBox.EditBox:SetFontObject("ChatFontNormal")
  -- itemsFrameUI.descriptionEditBox.CharCount:Hide()
  -- itemsFrameUI.descriptionEditBox.EditBox:SetText("slt")
  -- itemsFrameUI.descriptionEditBox.EditBox:SetScript("OnKeyDown", function(self, key) if (key == "TAB") then itemsFrameUI.categoryEditBox:SetFocus() end end)
  -- itemsFrameUI.descriptionEditBox.EditBox:SetScript("OnEnterPressed", function(self) print('ola') end); -- if we press enter, it's like we clicked on the add button
  -- -- itemsFrameUI.descriptionEditBox.ScrollBar:SetPoint("TOPLEFT", editboxParent, "TOPRIGHT", 0, 0);
  -- itemsFrameUI.descriptionEditBox:SetPoint("TOPLEFT", itemsFrameUI, "TOPLEFT", -400, 0);
  -- local editboxParent = itemsFrameUI.descriptionEditBox.EditBox:GetParent();

  -- generating the fixed content shared between the 3 tabs
  generateFrameContent();

  -- scroll frame
  itemsFrameUI.ScrollFrame = CreateFrame("ScrollFrame", nil, itemsFrameUI, "UIPanelScrollFrameTemplate");
  itemsFrameUI.ScrollFrame:SetPoint("TOPLEFT", itemsFrameUI, "TOPLEFT", 4, - 4);
  itemsFrameUI.ScrollFrame:SetPoint("BOTTOMRIGHT", itemsFrameUI, "BOTTOMRIGHT", - 4, 4);
  itemsFrameUI.ScrollFrame:SetClipsChildren(true);

  itemsFrameUI.ScrollFrame:SetScript("OnMouseWheel", ScrollFrame_OnMouseWheel);

  itemsFrameUI.ScrollFrame.ScrollBar:ClearAllPoints();
  itemsFrameUI.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", itemsFrameUI.ScrollFrame, "TOPRIGHT", - 12, - 38);
  itemsFrameUI.ScrollFrame.ScrollBar:SetPoint("BOTTOMRIGHT", itemsFrameUI.ScrollFrame, "BOTTOMRIGHT", - 7, 17);

  -- close button
  itemsFrameUI.closeButton = CreateFrame("Button", "closeButton", itemsFrameUI, "CloseButton");
  itemsFrameUI.closeButton:SetPoint("TOPRIGHT", itemsFrameUI, "TOPRIGHT", -1, -1);
  itemsFrameUI.closeButton:SetScript("onClick", function(self) itemsFrameUI:Hide(); end);

  -- Generating the tabs:--
  AllTab, DailyTab, WeeklyTab = SetTabs(itemsFrameUI, 3, L["All"], L["Daily"], L["Weekly"]);

  -- Initializing the frame with the current data
  itemsFrame:Init();

  itemsFrameUI:Hide();
end
