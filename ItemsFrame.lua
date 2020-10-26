-- Namespaces
local _, tdlTable = ...;
tdlTable.itemsFrame = {}; -- adds itemsFrame table to addon namespace

local config = tdlTable.config;
local itemsFrame = tdlTable.itemsFrame;

-- Variables declaration:--
local itemsFrameUI, toggleBtn;
local AllTab, DailyTab, WeeklyTab;
local remainingCheckAll, remainingCheckDaily, remainingCheckWeekly = 0, 0, 0;
local clearing, undoing = false, { ["clear"] = false, ["clearnb"] = 0, ["single"] = false, ["singleok"] = true};

local checkBtn = {};
local removeBtn = {};
local addBtn = {};
local label = {};
local editBox = {};
local labelHover = {};
local labelNewCatHover;

-- these are for code comfort (sort of)
local addACategoryItems = {}
local optionsItems = {}

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

function itemsFrame:ToggleBtn()
  -- changes the visibility of the ToDoList button
  toggleBtn:SetShown(not toggleBtn:IsShown());
  ToDoListSV.toggleBtnIsShown = toggleBtn:IsShown();
  itemsFrameUI.btnShowButton:SetChecked(ToDoListSV.toggleBtnIsShown); -- we update the state of the checkbox
end

--------------------------------------
-- Script functions
--------------------------------------
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
    elseif (config:HasItem(ToDoListSV.itemsList[tabName], checkBtn[All[i]]:GetName())) then
      if (checkBtn[All[i]]:GetChecked()) then
        uncheckedSomething = true;
      end

      checkBtn[All[i]]:SetChecked(false);
    end
  end
  ItemsFrame_Update();

  if (uncheckedSomething) then -- so that we print this message only if there was checked items before the uncheck
    if (tabName == "All") then
      config:Print("Unchecked everything!");
    else
      config:Print("Unchecked "..tabName.." tab!");
    end
  elseif (not auto) then -- we print this message only if it was the user's action that triggered this function (not the auto reset)
    config:Print("Nothing to uncheck here!");
  end
end

local function inChatIsDone(all, daily, weekly)
  -- we tell the player if he's the best c:
  if (all == 0 and remainingCheckAll ~= 0 and next(All) ~= nil) then
    config:Print("You did everything! (yay :D)");
  elseif (daily == 0 and remainingCheckDaily ~= 0 and next(ToDoListSV.itemsList["Daily"]) ~= nil) then
    config:Print("Everything's done for today!");
  elseif (weekly == 0 and remainingCheckWeekly ~= 0 and next(ToDoListSV.itemsList["Weekly"]) ~= nil) then
    config:Print("Everything's done for this week!");
  end
end

local function updateRemainingNumber()
  -- we get how many things there is left to do in every tab
  local numberAll, numberDaily, numberWeekly = 0, 0, 0;
  for i = 1, #All do
    if (not checkBtn[All[i]]:GetChecked()) then
      if (config:HasItem(ToDoListSV.itemsList["Daily"], checkBtn[All[i]]:GetName())) then
        numberDaily = numberDaily + 1;
      end
      if (config:HasItem(ToDoListSV.itemsList["Weekly"], checkBtn[All[i]]:GetName())) then
        numberWeekly = numberWeekly + 1;
      end
      numberAll = numberAll + 1;
    end
  end

  -- we say in the chat gg if we completed everything for any tab
  inChatIsDone(numberAll, numberDaily, numberWeekly);

  -- we update the number of remaining things to do for the current tab
  local tab = itemsFrameUI.remaining:GetParent();
  if (tab == AllTab) then
    itemsFrameUI.remaining:SetText("Remaining: ".."|cff00ffb3"..numberAll.."|r");
  elseif (tab == DailyTab) then
    itemsFrameUI.remaining:SetText("Remaining: ".."|cff00ffb3"..numberDaily.."|r");
  elseif (tab == WeeklyTab) then
    itemsFrameUI.remaining:SetText("Remaining: ".."|cff00ffb3"..numberWeekly.."|r");
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
      checkBtn[All[i]].text:SetTextColor(1, 0.85, 0);
    end
  end
end

-- Saved variable functions:

local function loadSavedVariable()
  -- checks all the saved checked items
  for i = 1, #All do
    if (config:HasItem(ToDoListSV.checkedButtons, checkBtn[All[i]]:GetName())) then
      checkBtn[All[i]]:SetChecked(true);
    end
  end
end

local function saveSavedVariable()
  -- we update the checked items table
  for i = 1, #All do
    local isPresent, pos = config:HasItem(ToDoListSV.checkedButtons, checkBtn[All[i]]:GetName());

    if (checkBtn[All[i]]:GetChecked() and not isPresent) then
      table.insert(ToDoListSV.checkedButtons, checkBtn[All[i]]:GetName());
    end

    if (not checkBtn[All[i]]:GetChecked() and isPresent) then
      table.remove(ToDoListSV.checkedButtons, pos);
    end
  end
end

local function autoReset()
  if time() > ToDoListSV.autoReset["Weekly"] then
    ToDoListSV.autoReset["Daily"] = config:GetSecondsToReset().daily;
    ToDoListSV.autoReset["Weekly"] = config:GetSecondsToReset().weekly;
    itemsFrame:ResetBtns("Daily", true);
    itemsFrame:ResetBtns("Weekly", true);
  elseif time() > ToDoListSV.autoReset["Daily"] then
    ToDoListSV.autoReset["Daily"] = config:GetSecondsToReset().daily;
    itemsFrame:ResetBtns("Daily", true);
  end
end

-- Items modifications
local function updateAllTable()
  All = {}
  -- Completing the All table
  for k, val in pairs(ToDoListSV.itemsList) do
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
        local isPresent, pos = config:HasItem(ToDoListSV.checkedButtons, checkBtn[name]:GetName());
        if (checked and isPresent) then
          table.remove(ToDoListSV.checkedButtons, pos);
        end

        checkBtn[name]:Hide(); -- get out of my view mate
        removeBtn[name] = nil;
        checkBtn[name] = nil;
      end

      Tab_OnClick(_G[ToDoListSV.lastLoadedTab]); -- we reload the tab to instantly display the changes
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
        label[cat] = config:CreateNoPointsLabel(itemsFrameUI, cat, tostring(cat.." :"));
        editBox[cat] = config:CreateNoPointsLabelEditBox(cat);
        editBox[cat]:SetScript("OnEnterPressed", function(self) itemsFrame:AddItem(addBtn[self:GetName()]) end); -- if we press enter, it's like we clicked on the add button
        addBtn[cat] = config:CreateAddButton(editBox[cat]);
        addBtn[cat]:SetScript("OnClick", function(self) itemsFrame:AddItem(self) end);
      end

      Tab_OnClick(_G[ToDoListSV.lastLoadedTab]); -- we reload the tab to instantly display the changes
    end
  end
end

local function addCategory()
  -- the big function to add categories

  local db = {}
  db.cat = itemsFrameUI.categoryEditBox:GetText();

  if (db.cat == "") then
    config:Print("Please enter a category name!")
    return;
  elseif (db.cat == "Weekly" or db.cat == "weekly" or db.cat == "Daily" or db.cat == "daily") then
    config:Print("The category name cannot be daily or weekly, there are tabs for that!")
    return;
  end

  local l = config:CreateNoPointsLabel(itemsFrameUI, nil, db.cat);
  if (l:GetWidth() > 220) then
    config:Print("This categoty name is too big!")
    return;
  end

  db.name = itemsFrameUI.nameEditBox:GetText();
  if (db.name == "") then
    config:Print("Please enter the name of the item!")
    return;
  end

  local l = config:CreateNoPointsLabel(itemsFrameUI, nil, db.name);
  if (l:GetWidth() > 230) then
    config:Print("This item name is too big!")
    return;
  end

  db.case = itemsFrameUI.labelAddACategory:GetParent():GetName();
  db.checked = false;

  itemsFrameUI.categoryEditBox:SetText("");
  itemsFrameUI.nameEditBox:SetText("");
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
    if (l:GetWidth() > 240) then -- is it too big?
      config:Print("This item name is too big!")
      return;
    end

    self:GetParent():SetText(""); -- we clear the editbox
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

    hasKey = config:HasKey(ToDoListSV.itemsList, cat);
    if (not hasKey) then ToDoListSV.itemsList[cat] = {}; new = true; end -- that means we'll be adding something to a new category, so we create the table to hold all theses shiny new items

    if (case == nil) then
      isPresent0 = (select(1, config:HasItem(ToDoListSV.itemsList[cat], name)));-- does it already exists in the typed category?
    else
      isPresent0 = (select(1, config:HasItem(ToDoListSV.itemsList[case], name)));-- does it already exists in Daily/Weekly?
      isPresent3 = (select(1, config:HasItem(ToDoListSV.itemsList[cat], name)));-- does it already exists in the typed category?
      if (isPresent1 and not isPresent3) then -- if it already exists but not in this category
        addResult = {"This item name already exists!", false};
        stop = true;
      end
    end

    if (not stop) then
      if (not isPresent0) then
        if (case == "Daily") then
          isPresent2 = (select(1, config:HasItem(ToDoListSV.itemsList["Weekly"], name)));
        elseif (case == "Weekly") then
          isPresent2 = (select(1, config:HasItem(ToDoListSV.itemsList["Daily"], name)));
        else
          stop = true;
          if (not isPresent1) then
            table.insert(ToDoListSV.itemsList[cat], name);
            addResult = {"\""..name.."\" added to "..cat.."! (\'All\' tab item)", true};
          else
            addResult = {"This item name already exists!", false};
          end
        end
        if (not stop) then
          if (not isPresent1) then
            table.insert(ToDoListSV.itemsList[cat], name);
            table.insert(ToDoListSV.itemsList[case], name);
            addResult = {"\""..name.."\" added to "..cat.. "! (" ..case.. " item)", true};
          elseif (not isPresent2) then
            table.insert(ToDoListSV.itemsList[case], name);
            addResult = {"\""..name.."\" added to "..cat.. "! (" ..case.." item)", true};
          else
            addResult = {"No item can be daily and weekly!", false};
          end
        end
      else
        addResult = {"This item is already here in this category!", false};
      end
    end
  else
    addResult = {"Please enter the name of the item!", false};
  end

  if (new and not addResult[2]) then -- if we didn't add anything and it was supposed to create a new category, we cancel our move and nil this false new empty category
    ToDoListSV.itemsList[cat] = nil;
  end

  -- okay so we print only if we're not in a clear undo process / single undo process but failed
  if (undoing["single"]) then undoing["singleok"] = addResult[2]; end
  if (not undoing["clear"] and not (undoing["single"] and not undoing["singleok"])) then config:Print(addResult[1]);
  elseif (addResult[2]) then undoing["clearnb"] = undoing["clearnb"] + 1; end

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
  table.remove(ToDoListSV.itemsList[cat], (select(2, config:HasItem(ToDoListSV.itemsList[cat], name))));
  -- Daily part
  isPresent, pos = config:HasItem(ToDoListSV.itemsList["Daily"], name);
  if (isPresent) then
    db.case = "Daily";
    table.remove(ToDoListSV.itemsList["Daily"], pos);
  end
  -- Weekly part
  isPresent, pos = config:HasItem(ToDoListSV.itemsList["Weekly"], name);
  if (isPresent) then
    db.case = "Weekly";
    table.remove(ToDoListSV.itemsList["Weekly"], pos);
  end

  if (not clearing) then config:Print("\""..name.."\" removed!"); end
  modif = true;

  table.insert(ToDoListSV.undoTable, db);

  refreshTab(case, name, "Remove", modif, db.checked);
end

function itemsFrame:ClearTab(tabName)
  if (tabName == nil) then tabName = "All"; end

  local items = {};
  if (tabName == "All") then items = All; end
  if (tabName == "Daily") then items = ToDoListSV.itemsList["Daily"]; end
  if (tabName == "Weekly") then items = ToDoListSV.itemsList["Weekly"]; end

  if (next(items) ~= nil) then
    -- we start the clear
    clearing = true;

    -- we keep in mind what tab we were on when we started the clear (just so that we come back to it after the job is done)
    local last = ToDoListSV.lastLoadedTab;

    -- we now go throught each of the tabs (weekly / daily / all) successively to remove every item there are, and in their correct tabs
    local nb = #items; -- but before (if we want to undo it) we keep in mind how many items there were

    Tab_OnClick(_G["ToDoListUIFrameTab1"]); -- we put ourselves in the All tab so that evey item is loaded

    for k, v in pairs(removeBtn) do
      if (config:HasItem(items, v:GetParent():GetName())) then -- if the item is in the tab we want to clear
        itemsFrame:RemoveItem(v);
      end
    end

    table.insert(ToDoListSV.undoTable, nb);

    -- we refresh and go back to the tab we were on
    Tab_OnClick(_G[last]);

    clearing = false;
    config:Print("Clear succesful! ("..tabName.." tab, " .. nb .. " items)");
  else
    config:Print("Nothing to clear here!");
  end
end

function itemsFrame:UndoRemove()
  -- function to undo the last removes we did
  if (next(ToDoListSV.undoTable)) then -- if there's something to undo
    if (type(ToDoListSV.undoTable[#ToDoListSV.undoTable]) ~= "table") then -- if it was a clear command
      -- we start undoing it
      undoing["clear"] = true;
      local nb = ToDoListSV.undoTable[#ToDoListSV.undoTable];
      table.remove(ToDoListSV.undoTable, #ToDoListSV.undoTable);
      for i = 1, nb do
        itemsFrame:AddItem(nil, ToDoListSV.undoTable[#ToDoListSV.undoTable]);
        table.remove(ToDoListSV.undoTable, #ToDoListSV.undoTable);
      end
      config:Print("Clear undo succesful! (" .. undoing["clearnb"] .. " items added back)");
      undoing["clearnb"] = 0;
      undoing["clear"] = false;
    else -- if it was a simple remove
      undoing["single"] = true;
      itemsFrame:AddItem(nil, ToDoListSV.undoTable[#ToDoListSV.undoTable]);
      table.remove(ToDoListSV.undoTable, #ToDoListSV.undoTable);
      local pass = undoing["singleok"];
      undoing["singleok"] = true;
      undoing["single"] = false;
      if (not pass) then itemsFrame:UndoRemove() end -- if the single undo failed (because of the user AAAAH :D) we just do it one more time
    end
  else
    config:Print("No remove/clear to undo!");
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
  autoReset();
end

local function ItemsFrame_CheckLabels()
  -- update for the labels:
  for k, i in pairs(ToDoListSV.itemsList) do
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

  -- add a category label
  if (itemsFrameUI.labelAddACategory:IsMouseOver()) then -- for the add a category label, if our mouse is over it,
    itemsFrameUI.labelAddACategory:SetTextColor(0, 0.8, 1, 1); -- we change its visual
    if (not labelNewCatHover) then
      labelNewCatHover = true;
    end
  else
    itemsFrameUI.labelAddACategory:SetTextColor(1, 1, 1, 1); -- back to the default color
    if (labelNewCatHover) then
      labelNewCatHover = false;
    end
  end
end

local function ItemsFrame_OnMouseUp()
  -- if we're here, it means we've clicked somewhere on the frame
  if (labelNewCatHover) then -- if it's the add a new category label
    ToDoListSV.optionsClosed = true;
    ToDoListSV.newCatClosed = not ToDoListSV.newCatClosed;
  elseif (next(labelHover)) then -- if we are mouse hovering one of the category labels
    local isPresent, pos = config:HasItem(ToDoListSV.closedCategories, unpack(labelHover));
    if (isPresent) then
      table.remove(ToDoListSV.closedCategories, pos); -- if it was closed, we open it
    else
      table.insert(ToDoListSV.closedCategories, tostringall(unpack(labelHover))); -- vice versa
    end
  end
  Tab_OnClick(_G[ToDoListSV.lastLoadedTab]); -- we reload the frame to display the changes
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

----------------------------
-- Frame
----------------------------

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
  for k, i in pairs(ToDoListSV.itemsList) do
    if (k ~= "Daily" and k ~= "Weekly") then
      label[k] = config:CreateNoPointsLabel(itemsFrameUI, k, tostring(k.." :"));
      editBox[k] = config:CreateNoPointsLabelEditBox(k);
      editBox[k]:SetScript("OnEnterPressed", function(self) itemsFrame:AddItem(addBtn[self:GetName()]) end); -- if we press enter, it's like we clicked on the add button
      addBtn[k] = config:CreateAddButton(editBox[k]);
      addBtn[k]:SetScript("OnClick", function(self) itemsFrame:AddItem(self) end);
    end
  end
end

-- boom
local function loadCategories(tab, category, categoryLabel, constraint, catName, lastData)
  if (lastData == nil) then -- doing that only one time
    lastData = nil;
    for i = 1, #All do
      checkBtn[All[i]]:Hide();
      removeBtn[All[i]]:Hide();
    end
  end
  categoryLabel:Hide();
  editBox[categoryLabel:GetName()]:Hide();

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

  if (config:HasAtLeastOneItem(All, category)) then -- litterally
    -- category label
    if (lastData == nil) then
      lastLabel = itemsFrameUI.dummyLabel;
      l = 0;
    else
      lastLabel = lastData["categoryLabel"];
      if ((select(1, config:HasItem(ToDoListSV.closedCategories, lastData["catName"])))) then
        l = 1;
      else
        l = #lastData["category"] + 1;
      end
    end

    if (l == 0) then m = 0; else m = 1; end -- just for a proper clean height
    categoryLabel:SetParent(tab);
    categoryLabel:SetPoint("TOPLEFT", lastLabel, "TOPLEFT", 0, (-l * 22) - (m * 5)); -- here
    categoryLabel:Show();

    if (not (select(1, config:HasItem(ToDoListSV.closedCategories, catName)))) then -- if the category is opened, we display all of its items
      -- edit box
      editBox[categoryLabel:GetName()]:SetParent(tab);
      editBox[categoryLabel:GetName()]:SetPoint("LEFT", categoryLabel, "RIGHT", 10, 0);

      local x = (categoryLabel:GetWidth());
      if (x + 120 > 270) then
        editBox[categoryLabel:GetName()]:SetWidth(270 - x);
      else
        editBox[categoryLabel:GetName()]:SetPoint("LEFT", categoryLabel, "LEFT", 160, 0);
      end

      editBox[categoryLabel:GetName()]:Show();

      -- checkboxes
      local buttonsLength = 0;
      for i = 1, #All do
        if ((select(1, config:HasItem(category, checkBtn[All[i]]:GetName())))) then
          buttonsLength = buttonsLength + 1;

          checkBtn[All[i]]:SetParent(tab);
          checkBtn[All[i]]:SetPoint("TOPLEFT", categoryLabel, "TOPLEFT", 30, - 22 * buttonsLength + 5);

          checkBtn[All[i]]:Show();
          removeBtn[All[i]]:Show();
        end
      end
    else -- even though we don't display them, we still need to move them to the right tab
      -- edit box
      editBox[categoryLabel:GetName()]:SetParent(tab);
      editBox[categoryLabel:GetName()]:SetPoint("LEFT", categoryLabel, "RIGHT", 10, 0);
      -- checkboxes
      local buttonsLength = 0;
      for i = 1, #All do
        if ((select(1, config:HasItem(category, checkBtn[All[i]]:GetName())))) then
          buttonsLength = buttonsLength + 1;

          checkBtn[All[i]]:SetParent(tab);
          checkBtn[All[i]]:SetPoint("TOPLEFT", categoryLabel, "TOPLEFT", 30, - 22 * buttonsLength + 5);
        end
      end
    end

  else
    if (not next(ToDoListSV.itemsList[catName])) then -- if there is no more item in a category, we delete the corresponding elements
      ToDoListSV.itemsList[catName] = nil;
      addBtn[categoryLabel:GetName()] = nil;
      editBox[categoryLabel:GetName()] = nil;
      label[categoryLabel:GetName()] = nil;
      isPresent, pos = config:HasItem(ToDoListSV.closedCategories, catName); -- we verify if it was a closed category (can happen with the /tdl clear command)
      if (isPresent) then
        table.remove(ToDoListSV.closedCategories, pos);
      end
    end
    categoryLabel:SetParent(tab);
    categoryLabel:SetPoint("TOPLEFT", itemsFrameUI, "TOPLEFT", 0, 50); -- we place that invisible-but-still-here label out of our way
    return lastData; -- if we are here, lastData shall not be changed or there will be consequences! (so we end the function prematurely)
  end

  lastData = {
    ["tab"] = tab,
    ["category"] = category,
    ["categoryLabel"] = categoryLabel,
    ["constraint"] = constraint,
    ["catName"] = catName,
  }
  return lastData;
end

-------------------------------------------------------------------------------------------
-- Contenting:<3 --------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

-- generating the content
local function generateTab(tab, case)
  -- We sort all of the categories in alphabetical order
  local tempTable = {}
  for t in pairs(ToDoListSV.itemsList) do table.insert(tempTable, t) end
  table.sort(tempTable);

  -- we load everything
  local lastData = nil;
  for _, n in pairs(tempTable) do
    if (n ~= "Daily" and n ~= "Weekly") then
      lastData = loadCategories(tab, ToDoListSV.itemsList[n], label[n], case, n, lastData);
    end
  end
end

local function loadAddACategory(tab)
  itemsFrameUI.labelAddACategory:SetParent(tab);
  itemsFrameUI.labelAddACategory:SetPoint("TOPLEFT", itemsFrameUI.lineTop, "TOPLEFT", 40, - 35);

  itemsFrameUI.labelCategoryName:SetParent(tab);
  itemsFrameUI.labelCategoryName:SetPoint("TOPLEFT", itemsFrameUI.labelAddACategory, "TOPLEFT", - 65, - 30);
  itemsFrameUI.categoryEditBox:SetParent(tab);
  itemsFrameUI.categoryEditBox:SetPoint("RIGHT", itemsFrameUI.labelCategoryName, "RIGHT", 150, 0);

  itemsFrameUI.labelFirstItemName:SetParent(tab);
  itemsFrameUI.labelFirstItemName:SetPoint("TOPLEFT", itemsFrameUI.labelCategoryName, "TOPLEFT", 0, - 25);
  itemsFrameUI.nameEditBox:SetParent(tab);
  itemsFrameUI.nameEditBox:SetPoint("RIGHT", itemsFrameUI.labelFirstItemName, "RIGHT", 150, 0);

  itemsFrameUI.lineBottom:SetParent(tab);
  if (ToDoListSV.newCatClosed) then -- if the creation of new categories is closed
    -- we hide and adapt the height of every component
    for _, v in pairs(addACategoryItems) do
      v:Hide();
    end

    if (ToDoListSV.optionsClosed) then itemsFrameUI.lineBottom:SetPoint("TOPLEFT", itemsFrameUI.labelAddACategory, "TOPLEFT", - 40, - 25); end
  else
    -- or else we show and adapt the height of every component again
    local height = 0;
    for _, v in pairs(addACategoryItems) do
      v:Show();
      height = height + (select(5, v:GetPoint()));
    end

    itemsFrameUI.lineBottom:SetPoint("TOPLEFT", itemsFrameUI.labelAddACategory, "TOPLEFT", - 40, height - addACategoryItems[#addACategoryItems]:GetHeight() + 10);
  end
end

local function loadOptions(tab)
  itemsFrameUI.optionsButton:SetParent(tab);
  itemsFrameUI.optionsButton:SetPoint("TOPLEFT", itemsFrameUI.lineTop, "TOPLEFT", 215, - 28);

  itemsFrameUI.labelWeeklyTime:SetParent(tab);
  itemsFrameUI.labelWeeklyTime:SetPoint("TOPLEFT", itemsFrameUI.labelAddACategory, "TOPLEFT", - 65, - 40);

  itemsFrameUI.ddWeeklyDay:SetParent(tab);
  itemsFrameUI.ddWeeklyDay:SetPoint("TOPLEFT", itemsFrameUI.labelWeeklyTime, "TOPLEFT", 155, 5)

  itemsFrameUI.labelDailyTime:SetParent(tab);
  itemsFrameUI.labelDailyTime:SetPoint("TOPLEFT", itemsFrameUI.labelWeeklyTime, "TOPLEFT", 0, - 30);

  itemsFrameUI.ddDailyHour:SetParent(tab);
  itemsFrameUI.ddDailyHour:SetPoint("TOPLEFT", itemsFrameUI.labelDailyTime, "TOPLEFT", 155, 5)

  itemsFrameUI.labelChatMessages:SetParent(tab);
  itemsFrameUI.labelChatMessages:SetPoint("TOPLEFT", itemsFrameUI.labelDailyTime, "TOPLEFT", 0, - 30);

  itemsFrameUI.btnChatMessages:SetParent(tab);
  itemsFrameUI.btnChatMessages:SetPoint("TOPLEFT", itemsFrameUI.labelChatMessages, "TOPLEFT", 250, 5);

  itemsFrameUI.labelShowButton:SetParent(tab);
  itemsFrameUI.labelShowButton:SetPoint("TOPLEFT", itemsFrameUI.labelChatMessages, "TOPLEFT", 0, - 30);

  itemsFrameUI.btnShowButton:SetParent(tab);
  itemsFrameUI.btnShowButton:SetPoint("TOPLEFT", itemsFrameUI.labelShowButton, "TOPLEFT", 250, 5);

  itemsFrameUI.labelRememberUndo:SetParent(tab);
  itemsFrameUI.labelRememberUndo:SetPoint("TOPLEFT", itemsFrameUI.labelShowButton, "TOPLEFT", 0, - 30);

  itemsFrameUI.btnRememberUndo:SetParent(tab);
  itemsFrameUI.btnRememberUndo:SetPoint("TOPLEFT", itemsFrameUI.labelRememberUndo, "TOPLEFT", 250, 5);

  itemsFrameUI.btnUncheck:SetParent(tab);
  itemsFrameUI.btnUncheck:SetPoint("TOPLEFT", itemsFrameUI.labelRememberUndo, "TOPLEFT", 15, - 30);

  itemsFrameUI.btnClear:SetParent(tab);
  itemsFrameUI.btnClear:SetPoint("TOPLEFT", itemsFrameUI.btnUncheck, "TOPRIGHT", 20, 0);

  itemsFrameUI.lineBottom:SetParent(tab);
  if (ToDoListSV.optionsClosed) then -- if the options menu is closed
    -- we hide and adapt the height of every component
    for _, v in pairs(optionsItems) do
      v:Hide();
    end

    if (ToDoListSV.newCatClosed) then itemsFrameUI.lineBottom:SetPoint("TOPLEFT", itemsFrameUI.labelAddACategory, "TOPLEFT", - 40, - 25); end
  else
    -- or else we show and adapt the height of every component again
    local height = 0;
    for _, v in pairs(optionsItems) do
      v:Show();
      height = height + (select(5, v:GetPoint()));
    end

    itemsFrameUI.lineBottom:SetPoint("TOPLEFT", itemsFrameUI.labelAddACategory, "TOPLEFT", - 40, height - optionsItems[#optionsItems]:GetHeight() - 25);
  end
end

-- loading the content (top to bottom)
local function loadTab(tab, case)
  itemsFrameUI.remaining:SetParent(tab);
  itemsFrameUI.remaining:SetPoint("TOPLEFT", tab, "TOPLEFT", 100, - 20);
  itemsFrameUI.lineTop:SetParent(tab);
  itemsFrameUI.lineTop:SetPoint("TOPLEFT", tab, "TOPLEFT", 40, - 40);
  itemsFrameUI.undoButton:SetParent(tab);
  itemsFrameUI.undoButton:SetPoint("TOPLEFT", itemsFrameUI.lineTop, "TOPLEFT", - 5, - 28);

  -- loading the "add a new category" menu
  loadAddACategory(tab);

  -- loading the "options" menu
  loadOptions(tab);

  -- Nothing label:
  itemsFrameUI.nothingLabel:SetParent(tab);
  if (next(case) ~= nil) then -- if there is something to show in the tab we're in
    itemsFrameUI.nothingLabel:Hide();
  else
    itemsFrameUI.nothingLabel:SetPoint("CENTER", itemsFrameUI.lineBottom, "CENTER", 0, - 33); -- to correctly center this text on diffent screen sizes
    itemsFrameUI.nothingLabel:Show();
  end

  itemsFrameUI.dummyLabel:SetParent(tab);
  itemsFrameUI.dummyLabel:SetPoint("TOPLEFT", itemsFrameUI.lineBottom, "TOPLEFT", - 35, - 35);

  -- generating all of the content (items, checkboxes, editboxes, category labels...)
  generateTab(tab, case);
end

local function generateAddACategory()
  itemsFrameUI.labelAddACategory = itemsFrameUI:CreateFontString(nil); -- info label 1
  itemsFrameUI.labelAddACategory:SetFontObject("GameFontHighlightLarge");
  itemsFrameUI.labelAddACategory:SetText("Add a new category");

  itemsFrameUI.labelCategoryName = itemsFrameUI:CreateFontString(nil); -- info label 2
  itemsFrameUI.labelCategoryName:SetFontObject("GameFontHighlightLarge");
  itemsFrameUI.labelCategoryName:SetText("Category name:");
  table.insert(addACategoryItems, itemsFrameUI.labelCategoryName);

  itemsFrameUI.categoryEditBox = CreateFrame("EditBox", nil, itemsFrameUI, "InputBoxTemplate"); -- edit box to put the new category name
  itemsFrameUI.categoryEditBox:SetSize(130, 30);
  itemsFrameUI.categoryEditBox:SetAutoFocus(false);
  itemsFrameUI.categoryEditBox:SetScript("OnKeyDown", function(self, key) if (key == "TAB") then itemsFrameUI.nameEditBox:SetFocus() end end) -- to switch easily between the two edit boxes
  itemsFrameUI.categoryEditBox:SetScript("OnEnterPressed", addCategory); -- if we press enter, it's like we clicked on the add button
  table.insert(addACategoryItems, itemsFrameUI.categoryEditBox);

  itemsFrameUI.labelFirstItemName = itemsFrameUI:CreateFontString(nil); -- info label 3
  itemsFrameUI.labelFirstItemName:SetFontObject("GameFontHighlightLarge");
  itemsFrameUI.labelFirstItemName:SetText("1st item name:");
  table.insert(addACategoryItems, itemsFrameUI.labelFirstItemName);

  itemsFrameUI.nameEditBox = CreateFrame("EditBox", nil, itemsFrameUI, "InputBoxTemplate"); -- edit box tp put the name of the first item
  itemsFrameUI.nameEditBox:SetSize(130, 30);
  itemsFrameUI.nameEditBox:SetAutoFocus(false);
  itemsFrameUI.nameEditBox:SetScript("OnKeyDown", function(self, key) if (key == "TAB") then itemsFrameUI.categoryEditBox:SetFocus() end end)
  itemsFrameUI.nameEditBox:SetScript("OnEnterPressed", addCategory); -- if we press enter, it's like we clicked on the add button
  table.insert(addACategoryItems, itemsFrameUI.nameEditBox);

  itemsFrameUI.addBtn = config:CreateAddButton(itemsFrameUI.nameEditBox);
  itemsFrameUI.addBtn:SetScript("onClick", addCategory)
  --table.insert(addACategoryItems, itemsFrameUI.addBtn);
end

local function generateOptions()
  itemsFrameUI.optionsButton = CreateFrame("Button", "optionsButton", itemsFrameUI, "OptionsButton");
  itemsFrameUI.optionsButton:SetScript("onClick", function(...)
    ToDoListSV.newCatClosed = true;
    ToDoListSV.optionsClosed = not ToDoListSV.optionsClosed;
    Tab_OnClick(_G[ToDoListSV.lastLoadedTab]); -- we reload the frame to display the changes
  end);

  --/************************************************/--

  itemsFrameUI.labelWeeklyTime = itemsFrameUI:CreateFontString(nil); -- info label 1
  itemsFrameUI.labelWeeklyTime:SetFontObject("GameFontHighlightLarge");
  itemsFrameUI.labelWeeklyTime:SetText("Weekly reset day:");
  table.insert(optionsItems, itemsFrameUI.labelWeeklyTime);

  itemsFrameUI.ddWeeklyDay = CreateFrame("FRAME", "ddWeeklyDay", itemsFrameUI, "UIDropDownMenuTemplate")
  table.insert(optionsItems, itemsFrameUI.ddWeeklyDay);
  UIDropDownMenu_SetWidth(itemsFrameUI.ddWeeklyDay, 90)
  UIDropDownMenu_SetText(itemsFrameUI.ddWeeklyDay, config:GetDayByNumber(ToDoListSV.weeklyDay))

  -- Implement the function to change the weekly reset day, then refresh
  local function setWeeklyDay(self, day)
    ToDoListSV.weeklyDay = day
    ToDoListSV.autoReset["Weekly"] = config:GetSecondsToReset().weekly
    UIDropDownMenu_SetText(itemsFrameUI.ddWeeklyDay, config:GetDayByNumber(day)) -- Update the text
  end

  -- Create and bind the initialization function to the dropdown menu
  UIDropDownMenu_Initialize(itemsFrameUI.ddWeeklyDay, function(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo()

    for i = 2, 8 do
      info.func = setWeeklyDay
      info.arg1 = i ~= 8 and i or 1
      info.text = config:GetDayByNumber(info.arg1)
      info.checked = ToDoListSV.weeklyDay == info.arg1
      UIDropDownMenu_AddButton(info)
    end
  end)

  --/************************************************/--

  itemsFrameUI.labelDailyTime = itemsFrameUI:CreateFontString(nil); -- info label 2
  itemsFrameUI.labelDailyTime:SetFontObject("GameFontHighlightLarge");
  itemsFrameUI.labelDailyTime:SetText("Daily reset hour:");
  table.insert(optionsItems, itemsFrameUI.labelDailyTime);

  itemsFrameUI.ddDailyHour = CreateFrame("FRAME", "ddDailyHour", itemsFrameUI, "UIDropDownMenuTemplate")
  table.insert(optionsItems, itemsFrameUI.ddDailyHour);
  UIDropDownMenu_SetWidth(itemsFrameUI.ddDailyHour, 90)
  UIDropDownMenu_SetText(itemsFrameUI.ddDailyHour, (ToDoListSV.dailyHour > 12 and ToDoListSV.dailyHour - 12 or ToDoListSV.dailyHour) .. ' ' .. (ToDoListSV.dailyHour < 12 and "AM" or "PM"))

  -- Implement the function to change the daily reset hour, then refresh
  local function setDailyHour(self, hour)
    ToDoListSV.dailyHour = hour
    ToDoListSV.autoReset["Daily"] = config:GetSecondsToReset().daily
    ToDoListSV.autoReset["Weekly"] = config:GetSecondsToReset().weekly

    -- we update the text
    UIDropDownMenu_SetText(itemsFrameUI.ddDailyHour, (hour > 12 and hour - 12 or hour) .. ' ' .. (hour < 12 and "AM" or "PM"))

    -- Because this is called from a sub-menu, only that menu level is closed by default.
    -- Close the entire menu with this next call
    CloseDropDownMenus()
  end

  -- Create and bind the initialization function to the dropdown menu
  UIDropDownMenu_Initialize(itemsFrameUI.ddDailyHour, function(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo()

    if (level or 1) == 1 then
      -- AM group
      info.text, info.checked = "AM", ToDoListSV.dailyHour <= 12
      info.menuList, info.hasArrow = 0, true
      UIDropDownMenu_AddButton(info)
      -- PM group
      info.text, info.checked = "PM", ToDoListSV.dailyHour > 12
      info.menuList, info.hasArrow = 1, true
      UIDropDownMenu_AddButton(info)
    elseif (menuList == 0) then
      -- nested group for AM
      info.func = setDailyHour
      for i = 1, 12 do
        info.text = i .. ' ' .. "AM"
        info.arg1 = i
        info.checked = ToDoListSV.dailyHour == i
        UIDropDownMenu_AddButton(info, level)
      end
    elseif (menuList == 1) then
      -- nested group for PM
      info.func = setDailyHour
      for i = 13, 24 do
        info.text = i - 12 .. ' ' .. "PM"
        info.arg1 = i
        info.checked = ToDoListSV.dailyHour == i
        UIDropDownMenu_AddButton(info, level)
      end
    end
  end)

  --/************************************************/--

  itemsFrameUI.labelChatMessages = itemsFrameUI:CreateFontString(nil); -- info label 3
  itemsFrameUI.labelChatMessages:SetFontObject("GameFontHighlightLarge");
  itemsFrameUI.labelChatMessages:SetText("Display chat messages:");
  table.insert(optionsItems, itemsFrameUI.labelChatMessages);

  itemsFrameUI.btnChatMessages = CreateFrame("CheckButton", "ChatMessages", itemsFrameUI, "UICheckButtonTemplate");
  itemsFrameUI.btnChatMessages:SetChecked(ToDoListSV.showChatMessages);
  itemsFrameUI.btnChatMessages:SetScript("OnClick", function(self) ToDoListSV.showChatMessages = self:GetChecked(); end);
  table.insert(optionsItems, itemsFrameUI.btnChatMessages);

  --/************************************************/--

  itemsFrameUI.labelShowButton = itemsFrameUI:CreateFontString(nil); -- info label 4
  itemsFrameUI.labelShowButton:SetFontObject("GameFontHighlightLarge");
  itemsFrameUI.labelShowButton:SetText("Display ToDoList button:");
  table.insert(optionsItems, itemsFrameUI.labelShowButton);

  itemsFrameUI.btnShowButton = CreateFrame("CheckButton", "ShowButton", itemsFrameUI, "UICheckButtonTemplate");
  itemsFrameUI.btnShowButton:SetChecked(ToDoListSV.toggleBtnIsShown);
  itemsFrameUI.btnShowButton:SetScript("OnClick", itemsFrame.ToggleBtn);
  table.insert(optionsItems, itemsFrameUI.btnShowButton);

  --/************************************************/--

  itemsFrameUI.labelRememberUndo = itemsFrameUI:CreateFontString(nil); -- info label 5
  itemsFrameUI.labelRememberUndo:SetFontObject("GameFontHighlightLarge");
  itemsFrameUI.labelRememberUndo:SetText("Remember undos after reload:");
  table.insert(optionsItems, itemsFrameUI.labelRememberUndo);

  itemsFrameUI.btnRememberUndo = CreateFrame("CheckButton", "RememberUndo", itemsFrameUI, "UICheckButtonTemplate");
  itemsFrameUI.btnRememberUndo:SetChecked(ToDoListSV.rememberUndo);
  itemsFrameUI.btnRememberUndo:SetScript("OnClick", function(self) ToDoListSV.rememberUndo = self:GetChecked(); end);
  table.insert(optionsItems, itemsFrameUI.btnRememberUndo);

  --/************************************************/--

  itemsFrameUI.btnUncheck = config:CreateTransparentButton("uncheckButton", itemsFrameUI, 120, 35, "Uncheck tab");
  itemsFrameUI.btnUncheck:SetScript("onClick", function(self)
    local tabName = self:GetParent():GetName();
    itemsFrame:ResetBtns(tabName);
  end);
  table.insert(optionsItems, itemsFrameUI.btnUncheck);

  itemsFrameUI.btnClear = config:CreateTransparentButton("clearButton", itemsFrameUI, 120, 35, "Clear tab");
  itemsFrameUI.btnClear:SetScript("onClick", function(self)
    local tabName = self:GetParent():GetName();
    itemsFrame:ClearTab(tabName);
  end);
  table.insert(optionsItems, itemsFrameUI.btnClear);
end

local function generateFrameContent()
  itemsFrameUI.remaining = config:CreateNoPointsLabel(itemsFrameUI, nil, "Remaining:");
  itemsFrameUI.lineTop = config:CreateNoPointsLabel(itemsFrameUI, nil, "|cff00ccff___________________________|r");
  itemsFrameUI.undoButton = CreateFrame("Button", "undoButton", itemsFrameUI, "UndoButton");
  itemsFrameUI.undoButton:SetScript("onClick", itemsFrame.UndoRemove);

  generateAddACategory();

  generateOptions();

  itemsFrameUI.lineBottom = config:CreateLabel("TOPLEFT", itemsFrameUI, "TOPLEFT", 0, 0, "|cff00ccff___________________________|r");

  itemsFrameUI.nothingLabel = config:CreateNothingLabel(itemsFrameUI);

  itemsFrameUI.dummyLabel = config:CreateDummy(itemsFrameUI.lineBottom, 0, 0);
end

----------------------------------
-- Creating the frame and tabs
----------------------------------

--------------------------------------------------------------------
-- BIG Thanks to Mayron on YouTube for his tutorial on theses parts!
--------------------------------------------------------------------

-- Selecting the tab
Tab_OnClick = function(self)
  PanelTemplates_SetTab(self:GetParent(), self:GetID());

  local scrollChild = itemsFrameUI.ScrollFrame:GetScrollChild();
  if (scrollChild) then
    scrollChild:Hide();
  end

  itemsFrameUI.ScrollFrame:SetScrollChild(self.content);

  -- we update the frame before loading the tab if there are changes pending (especially in the All variable)
  ItemsFrame_Update();

  -- Loading the good tab
  if (self:GetName() == "ToDoListUIFrameTab1") then loadTab(AllTab, All) end
  if (self:GetName() == "ToDoListUIFrameTab2") then loadTab(DailyTab, ToDoListSV.itemsList["Daily"]) end
  if (self:GetName() == "ToDoListUIFrameTab3") then loadTab(WeeklyTab, ToDoListSV.itemsList["Weekly"]) end

  -- we update the frame after loading the tab to refresh the display
  ItemsFrame_Update();

  ToDoListSV.lastLoadedTab = self:GetName();

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

    tab.content = CreateFrame("Frame", (select(i, ...)), itemsFrameUI.ScrollFrame);
    tab.content:SetSize(308, 1); -- y is determined by number of elements
    tab.content:Hide();

    table.insert(contents, tab.content);

    if (i == 1) then -- position
      tab:SetPoint("TOPLEFT", itemsFrameUI, "BOTTOMLEFT", 5, 7);
    else
      tab:SetPoint("TOPLEFT", _G[frameName.."Tab"..(i - 1)], "TOPRIGHT", - 14, 0);
    end
  end

  return unpack(contents);
end

---Creating the main window----
function config:CreateItemsFrame()

  itemsFrameUI = CreateFrame("Frame", "ToDoListUIFrame", UIParent, "UIPanelDialogTemplate");
  itemsFrameUI:SetSize(350, 400);
  itemsFrameUI:SetPoint("CENTER");

  itemsFrameUI.Title:ClearAllPoints();
  itemsFrameUI.Title:SetFontObject("GameFontHighlight");
  itemsFrameUI.Title:SetPoint("LEFT", ToDoListUIFrameTitleBG, "LEFT", (itemsFrameUI:GetWidth() / 2) - 50, 1);
  itemsFrameUI.Title:SetText("To do list");

  --generating the fixed content shared between the 3 tabs
  generateFrameContent();

  itemsFrameUI.timeSinceLastUpdate = 0;
  itemsFrameUI.timeSinceLastRefresh = 0;

  itemsFrameUI.ScrollFrame = CreateFrame("ScrollFrame", nil, itemsFrameUI, "UIPanelScrollFrameTemplate");
  itemsFrameUI.ScrollFrame:SetPoint("TOPLEFT", ToDoListUIFrameDialogBG, "TOPLEFT", 4, - 8);
  itemsFrameUI.ScrollFrame:SetPoint("BOTTOMRIGHT", ToDoListUIFrameDialogBG, "BOTTOMRIGHT", - 3, 4);
  itemsFrameUI.ScrollFrame:SetClipsChildren(true);

  itemsFrameUI.ScrollFrame:SetScript("OnMouseWheel", ScrollFrame_OnMouseWheel);

  itemsFrameUI.ScrollFrame.ScrollBar:ClearAllPoints();
  itemsFrameUI.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", itemsFrameUI.ScrollFrame, "TOPRIGHT", - 12, - 18);
  itemsFrameUI.ScrollFrame.ScrollBar:SetPoint("BOTTOMRIGHT", itemsFrameUI.ScrollFrame, "BOTTOMRIGHT", - 7, 18);

  itemsFrameUI:SetScript("OnUpdate", ItemsFrame_OnUpdate);
  itemsFrameUI:SetScript("OnMouseUp", ItemsFrame_OnMouseUp);

  itemsFrameUI:SetMovable(true);
  itemsFrameUI:SetClampedToScreen(true);
  itemsFrameUI:EnableMouse(true);

  itemsFrameUI:RegisterForDrag("LeftButton"); -- to move the frame
  itemsFrameUI:SetScript("OnDragStart", itemsFrameUI.StartMoving);
  itemsFrameUI:SetScript("OnDragStop", itemsFrameUI.StopMovingOrSizing);

  -- Generating the tabs:--
  AllTab, DailyTab, WeeklyTab = SetTabs(itemsFrameUI, 3, "All", "Daily", "Weekly");

  -- Generating the core --
  updateAllTable();
  loadMovable();
  loadSavedVariable();

  -- Updating everything once and hiding the UI
  ItemsFrame_UpdateTime(); -- for the auto reset check (we could wait 1 sec, but nah we don't have the time man)

  -- We load the good tab
  Tab_OnClick(_G[ToDoListSV.lastLoadedTab]);

  itemsFrameUI:Hide();

  -- Creating the button to easily toggle the frame
  toggleBtn = config:CreateButton("ToDoListToggleButton", UIParent, 100, 35, "ToDoList");
  toggleBtn:SetPoint("Center", UIParent, "Center", 0, 0);

  toggleBtn:SetMovable(true);
  toggleBtn:EnableMouse(true);
  toggleBtn:SetClampedToScreen(true);
  toggleBtn:RegisterForDrag("LeftButton");
  toggleBtn:SetScript("OnDragStart", toggleBtn.StartMoving);
  toggleBtn:SetScript("OnDragStop", toggleBtn.StopMovingOrSizing);

  toggleBtn:SetScript("OnClick", itemsFrame.Toggle); -- the function the button calls when pressed
  toggleBtn:SetShown(ToDoListSV.toggleBtnIsShown);
end
