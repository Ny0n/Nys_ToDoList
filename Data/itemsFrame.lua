-- Namespaces
local _, tdlTable = ...;
tdlTable.itemsFrame = {}; -- adds itemsFrame table to addon namespace

local config = tdlTable.config;
local itemsFrame = tdlTable.itemsFrame;

-- Variables declaration --
local L = config.L;

local itemsFrameUI;
local AllTab, DailyTab, WeeklyTab, CurrentTab;

-- reset variables
local remainingCheckAll, remainingCheckDaily, remainingCheckWeekly = 0, 0, 0;
local clearing, undoing = false, { ["clear"] = false, ["clearnb"] = 0, ["single"] = false, ["singleok"] = true};

local dontHideMePls = {};
local checkBtn = {};
local removeBtn = {};
local favoriteBtn = {};
local descBtn = {};
local descFrames = {};
local addBtn = {};
local label = {};
local editBox = {};
local labelHover = {};
local categoryLabelFavsRemaining = {};
local addACategoryClosed = true;
local tabActionsClosed = true;
local optionsClosed = true;
local autoResetedThisSession = false;

-- these are for code comfort (sort of)
local addACategoryItems = {}
local tabActionsItems = {}
local frameOptionsItems = {}
local currentDBItemsList;
local categoryNameWidthMax = 220;
local itemNameWidthMax = 240;
local editBoxAddItemWidth = 270;
local centerXOffset = 165;
local lineOffset = 120;
local descFrameLevelDiff = 20;
local cursorX, cursorY, cursorDist = 0, 0, 10; -- for my special drag

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

local function FrameAlphaSlider_OnValueChanged(_, value)
  -- itemsList frame part
  NysTDL.db.profile.frameAlpha = value;
  itemsFrameUI.frameAlphaSliderValue:SetText(value);
  itemsFrameUI:SetBackdropColor(0, 0, 0, value/100);
  itemsFrameUI:SetBackdropBorderColor(1, 1, 1, value/100);
  for i = 1, 3 do
    _G["ToDoListUIFrameTab"..i.."Left"]:SetAlpha((value)/100);
    _G["ToDoListUIFrameTab"..i.."LeftDisabled"]:SetAlpha((value)/100);
    _G["ToDoListUIFrameTab"..i.."Middle"]:SetAlpha((value)/100);
    _G["ToDoListUIFrameTab"..i.."MiddleDisabled"]:SetAlpha((value)/100);
    _G["ToDoListUIFrameTab"..i.."Right"]:SetAlpha((value)/100);
    _G["ToDoListUIFrameTab"..i.."RightDisabled"]:SetAlpha((value)/100);
    _G["ToDoListUIFrameTab"..i.."HighlightTexture"]:SetAlpha((value)/100);
  end

  -- description frames part
  if (NysTDL.db.profile.affectDesc) then
    NysTDL.db.profile.descFrameAlpha = value;
  end

  value = NysTDL.db.profile.descFrameAlpha;

  for _, v in pairs(descFrames) do
    v:SetBackdropColor(0, 0, 0, value/100);
    v:SetBackdropBorderColor(1, 1, 1, value/100);
    for k, x in pairs(v.descriptionEditBox) do
      if (type(k) == "string") then
        if (string.sub(k, k:len()-2, k:len()) == "Tex") then
          x:SetAlpha(value/100)
        end
      end
    end
  end
end

local function FrameContentAlphaSlider_OnValueChanged(_, value)
  -- itemsList frame part
  NysTDL.db.profile.frameContentAlpha = value;
  itemsFrameUI.frameContentAlphaSliderValue:SetText(value);
  itemsFrameUI.ScrollFrame.ScrollBar:SetAlpha((value)/100);
  itemsFrameUI.closeButton:SetAlpha((value)/100);
  itemsFrameUI.resizeButton:SetAlpha((value)/100);
  for i = 1, 3 do
    _G["ToDoListUIFrameTab"..i.."Text"]:SetAlpha((value)/100);
    _G["ToDoListUIFrameTab"..i].content:SetAlpha((value)/100);
  end

  -- description frames part
  if (NysTDL.db.profile.affectDesc) then
    NysTDL.db.profile.descFrameContentAlpha = value;
  end

  value = NysTDL.db.profile.descFrameContentAlpha;

  for _, v in pairs(descFrames) do
    v.closeButton:SetAlpha(value/100);
    -- the title is already being cared for in the update of the desc frame
    v.descriptionEditBox.EditBox:SetAlpha(value/100);
    v.descriptionEditBox.ScrollBar:SetAlpha(value/100);
    v.resizeButton:SetAlpha(value/100);
  end
end

local function TabItemsTable(tabName)
  -- returns the saved variable corresponding to the items for 'tabName'
  if (tabName == "Daily") then
    return NysTDL.db.profile.itemsDaily;
  elseif (tabName == "Weekly") then
    return NysTDL.db.profile.itemsWeekly;
  end
  return All;
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
    elseif (config:HasItem(TabItemsTable(tabName), checkBtn[All[i]]:GetName())) then
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

function itemsFrame:CheckBtns(tabName)
  -- this function's goal is to check every item in the selected tab
  local checkedSomething = false;

  for i = 1, #All do
    if (tabName == "All") then
      if (config:HasItem(All, checkBtn[All[i]]:GetName())) then -- the All table isn't in the saved variable
        if (not checkBtn[All[i]]:GetChecked()) then
          checkedSomething = true;
        end

        checkBtn[All[i]]:SetChecked(true);
      end
    elseif (config:HasItem(TabItemsTable(tabName), checkBtn[All[i]]:GetName())) then
      if (not checkBtn[All[i]]:GetChecked()) then
        checkedSomething = true;
      end

      checkBtn[All[i]]:SetChecked(true);
    end
  end
  ItemsFrame_Update();

  if (checkedSomething) then -- so that we print this message only if there was checked items before the uncheck
    if (tabName == "All") then
      config:Print(L["Checked everything!"]);
    else
      config:Print(L["Checked %s tab!"]:format(L[tabName]));
    end
  else
    config:Print(L["Nothing to check here!"]);
  end
end

local function inChatIsDone(all, daily, weekly)
  -- we tell the player if he's the best c:
  if (all == 0 and remainingCheckAll ~= 0 and next(All) ~= nil) then
    config:Print(L["Nice job, you did everything on the list!"]);
  elseif (daily == 0 and remainingCheckDaily ~= 0 and next(NysTDL.db.profile.itemsDaily) ~= nil) then
    config:Print(L["Everything's done for today!"]);
  elseif (weekly == 0 and remainingCheckWeekly ~= 0 and next(NysTDL.db.profile.itemsWeekly) ~= nil) then
    config:Print(L["Everything's done for this week!"]);
  end
end

function itemsFrame:updateRemainingNumber()
  -- we get how many things there is left to do in every tab
  local numberAll, numberDaily, numberWeekly = 0, 0, 0;
  local numberFavAll, numberFavDaily, numberFavWeekly = 0, 0, 0;
  for i = 1, #All do
    local name = checkBtn[All[i]]:GetName();
    local isDaily = config:HasItem(NysTDL.db.profile.itemsDaily, name);
    local isWeekly = config:HasItem(NysTDL.db.profile.itemsWeekly, name);
    local isFav = config:HasItem(NysTDL.db.profile.itemsFavorite, name);

    if (not checkBtn[All[i]]:GetChecked()) then -- if the current button is not checked
      if (isDaily) then
        numberDaily = numberDaily + 1;
        if (isFav) then
          numberFavDaily = numberFavDaily + 1;
        end
      end
      if (isWeekly) then
        numberWeekly = numberWeekly + 1;
        if (isFav) then
          numberFavWeekly = numberFavWeekly + 1;
        end
      end
      numberAll = numberAll + 1;
      if (isFav) then
        numberFavAll = numberFavAll + 1;
      end
    end
  end

  -- we say in the chat gg if we completed everything for any tab
  -- (and we were not in a clear)
  if (not clearing) then inChatIsDone(numberAll, numberDaily, numberWeekly); end

  -- we update the number of remaining things to do for the current tab
  local tab = itemsFrameUI.remainingNumber:GetParent();
  local hex = config:RGBToHex({ NysTDL.db.profile.favoritesColor[1]*255, NysTDL.db.profile.favoritesColor[2]*255, NysTDL.db.profile.favoritesColor[3]*255} );
  if (tab == AllTab) then
    itemsFrameUI.remainingNumber:SetText(((numberAll > 0) and "|cffffffff" or "|cff00ff00")..numberAll.."|r "..((numberFavAll > 0) and string.format("|cff%s%s|r", hex, "("..numberFavAll..")") or ""));
  elseif (tab == DailyTab) then
    itemsFrameUI.remainingNumber:SetText(((numberDaily > 0) and "|cffffffff" or "|cff00ff00")..numberDaily.."|r "..((numberFavDaily > 0) and string.format("|cff%s%s|r", hex, "("..numberFavDaily..")") or ""));
  elseif (tab == WeeklyTab) then
    itemsFrameUI.remainingNumber:SetText(((numberWeekly > 0) and "|cffffffff" or "|cff00ff00")..numberWeekly.."|r "..((numberFavWeekly > 0) and string.format("|cff%s%s|r", hex, "("..numberFavWeekly..")") or ""));
  end
  -- same for the category label ones
  for c, _ in pairs(label) do -- for every category labels
    local nbFavCat = 0
    for _, x in pairs(NysTDL.db.profile.itemsList[c]) do -- and for every items in them
      if (config:HasItem(TabItemsTable(tab:GetName()), x)) then -- if the current loop item is in the tab we're on
        if (config:HasItem(NysTDL.db.profile.itemsFavorite, x)) then -- and it's a favorite
          if (not checkBtn[x]:GetChecked()) then -- and it's not checked
            nbFavCat = nbFavCat + 1 -- then it's one more remaining favorite hidden in the closed category
          end
        end
      end
    end
    categoryLabelFavsRemaining[c]:SetText((nbFavCat > 0) and "("..nbFavCat..")" or "")
    categoryLabelFavsRemaining[c]:SetTextColor(unpack(NysTDL.db.profile.favoritesColor))
  end

  -- and update the "last" remainings for EACH tab (for the inChatIsDone function)
  remainingCheckAll = numberAll;
  remainingCheckDaily = numberDaily;
  remainingCheckWeekly = numberWeekly;

  return numberAll, numberDaily, numberWeekly, numberFavAll, numberFavDaily, numberFavWeekly; -- and we return them, so that we can access it eg. in the favorites warning function
end

function itemsFrame:updateCheckButtons()
  -- we color the items wether they're checked or not
  for i = 1, #All do
    if (checkBtn[All[i]]:GetChecked()) then
      checkBtn[All[i]].text:SetTextColor(0, 1, 0);
    else
      if (config:HasItem(NysTDL.db.profile.itemsFavorite, checkBtn[All[i]]:GetName())) then
        checkBtn[All[i]].text:SetTextColor(unpack(NysTDL.db.profile.favoritesColor));
      else
        checkBtn[All[i]].text:SetTextColor(unpack(config:ThemeDownTo01(config.database.theme_yellow)));
      end
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
    autoResetedThisSession = true;
  elseif time() > NysTDL.db.profile.autoReset["Daily"] then
    NysTDL.db.profile.autoReset["Daily"] = config:GetSecondsToReset().daily;
    itemsFrame:ResetBtns("Daily", true);
    autoResetedThisSession = true;
  end
end

function itemsFrame:autoResetedThisSessionGET()
  return autoResetedThisSession;
end

-- Items modifications

local function updateAllTable()
  All = {}
  local fav = {}
  local others = {}

  -- Completing the All table
  for _, val in pairs(NysTDL.db.profile.itemsList) do
    for _, v in pairs(val) do
      if (config:HasItem(NysTDL.db.profile.itemsFavorite, v)) then
        table.insert(fav, v)
      else
        table.insert(others, v)
      end
    end
  end

  -- then we sort them, so that every item will be sorted alphabetically in the list,
  -- with the favorites in first of every categories
  table.sort(fav)
  table.sort(others)
  for _, v in pairs(fav) do
    table.insert(All, v)
  end
  for _, v in pairs(others) do
    table.insert(All, v)
  end
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

        removeBtn[name] = nil;
        favoriteBtn[name] = nil;
        descBtn[name] = nil;
        checkBtn[name]:Hide(); -- get out of my view mate
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

        favoriteBtn[name] = config:CreateFavoriteButton(checkBtn[name]);
        favoriteBtn[name]:SetScript("OnClick", function(self) itemsFrame:FavoriteClick(self) end);
        favoriteBtn[name]:Hide();

        descBtn[name] = config:CreateDescButton(checkBtn[name]);
        descBtn[name]:SetScript("OnClick", function(self) itemsFrame:DescriptionClick(self) end);
        descBtn[name]:Hide();
      end
      -- we create the corresponding label (if it is a new one)
      if (label[cat] == nil) then
        -- category label
        label[cat] = config:CreateNoPointsLabel(itemsFrameUI, cat, tostring(cat));
        categoryLabelFavsRemaining[cat] = config:CreateNoPointsLabel(itemsFrameUI, cat.."_FavsRemaining", "");
        -- associated edit box and add button
        editBox[cat] = config:CreateNoPointsLabelEditBox(cat);
        editBox[cat]:SetScript("OnEnterPressed", function(self) itemsFrame:AddItem(addBtn[self:GetName()]) end); -- if we press enter, it's like we clicked on the add button
        addBtn[cat] = config:CreateAddButton(editBox[cat]);
        addBtn[cat]:SetScript("OnClick", function(self) itemsFrame:AddItem(self) end);
      end

      Tab_OnClick(_G[NysTDL.db.profile.lastLoadedTab]); -- we reload the tab to instantly display the changes
    end
  end
end

local function addCategory()
  -- the big function to add categories

  local db = {}
  db.cat = itemsFrameUI.categoryEditBox:GetText();

  if (db.cat == "") then
    config:Print(L["Please enter a category name!"])
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
      isPresent0 = (select(1, config:HasItem(NysTDL.db.profile.itemsList[cat], name))); -- does it already exists in the typed category?
    else
      isPresent3 = (select(1, config:HasItem(NysTDL.db.profile.itemsList[cat], name))); -- does it already exists in the typed category?
      if (isPresent1 and not isPresent3) then -- if it already exists somewhere but not in this category
        addResult = {L["This item name already exists!"], false};
        stop = true;
      else -- if it is present IN THIS category (maybe on an other tab) !OR! if it doesn't exists at all
        isPresent0 = (select(1, config:HasItem(TabItemsTable(case), name))); -- does it already exists in the current tab? (Daily or Weekly)
      end
    end

    if (not stop) then
      if (not isPresent0) then
        if (case == "Daily") then
          isPresent2 = (select(1, config:HasItem(NysTDL.db.profile.itemsWeekly, name)));
        elseif (case == "Weekly") then
          isPresent2 = (select(1, config:HasItem(NysTDL.db.profile.itemsDaily, name)));
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
            table.insert(TabItemsTable(case), name);
            addResult = {L["\"%s\" added to %s! (%s item)"]:format(name, cat, L[case]), true};
          elseif (not isPresent2) then -- if it doesn't exists in the current tab, but it does in that category only in the 'All' tab
            table.insert(TabItemsTable(case), name); -- we transform that item into a 'case' item for this category
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
  -- the really important function to delete items

  local modif = false;
  local isPresent, pos;

  local name = self:GetParent():GetName(); -- we get the name of the tied check button
  local cat = (select(2, self:GetParent():GetPoint())):GetName(); -- we get the category we're in

  -- since the item will get removed, we check if his description frame was opened (can happen if there was no description on the item)
  -- and if so, we hide and destroy it
  itemsFrame:descriptionFrameHide(name.."_descFrame")

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
  isPresent, pos = config:HasItem(NysTDL.db.profile.itemsDaily, name);
  if (isPresent) then
    db.case = "Daily";
    table.remove(NysTDL.db.profile.itemsDaily, pos);
  end
  -- Weekly part
  isPresent, pos = config:HasItem(NysTDL.db.profile.itemsWeekly, name);
  if (isPresent) then
    db.case = "Weekly";
    table.remove(NysTDL.db.profile.itemsWeekly, pos);
  end

  if (not clearing) then
    config:Print(L["\"%s\" removed!"]:format(name));
    dontHideMePls[cat] = true; -- we don't hide the edit box at the next refresh for the category we just deleted an item from
  end
  modif = true;

  table.insert(NysTDL.db.profile.undoTable, db);

  refreshTab(nil, name, "Remove", modif, db.checked);
end

function itemsFrame:FavoriteClick(self)
  -- the function to favorite items

  local name = self:GetParent():GetName(); -- we get the name of the tied check button
  local cat = (select(2, self:GetParent():GetPoint())):GetName(); -- we get the category we're in so that we don't hide the add edit box at the next refresh
  dontHideMePls[cat] = true;

  local isPresent, pos = config:HasItem(NysTDL.db.profile.itemsFavorite, name)
  if (not isPresent) then
    table.insert(NysTDL.db.profile.itemsFavorite, name)
  else
    table.remove(NysTDL.db.profile.itemsFavorite, pos)
  end

  Tab_OnClick(_G[NysTDL.db.profile.lastLoadedTab]); -- we reload the tab to instantly display the changes
end

function itemsFrame:descriptionFrameHide(name)
  -- here, if the name matches one of the opened description frames, we hide that frame, delete it from memory and reupdate the levels of every other active ones
  for pos, v in pairs(descFrames) do
    if (v:GetName() == name) then
      v:Hide()
      table.remove(descFrames, pos)
      for pos2, v2 in pairs(descFrames) do -- we reupdate the frame levels
        v2:SetFrameLevel(300 + (pos2-1)*descFrameLevelDiff)
      end
      return true;
    end
  end
  return false;
end

function itemsFrame:DescriptionClick(self)
  -- the big function to create the description frame for each items

  local name = self:GetParent():GetName(); -- we get the name of the tied check button
  local cat = (select(2, self:GetParent():GetPoint())):GetName(); -- we get the category we're in so that we don't hide the add edit box at the next refresh
  dontHideMePls[cat] = true;

  if (itemsFrame:descriptionFrameHide(name.."_descFrame")) then return; end

  -- we create the mini frame holding the name of the item and his description in an edit box
  local descFrame = CreateFrame("Frame", name.."_descFrame", UIParent);
  local w = config:CreateNoPointsLabel(UIParent, nil, name):GetWidth();
  descFrame:SetSize((w < 190) and 190+35 or w+35, 110);

  -- background
  descFrame:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = false, tileSize = 1, edgeSize = 10, insets = { left = 1, right = 1, top = 1, bottom = 1 }});
  descFrame:SetBackdropColor(0, 0, 0, 1);

  -- properties
  descFrame:SetResizable(true);
  descFrame:SetMinResize(descFrame:GetWidth(), descFrame:GetHeight());
  descFrame:SetFrameLevel(300 + #descFrames*descFrameLevelDiff);
  descFrame:SetMovable(true);
  descFrame:SetClampedToScreen(true);
  descFrame:EnableMouse(true);

  -- to move the frame
  descFrame:SetScript("OnMouseDown", function(self, button)
      if (button == "LeftButton") then
          self:StartMoving()
      end
  end)
  descFrame:SetScript("OnMouseUp", descFrame.StopMovingOrSizing)

  descFrame:SetScript("OnUpdate", function(self)
    -- we update non-stop the color of the title
    local name = self.title:GetText();
    local currentAlpha = NysTDL.db.profile.descFrameContentAlpha/100;
    if (checkBtn[name]:GetChecked()) then
      self.title:SetTextColor(0, 1, 0, currentAlpha);
    else
      if (config:HasItem(NysTDL.db.profile.itemsFavorite, checkBtn[name]:GetName())) then
        local r, g, b = unpack(NysTDL.db.profile.favoritesColor);
        self.title:SetTextColor(r, g, b, currentAlpha);
      else
        local r, g, b = unpack(config:ThemeDownTo01(config.database.theme_yellow));
        self.title:SetTextColor(r, g, b, currentAlpha);
      end
    end

    -- and we also update non-stop the width of the description edit box to match that of the frame if we resize it, and when the scrollbar kicks in. (this is the secret to make it work)
    self.descriptionEditBox.EditBox:SetWidth(self.descriptionEditBox:GetWidth() - (self.descriptionEditBox.ScrollBar:IsShown() and 15 or 0))
  end)

  -- position
  descFrame:ClearAllPoints();
  descFrame:SetParent(UIParent);
  descFrame:SetPoint("BOTTOMRIGHT", self, "TOPLEFT", 0, 0);
  descFrame:StartMoving(); -- to unlink it from the itemsframe
  descFrame:StopMovingOrSizing();

  -- / content of the frame / --

  -- resize button
  descFrame.resizeButton = CreateFrame("Button", nil, descFrame, "NysTDL_ResizeButton")
  descFrame.resizeButton:SetPoint("BOTTOMRIGHT")
  descFrame.resizeButton:SetScript("OnMouseDown", function(self, button)
    if (button == "LeftButton") then
      descFrame:StartSizing("BOTTOMRIGHT")
      self:GetHighlightTexture():Hide() -- more noticeable
    end
  end)
  descFrame.resizeButton:SetScript("OnMouseUp", function(self)
    descFrame:StopMovingOrSizing()
    self:GetHighlightTexture():Show()
  end)

  -- close button
  descFrame.closeButton = CreateFrame("Button", "closeButton", descFrame, "NysTDL_CloseButton");
  descFrame.closeButton:SetPoint("TOPRIGHT", descFrame, "TOPRIGHT", -1, -1);
  descFrame.closeButton:SetScript("onClick", function(self)
      itemsFrame:descriptionFrameHide(self:GetParent():GetName())
  end);

  -- item label
  descFrame.title = descFrame:CreateFontString(name.."_descFrameTitle")
  descFrame.title:SetFontObject("GameFontNormalLarge")
  descFrame.title:SetPoint("TOPLEFT", descFrame, "TOPLEFT", 6, -5)
  descFrame.title:SetText(name)

  -- description edit box
  descFrame.descriptionEditBox = CreateFrame("ScrollFrame", name.."_descFrameEditBox", descFrame, "InputScrollFrameTemplate");
  descFrame.descriptionEditBox.EditBox:SetFontObject("ChatFontNormal")
  descFrame.descriptionEditBox.EditBox:SetAutoFocus(false)
  descFrame.descriptionEditBox.EditBox:SetMaxLetters(0)
  descFrame.descriptionEditBox.CharCount:Hide()
  descFrame.descriptionEditBox.EditBox.Instructions:SetFontObject("GameFontNormal")
  descFrame.descriptionEditBox.EditBox.Instructions:SetText(L["Add a description..."].."\n"..L["(automatically saved)"])
  descFrame.descriptionEditBox:SetPoint("TOPLEFT", descFrame, "TOPLEFT", 10, -30);
  descFrame.descriptionEditBox:SetPoint("BOTTOMRIGHT", descFrame, "BOTTOMRIGHT", -10, 10);
  if (config:HasKey(NysTDL.db.profile.itemsDesc, name)) then -- if there is already a description for this item, we write it on frame creation
    descFrame.descriptionEditBox.EditBox:SetText(NysTDL.db.profile.itemsDesc[name])
  end
  descFrame.descriptionEditBox.EditBox:SetScript("OnKeyUp", function(self)
    -- and here we save the description everytime we lift a finger (best auto-save possible I think)
    local itemName = self:GetParent():GetParent().title:GetText()
    NysTDL.db.profile.itemsDesc[itemName] = (self:GetText() ~= "") and self:GetText() or nil
  end)


  table.insert(descFrames, descFrame) -- we save it for level, hide, and alpha purposes

  -- we update the alpha if it needs to be
  FrameAlphaSlider_OnValueChanged(nil, NysTDL.db.profile.frameAlpha);
  FrameContentAlphaSlider_OnValueChanged(nil, NysTDL.db.profile.frameContentAlpha);

  Tab_OnClick(_G[NysTDL.db.profile.lastLoadedTab]); -- we reload the tab to instantly display the changes
end

function itemsFrame:ClearTab(tabName)
  if (tabName == nil) then tabName = "All"; end

  local items = {};
  if (tabName == "All") then items = All; end
  if (tabName == "Daily") then items = NysTDL.db.profile.itemsDaily; end
  if (tabName == "Weekly") then items = NysTDL.db.profile.itemsWeekly; end

  -- first we get how many items are favorites and how many have descriptions in this tab (they are protected, we won't clear them)
  local nbProtected = 0;
  for _, v in pairs(items) do
    if (config:HasItem(NysTDL.db.profile.itemsFavorite, v) or config:HasKey(NysTDL.db.profile.itemsDesc, v)) then
      nbProtected = nbProtected + 1;
    end
  end

  if (#items > nbProtected) then -- if there is at least one item that can be cleared in this tab
    -- we start the clear
    clearing = true;

    -- we keep in mind what tab we were on when we started the clear (just so that we come back to it after the job is done)
    local last = NysTDL.db.profile.lastLoadedTab;

    local nb = #items - nbProtected; -- but before (if we want to undo it) we keep in mind how many items there were to be cleared

    Tab_OnClick(_G["ToDoListUIFrameTab1"]); -- we put ourselves in the All tab so that evey item is loaded

    for _, v in pairs(removeBtn) do
      if (config:HasItem(items, v:GetParent():GetName())) then -- if the item is in the tab we want to clear
        if (not config:HasItem(NysTDL.db.profile.itemsFavorite, v:GetParent():GetName()) and not config:HasKey(NysTDL.db.profile.itemsDesc, v:GetParent():GetName())) then -- if it's not a favorite nor it has a description
          itemsFrame:RemoveItem(v); -- then we remove it
        end
      end
    end

    table.insert(NysTDL.db.profile.undoTable, nb); -- and then we save how many items were actually removed

    -- we refresh and go back to the tab we were on
    Tab_OnClick(_G[last]);

    clearing = false;
    config:Print(L["Clear succesful! (%s tab, %i items)"]:format(L[tabName], nb));
  else
    config:Print(L["Nothing can be cleared here!"]);
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
ItemsFrame_Update = function()
  -- updates everything about the frame once everytime we call this function
  updateAllTable();
  itemsFrame:updateRemainingNumber();
  itemsFrame:updateCheckButtons();
  saveSavedVariable();
end

ItemsFrame_UpdateTime = function()
  -- updates things about time
  itemsFrame:autoReset();
end

local function ItemsFrame_CheckLabels()
  -- update for the labels:
  for k, _ in pairs(NysTDL.db.profile.itemsList) do
    if (label[k]:IsMouseOver()) then -- for every label in the current tab, if our mouse is over one of them,
      local r, g, b = unpack(config:ThemeDownTo01(config.database.theme));
      label[k]:SetTextColor(r, g, b, 1); -- we change its visual
      if (not config:HasItem(labelHover, k)) then
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

local function ItemsFrame_OnMouseUp(_, button)
  local name = tostringall(unpack(labelHover)); -- we get the name of the label we clicked on (if we clicked on a label)
  if (name ~= "" and name ~= nil) then -- we test that here
    if (button == "LeftButton") then
      -- if we're here, it means we've clicked somewhere on the frame
      if (next(labelHover)) then -- if we are mouse hovering one of the category labels
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
    elseif (button == "RightButton") then
      -- if the label we right clicked on is NOT a closed category
      if (not (select(1, config:HasKey(NysTDL.db.profile.closedCategories, name))) or not (select(1, config:HasItem(NysTDL.db.profile.closedCategories[name], CurrentTab:GetName())))) then
        -- then we toggle its edit box
        editBox[name]:SetShown(not editBox[name]:IsShown());
        dontHideMePls[name] = true;
        Tab_OnClick(_G[NysTDL.db.profile.lastLoadedTab]); -- and we reload the frame to hide any other edit boxes, we only want one shown at a time
      end
    end
  end
end

local function ItemsFrame_OnVisibilityUpdate()
  -- things to do when we hide/show the list
  addACategoryClosed = true;
  tabActionsClosed = true;
  optionsClosed = true;
  Tab_OnClick(_G[NysTDL.db.profile.lastLoadedTab]);
end

local function ItemsFrame_Scale()
  local scale = itemsFrameUI:GetWidth()/340;
  itemsFrameUI.ScrollFrame.ScrollBar:SetScale(scale)
  itemsFrameUI.closeButton:SetScale(scale)
  itemsFrameUI.resizeButton:SetScale(scale)
  for i = 1, 3 do
    _G["ToDoListUIFrameTab"..i].content:SetScale(scale)
    _G["ToDoListUIFrameTab"..i]:SetScale(scale)
  end
end

local function ItemsFrame_OnUpdate(self, elapsed)
  -- called every frame
  self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed;
  self.timeSinceLastRefresh = self.timeSinceLastRefresh + elapsed;

  -- if (self:IsMouseOver()) then
  --   itemsFrameUI.ScrollFrame.ScrollBar:Show()
  -- else
  --   itemsFrameUI.ScrollFrame.ScrollBar:Hide()
  -- end

  if (self.isMouseDown and not self.hasMoved) then
    local x, y = GetCursorPosition()
    if ((x > cursorX + cursorDist) or (x < cursorX - cursorDist) or (y > cursorY + cursorDist) or (y < cursorY - cursorDist)) then  -- we start dragging the frame
      self:StartMoving()
      self.hasMoved = true
    end
  end

  -- testing and showing the right button next to each items
  if (IsShiftKeyDown()) then
    for i = 1, #All, 1 do
      -- we show every star icons
      removeBtn[All[i]]:Hide()
      descBtn[All[i]]:Hide();
      favoriteBtn[All[i]]:Show();
    end
  elseif (IsControlKeyDown()) then
    for i = 1, #All, 1 do
      -- we show every paper icons
      removeBtn[All[i]]:Hide()
      favoriteBtn[All[i]]:Hide();
      descBtn[All[i]]:Show();
    end
  else
      for i = 1, #All, 1 do
        local isFavorite = config:HasItem(NysTDL.db.profile.itemsFavorite, favoriteBtn[All[i]]:GetParent():GetName());
        local hasDesc = config:HasKey(NysTDL.db.profile.itemsDesc, descBtn[All[i]]:GetParent():GetName());
        if (hasDesc) then
          -- if current item has a description, the paper icon takes the lead
          favoriteBtn[All[i]]:Hide();
          removeBtn[All[i]]:Hide()
          descBtn[All[i]]:Show();
        elseif (isFavorite) then
          -- or else if current item is a favorite
          descBtn[All[i]]:Hide();
          removeBtn[All[i]]:Hide()
          favoriteBtn[All[i]]:Show();
        else
          -- default
          favoriteBtn[All[i]]:Hide();
          descBtn[All[i]]:Hide();
          removeBtn[All[i]]:Show()
        end
      end
  end

  if (IsAltKeyDown()) then
    -- we switch the category and frame options buttons for the undo and frame action ones and vice versa
    itemsFrameUI.categoryButton:Hide()
    itemsFrameUI.undoButton:Show()
    itemsFrameUI.frameOptionsButton:Hide()
    itemsFrameUI.tabActionsButton:Show()
    -- resize button
    itemsFrameUI.ScrollFrame.ScrollBar:SetPoint("BOTTOMRIGHT", itemsFrameUI.ScrollFrame, "BOTTOMRIGHT", - 7, 32);
    itemsFrameUI.resizeButton:Show()
  else
    itemsFrameUI.undoButton:Hide()
    itemsFrameUI.categoryButton:Show()
    itemsFrameUI.tabActionsButton:Hide()
    itemsFrameUI.frameOptionsButton:Show()
    -- resize button
    itemsFrameUI.ScrollFrame.ScrollBar:SetPoint("BOTTOMRIGHT", itemsFrameUI.ScrollFrame, "BOTTOMRIGHT", - 7, 17);
    itemsFrameUI.resizeButton:Hide()
  end

  -- we also update their color, if one of the button menus is opened
  itemsFrameUI.categoryButton.Icon:SetTextColor(unpack(config:ThemeDownTo01(config.database.theme_yellow))) -- for this one, it's text, not an icon!
  itemsFrameUI.frameOptionsButton.Icon:SetDesaturated(nil) itemsFrameUI.frameOptionsButton.Icon:SetVertexColor(1, 1, 1)
  itemsFrameUI.tabActionsButton.Icon:SetDesaturated(nil) itemsFrameUI.tabActionsButton.Icon:SetVertexColor(1, 1, 1)
  if (not addACategoryClosed) then
  itemsFrameUI.categoryButton.Icon:SetTextColor(0.8, 0.8, 0.8)
  elseif (not optionsClosed) then
    itemsFrameUI.frameOptionsButton.Icon:SetDesaturated(1) itemsFrameUI.frameOptionsButton.Icon:SetVertexColor(1, 1, 1)
  elseif (not tabActionsClosed) then
    itemsFrameUI.tabActionsButton.Icon:SetDesaturated(1) itemsFrameUI.tabActionsButton.Icon:SetVertexColor(1, 1, 1)
  end

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

    favoriteBtn[All[i]] = config:CreateFavoriteButton(checkBtn[All[i]]);
    favoriteBtn[All[i]]:SetScript("OnClick", function(self) itemsFrame:FavoriteClick(self) end);
    favoriteBtn[All[i]]:Hide();

    descBtn[All[i]] = config:CreateDescButton(checkBtn[All[i]]);
    descBtn[All[i]]:SetScript("OnClick", function(self) itemsFrame:DescriptionClick(self) end);
    descBtn[All[i]]:Hide();
  end

  -- Category labels
  for k, _ in pairs(NysTDL.db.profile.itemsList) do
    -- category label
    label[k] = config:CreateNoPointsLabel(itemsFrameUI, k, tostring(k));
    categoryLabelFavsRemaining[k] = config:CreateNoPointsLabel(itemsFrameUI, k.."_FavsRemaining", "");
    -- associated edit box and add button
    editBox[k] = config:CreateNoPointsLabelEditBox(k);
    editBox[k]:SetScript("OnEnterPressed", function(self) itemsFrame:AddItem(addBtn[self:GetName()]) end); -- if we press enter, it's like we clicked on the add button
    addBtn[k] = config:CreateAddButton(editBox[k]);
    addBtn[k]:SetScript("OnClick", function(self) itemsFrame:AddItem(self) end);
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

  local lastLabel, l, m;
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
    local distanceFromLabelWhenOk = 160;
    if (labelWidth + 120 > editBoxAddItemWidth) then
      editBox[categoryLabel:GetName()]:SetPoint("LEFT", categoryLabel, "RIGHT", 10, 0);
      editBox[categoryLabel:GetName()]:SetWidth(editBoxAddItemWidth - labelWidth);
    else
      editBox[categoryLabel:GetName()]:SetPoint("LEFT", categoryLabel, "LEFT", distanceFromLabelWhenOk, 0);
    end

    -- we keep the edit box for this category shown if we just added an item with it
    if (not dontHideMePls[categoryLabel:GetName()]) then
      editBox[categoryLabel:GetName()]:Hide();
    else
      dontHideMePls[categoryLabel:GetName()] = nil;
      -- we do not change its points, he's still here and anchored to the label (which may have moved, but will update the button as well on its own)
    end

    -- label showing how much favs is left in a closed category
    -- if the category label is shown in this tab, we move that cat fav label here too, correctly anchored
    categoryLabelFavsRemaining[catName]:SetParent(tab);
    categoryLabelFavsRemaining[catName]:ClearAllPoints();
    categoryLabelFavsRemaining[catName]:SetPoint("LEFT", categoryLabel, "RIGHT", 6, 0);

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
      categoryLabelFavsRemaining[catName]:Hide(); -- the only thing is that we hide it if the category is opened
    else
      -- if not, we still need to put them at their right place, anchors and parents (but we keep them hidden)
      -- especially for when we load the All tab, for the clearing
      for i = 1, #All do
        if ((select(1, config:HasItem(category, checkBtn[All[i]]:GetName())))) then
          checkBtn[All[i]]:SetParent(tab);
          checkBtn[All[i]]:SetPoint("TOPLEFT", categoryLabel, "TOPLEFT");
        end
      end
      categoryLabelFavsRemaining[catName]:Show(); -- bc we only see him when the cat is closed
    end
  else
    -- if the current label has no reason to be visible in this tab, we hide it (and for the checkboxes, they have already been hidden in the first call to this func).
    -- so first we hide them to be sure they are gone from our view, and then it's a bit more complicated:
    -- we reset their parent to be the current tab, so that we're sure that they are all on the same tab, and then
    -- ClearAllPoints is pretty magical here since a hidden label CAN be clicked on and still manages to fire OnEnter and everything else, so :Hide() is not enough,
    -- so with this API we clear their points so that they have nowhere to go and they don't fire events anymore.
    label[catName]:Hide();
    label[catName]:SetParent(tab);
    label[catName]:ClearAllPoints();
    categoryLabelFavsRemaining[catName]:Hide();
    categoryLabelFavsRemaining[catName]:SetParent(tab);
    categoryLabelFavsRemaining[catName]:ClearAllPoints();
    editBox[catName]:Hide();
    editBox[catName]:SetParent(tab);
    editBox[catName]:ClearAllPoints();
    dontHideMePls[catName] = nil;

    if (not next(NysTDL.db.profile.itemsList[catName])) then -- if there is no more item in a category, we delete the corresponding elements
      -- we destroy them
      addBtn[catName] = nil;
      editBox[catName] = nil;
      label[catName] = nil;
      categoryLabelFavsRemaining[catName] = nil;

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
    lastData, once = loadCategories(tab, NysTDL.db.profile.itemsList[n], label[n], case, n, lastData, once);
  end
end

----------------------------

local function loadAddACategory(tab)
  itemsFrameUI.categoryButton:SetParent(tab);
  itemsFrameUI.categoryButton:SetPoint("RIGHT", itemsFrameUI.frameOptionsButton, "LEFT", 2, 0);

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

local function loadTabActions(tab)
  itemsFrameUI.tabActionsButton:SetParent(tab);
  itemsFrameUI.tabActionsButton:SetPoint("RIGHT", itemsFrameUI.undoButton, "LEFT", 2, 0);

  --/************************************************/--

  itemsFrameUI.tabActionsTitle:SetParent(tab);
  itemsFrameUI.tabActionsTitle:SetPoint("TOP", itemsFrameUI.title, "TOP", 0, - 59);
  itemsFrameUI.tabActionsTitle:SetText(string.format("|cff%s%s|r", config:RGBToHex(config.database.theme), "/ "..L["Tab actions"].." ("..L[tab:GetName()]..") \\"));

  --/************************************************/--

  local w = itemsFrameUI.btnCheck:GetWidth() + itemsFrameUI.btnUncheck:GetWidth() + 10; -- this is to better center the buttons
  itemsFrameUI.btnCheck:SetParent(tab);
  itemsFrameUI.btnCheck:SetPoint("TOPLEFT", itemsFrameUI.tabActionsTitle, "TOP", -(w/2), - 35);

  itemsFrameUI.btnUncheck:SetParent(tab);
  itemsFrameUI.btnUncheck:SetPoint("TOPLEFT", itemsFrameUI.btnCheck, "TOPRIGHT", 10, 0);

  --/************************************************/--

  itemsFrameUI.btnClear:SetParent(tab);
  itemsFrameUI.btnClear:SetPoint("TOP", itemsFrameUI.btnCheck, "TOPLEFT", (w/2), -45);
end

local function loadOptions(tab)
  itemsFrameUI.frameOptionsButton:SetParent(tab);
  itemsFrameUI.frameOptionsButton:SetPoint("RIGHT", itemsFrameUI.helpButton, "LEFT", 2, 0);

  --/************************************************/--

  itemsFrameUI.optionsTitle:SetParent(tab);
  itemsFrameUI.optionsTitle:SetPoint("TOP", itemsFrameUI.title, "TOP", 0, - 59);

  --/************************************************/--

  itemsFrameUI.resizeTitle:SetParent(tab);
  itemsFrameUI.resizeTitle:SetPoint("TOP", itemsFrameUI.optionsTitle, "TOP", 0, -32);
  local h = itemsFrameUI.resizeTitle:GetHeight() -- if the locale text is too long, we adapt the points of the next element to match the height of this string

  --/************************************************/--

  itemsFrameUI.frameAlphaSlider:SetParent(tab);
  itemsFrameUI.frameAlphaSlider:SetPoint("TOP", itemsFrameUI.resizeTitle, "TOP", 0, -28 - h); -- here

  itemsFrameUI.frameAlphaSliderValue:SetParent(tab);
  itemsFrameUI.frameAlphaSliderValue:SetPoint("TOP", itemsFrameUI.frameAlphaSlider, "BOTTOM", 0, 0);

  --/************************************************/--

  itemsFrameUI.frameContentAlphaSlider:SetParent(tab);
  itemsFrameUI.frameContentAlphaSlider:SetPoint("TOP", itemsFrameUI.frameAlphaSlider, "TOP", 0, -50);

  itemsFrameUI.frameContentAlphaSliderValue:SetParent(tab);
  itemsFrameUI.frameContentAlphaSliderValue:SetPoint("TOP", itemsFrameUI.frameContentAlphaSlider, "BOTTOM", 0, 0);

  --/************************************************/--

  itemsFrameUI.affectDesc:SetParent(tab);
  itemsFrameUI.affectDesc:SetPoint("TOP", itemsFrameUI.frameContentAlphaSlider, "TOP", 0, -40);

  --/************************************************/--

  itemsFrameUI.btnAddonOptions:SetParent(tab);
  itemsFrameUI.btnAddonOptions:SetPoint("TOP", itemsFrameUI.affectDesc, "TOP", 0, - 55);
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

  itemsFrameUI.helpButton:SetParent(tab);
  itemsFrameUI.helpButton:SetPoint("TOPRIGHT", itemsFrameUI.title, "TOP", 140, - 23);

  itemsFrameUI.undoButton:SetParent(tab);
  itemsFrameUI.undoButton:SetPoint("RIGHT", itemsFrameUI.helpButton, "LEFT", 2, 0);

  -- loading the "add a new category" menu
  loadAddACategory(tab);

  -- loading the "tab actions" menu
  loadTabActions(tab);

  -- loading the "frame options" menu
  loadOptions(tab);

  -- loading the bottom line at the correct place (a bit special)
  itemsFrameUI.lineBottom:SetParent(tab);

  -- and the menu title lines (a bit complicated too)
  itemsFrameUI.menuTitleLineLeft:SetParent(tab)
  itemsFrameUI.menuTitleLineRight:SetParent(tab)
  if (addACategoryClosed and tabActionsClosed and optionsClosed) then
    itemsFrameUI.menuTitleLineLeft:Hide()
    itemsFrameUI.menuTitleLineRight:Hide()
  else
    if (not addACategoryClosed) then
      l = itemsFrameUI.categoryTitle:GetWidth()
    elseif (not tabActionsClosed) then
      l = itemsFrameUI.tabActionsTitle:GetWidth()
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

  if (tabActionsClosed) then -- if the tab actions menu is closed
    -- then we hide every component of the "tab actions"
    for _, v in pairs(tabActionsItems) do
      v:Hide();
    end
  end

  if (optionsClosed) then -- if the options menu is closed
    -- then we hide every component of the "options"
    for _, v in pairs(frameOptionsItems) do
      v:Hide();
    end
  end

  -- then we decide where to place the bottom line
  if (addACategoryClosed) then -- if the creation of new categories is closed
    if (tabActionsClosed) then -- if the options menu is closed
      if (optionsClosed) then -- and if the tab actions menu is closed too
        -- we place the line just below the buttons
        itemsFrameUI.lineBottom:SetStartPoint("TOPLEFT", centerXOffset-lineOffset, -78)
        itemsFrameUI.lineBottom:SetEndPoint("TOPLEFT", centerXOffset+lineOffset, -78)
      else
        -- or else we show and adapt the height of every component of the "options"
        local height = 0;
        for _, v in pairs(frameOptionsItems) do
          v:Show();
          height = height + (select(5, v:GetPoint()));
        end

        -- and show the line below them
        itemsFrameUI.lineBottom:SetStartPoint("TOPLEFT", centerXOffset-lineOffset, height - 62)
        itemsFrameUI.lineBottom:SetEndPoint("TOPLEFT", centerXOffset+lineOffset, height - 62)
      end
    else
      -- or else we show and adapt the height of every component of the "tab actions"
      local height = 0;
      for _, v in pairs(tabActionsItems) do
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
  itemsFrameUI.categoryButton = CreateFrame("Button", "categoryButton", itemsFrameUI, "NysTDL_CategoryButton");
  itemsFrameUI.categoryButton.tooltip = L["Add a new category"];
  itemsFrameUI.categoryButton:SetScript("OnClick", function()
    tabActionsClosed = true;
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
  itemsFrameUI.categoryEditBox:SetScript("OnKeyDown", function(_, key) if (key == "TAB") then itemsFrameUI.nameEditBox:SetFocus() end end) -- to switch easily between the two edit boxes
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
  itemsFrameUI.nameEditBox:SetScript("OnKeyDown", function(_, key) if (key == "TAB") then itemsFrameUI.categoryEditBox:SetFocus() end end)
  itemsFrameUI.nameEditBox:SetScript("OnEnterPressed", addCategory); -- if we press enter, it's like we clicked on the add button
  table.insert(addACategoryItems, itemsFrameUI.nameEditBox);

  itemsFrameUI.addBtn = config:CreateButton("addButton", itemsFrameUI, L["Add category"]);
  itemsFrameUI.addBtn:SetScript("onClick", addCategory);
  table.insert(addACategoryItems, itemsFrameUI.addBtn);
end

local function generateTabActions()
  itemsFrameUI.tabActionsButton = CreateFrame("Button", "categoryButton", itemsFrameUI, "NysTDL_TabActionsButton");
  itemsFrameUI.tabActionsButton.tooltip = L["Tab actions"];
  itemsFrameUI.tabActionsButton:SetScript("OnClick", function()
    addACategoryClosed = true;
    optionsClosed = true;
    tabActionsClosed = not tabActionsClosed;
    Tab_OnClick(_G[NysTDL.db.profile.lastLoadedTab]); -- we reload the frame to display the changes
  end);
  itemsFrameUI.tabActionsButton:Hide();

  --/************************************************/--

  itemsFrameUI.tabActionsTitle = config:CreateNoPointsLabel(itemsFrameUI, nil, string.format("|cff%s%s|r", config:RGBToHex(config.database.theme), "/ "..L["Tab actions"].." \\"));
  table.insert(tabActionsItems, itemsFrameUI.tabActionsTitle);

  --/************************************************/--

  itemsFrameUI.btnCheck = config:CreateButton("btnCheck_itemsFrameUI", itemsFrameUI, L["Check"], "Interface\\BUTTONS\\UI-CheckBox-Check");
  itemsFrameUI.btnCheck:SetScript("OnClick", function(self)
    local tabName = self:GetParent():GetName();
    itemsFrame:CheckBtns(tabName);
  end);
  table.insert(tabActionsItems, itemsFrameUI.btnCheck);

  itemsFrameUI.btnUncheck = config:CreateButton("btnUncheck_itemsFrameUI", itemsFrameUI, L["Uncheck"], "Interface\\BUTTONS\\UI-CheckBox-Check-Disabled");
  itemsFrameUI.btnUncheck:SetScript("OnClick", function(self)
    local tabName = self:GetParent():GetName();
    itemsFrame:ResetBtns(tabName);
  end);
  table.insert(tabActionsItems, itemsFrameUI.btnUncheck);

  --/************************************************/--

  itemsFrameUI.btnClear = config:CreateButton("clearButton", itemsFrameUI, L["Clear"], "Interface\\GLUES\\LOGIN\\Glues-CheckBox-Check");
  itemsFrameUI.btnClear:SetScript("onClick", function(self)
    local tabName = self:GetParent():GetName();
    itemsFrame:ClearTab(tabName);
  end);
  table.insert(tabActionsItems, itemsFrameUI.btnClear);
end

local function generateOptions()
  itemsFrameUI.frameOptionsButton = CreateFrame("Button", "frameOptionsButton_itemsFrameUI", itemsFrameUI, "NysTDL_FrameOptionsButton");
  itemsFrameUI.frameOptionsButton.tooltip = L["Frame options"];
  itemsFrameUI.frameOptionsButton:SetScript("OnClick", function()
    addACategoryClosed = true;
    tabActionsClosed = true;
    optionsClosed = not optionsClosed;
    Tab_OnClick(_G[NysTDL.db.profile.lastLoadedTab]); -- we reload the frame to display the changes
  end);

  --/************************************************/--

  itemsFrameUI.optionsTitle = config:CreateNoPointsLabel(itemsFrameUI, nil, string.format("|cff%s%s|r", config:RGBToHex(config.database.theme), "/ "..L["Frame options"].." \\"));
  table.insert(frameOptionsItems, itemsFrameUI.optionsTitle);

  --/************************************************/--

  itemsFrameUI.resizeTitle = config:CreateNoPointsLabel(itemsFrameUI, nil, string.format("|cffffffff%s|r", L["Hold ALT to see the resize button"]));
  itemsFrameUI.resizeTitle:SetFontObject("GameFontHighlight");
  itemsFrameUI.resizeTitle:SetWidth(230)
  table.insert(frameOptionsItems, itemsFrameUI.resizeTitle);

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
  table.insert(frameOptionsItems, itemsFrameUI.frameAlphaSlider);

  itemsFrameUI.frameAlphaSliderValue = itemsFrameUI.frameAlphaSlider:CreateFontString("frameAlphaSliderValue"); -- the font string to see the current value
  itemsFrameUI.frameAlphaSliderValue:SetFontObject("GameFontNormalSmall");
  itemsFrameUI.frameAlphaSliderValue:SetText(itemsFrameUI.frameAlphaSlider:GetValue());
  table.insert(frameOptionsItems, itemsFrameUI.frameAlphaSliderValue);

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
  table.insert(frameOptionsItems, itemsFrameUI.frameContentAlphaSlider);

  itemsFrameUI.frameContentAlphaSliderValue = itemsFrameUI.frameContentAlphaSlider:CreateFontString("frameContentAlphaSliderValue"); -- the font string to see the current value
  itemsFrameUI.frameContentAlphaSliderValue:SetFontObject("GameFontNormalSmall");
  itemsFrameUI.frameContentAlphaSliderValue:SetText(itemsFrameUI.frameContentAlphaSlider:GetValue());
  table.insert(frameOptionsItems, itemsFrameUI.frameContentAlphaSliderValue);

  --/************************************************/--

  itemsFrameUI.affectDesc = CreateFrame("CheckButton", "NysTDL_affectDesc", itemsFrameUI, "ChatConfigCheckButtonTemplate");
  itemsFrameUI.affectDesc.tooltip = L["Share the opacity options of this frame onto the description frames (only when checked)"]
  itemsFrameUI.affectDesc.Text:SetText(L["Affect description frames"]);
  itemsFrameUI.affectDesc.Text:SetFontObject("GameFontHighlight");
  itemsFrameUI.affectDesc.Text:ClearAllPoints()
  itemsFrameUI.affectDesc.Text:SetPoint("TOP", itemsFrameUI.affectDesc, "BOTTOM");
  itemsFrameUI.affectDesc:SetHitRectInsets(0, 0, 0, 0);
  itemsFrameUI.affectDesc:SetScript("OnClick", function(self)
    NysTDL.db.profile.affectDesc = self:GetChecked()
    FrameAlphaSlider_OnValueChanged(nil, NysTDL.db.profile.frameAlpha);
    FrameContentAlphaSlider_OnValueChanged(nil, NysTDL.db.profile.frameContentAlpha);
  end);
  itemsFrameUI.affectDesc:SetChecked(NysTDL.db.profile.affectDesc);
  table.insert(frameOptionsItems, itemsFrameUI.affectDesc);

  --/************************************************/--

  itemsFrameUI.btnAddonOptions = config:CreateButton("addonOptionsButton", itemsFrameUI, L["Open addon options"], "Interface\\Buttons\\UI-OptionsButton");
  itemsFrameUI.btnAddonOptions:SetScript("OnClick", function() if (not NysTDL:ToggleOptions(true)) then itemsFrameUI:Hide(); end end);
  table.insert(frameOptionsItems, itemsFrameUI.btnAddonOptions);
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

  -- help button
  itemsFrameUI.helpButton = config:CreateHelpButton(itemsFrameUI);
  itemsFrameUI.helpButton:SetScript("OnClick", function() SlashCmdList["NysToDoList"](L["info"]) end);

  -- undo button
  itemsFrameUI.undoButton = CreateFrame("Button", "undoButton_itemsFrameUI", itemsFrameUI, "NysTDL_UndoButton");
  itemsFrameUI.undoButton.tooltip = L["Undo last remove/clear"];
  itemsFrameUI.undoButton:SetScript("OnClick", itemsFrame.UndoRemove);
  itemsFrameUI.undoButton:Hide();

  -- add a new category button
  generateAddACategory();

  -- tab actions button
  generateTabActions();

  -- options button
  generateOptions();

  itemsFrameUI.titleLineLeft = config:CreateNoPointsLine(itemsFrameUI, 2, unpack(config:ThemeDownTo01(config:DimTheme(config.database.theme_yellow, 0.8))))
  itemsFrameUI.titleLineRight = config:CreateNoPointsLine(itemsFrameUI, 2, unpack(config:ThemeDownTo01(config:DimTheme(config.database.theme_yellow, 0.8))))
  itemsFrameUI.menuTitleLineLeft = config:CreateNoPointsLine(itemsFrameUI, 2, unpack(config:ThemeDownTo01(config:DimTheme(config.database.theme, 0.7))))
  itemsFrameUI.menuTitleLineRight = config:CreateNoPointsLine(itemsFrameUI, 2, unpack(config:ThemeDownTo01(config:DimTheme(config.database.theme, 0.7))))
  itemsFrameUI.lineBottom = config:CreateNoPointsLine(itemsFrameUI, 2, unpack(config:ThemeDownTo01(config:DimTheme(config.database.theme, 0.7))))

  itemsFrameUI.nothingLabel = config:CreateNothingLabel(itemsFrameUI);

  itemsFrameUI.dummyLabel = config:CreateDummy(itemsFrameUI, itemsFrameUI.lineBottom, 0, 0);
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
  if (self:GetName() == "ToDoListUIFrameTab2") then loadTab(DailyTab, NysTDL.db.profile.itemsDaily) end
  if (self:GetName() == "ToDoListUIFrameTab3") then loadTab(WeeklyTab, NysTDL.db.profile.itemsWeekly) end

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
    if (i == 1) then -- OnUpdate hook
      tab:HookScript("OnUpdate", function()
        for i = 1, 3 do
          _G["ToDoListUIFrameTab"..i.."Text"]:SetAlpha((NysTDL.db.profile.frameContentAlpha)/100);
        end
      end);
    end

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

  for k, _ in pairs(currentDBItemsList) do
    label[k]:Hide()
    categoryLabelFavsRemaining[k]:Hide()
    editBox[k]:Hide()
  end

  for _, v in pairs(descFrames) do
    v:Hide()
  end

  -- 2 - reset every content variable to their default value
  remainingCheckAll, remainingCheckDaily, remainingCheckWeekly = 0, 0, 0;
  clearing, undoing = false, { ["clear"] = false, ["clearnb"] = 0, ["single"] = false, ["singleok"] = true};

  dontHideMePls = {};
  checkBtn = {};
  removeBtn = {};
  favoriteBtn = {};
  descBtn = {};
  descFrames = {};
  addBtn = {};
  label = {};
  editBox = {};
  labelHover = {};
  categoryLabelFavsRemaining = {};
  addACategoryClosed = true;
  tabActionsClosed = true;
  optionsClosed = true;
  autoResetedThisSession = false;
end

--Frame init
function itemsFrame:Init()
  -- this one is for keeping track of the old itemsList when we reset,
  -- so that we can hide everything when we change profiles
  currentDBItemsList = NysTDL.db.profile.itemsList;

  -- we resize and scale the frame to match the saved variable
  itemsFrameUI:SetSize(NysTDL.db.profile.frameSize.width, NysTDL.db.profile.frameSize.height);
  -- we reposition the frame to match the saved variable
  local points = NysTDL.db.profile.framePos;
  itemsFrameUI:ClearAllPoints();
  itemsFrameUI:SetPoint(points.point, points.relativeTo, points.relativePoint, points.xOffset, points.yOffset);
  -- and update its elements opacity to match the saved variable
  FrameAlphaSlider_OnValueChanged(nil, NysTDL.db.profile.frameAlpha);
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
  itemsFrameUI.affectDesc:SetChecked(NysTDL.db.profile.affectDesc);
end

---Creating the main window---
function itemsFrame:CreateItemsFrame()

  itemsFrameUI = CreateFrame("Frame", "ToDoListUIFrame", UIParent);

  -- background
  itemsFrameUI:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = false, tileSize = 1, edgeSize = 10, insets = { left = 1, right = 1, top = 1, bottom = 1 }});

  -- properties
  itemsFrameUI:SetResizable(true);
  itemsFrameUI:SetMinResize(240, 284);
  itemsFrameUI:SetMaxResize(400, 600);
  itemsFrameUI:SetFrameLevel(200);
  itemsFrameUI:SetMovable(true);
  itemsFrameUI:SetClampedToScreen(true);
  itemsFrameUI:EnableMouse(true);

  itemsFrameUI:HookScript("OnUpdate", ItemsFrame_OnUpdate);
  itemsFrameUI:HookScript("OnMouseUp", ItemsFrame_OnMouseUp);
  itemsFrameUI:HookScript("OnShow", ItemsFrame_OnVisibilityUpdate);
  itemsFrameUI:HookScript("OnHide", ItemsFrame_OnVisibilityUpdate);
  itemsFrameUI:HookScript("OnSizeChanged", function(self)
    NysTDL.db.profile.frameSize.width = self:GetWidth()
    NysTDL.db.profile.frameSize.height = self:GetHeight()
    ItemsFrame_Scale()
  end);

  -- to move the frame AND NOT HAVE THE PRB WITH THE RESIZE so it's custom moving
  itemsFrameUI.isMouseDown = false
  itemsFrameUI.hasMoved = false
  local function StopMoving(self)
    self.isMouseDown = false
    if (self.hasMoved == true) then
      self:StopMovingOrSizing()
      self.hasMoved = false
      local points = NysTDL.db.profile.framePos
      points.point, points.relativeTo, points.relativePoint, points.xOffset, points.yOffset = self:GetPoint()
    end
  end
  itemsFrameUI:HookScript("OnMouseDown", function(self, button)
    if (button == "LeftButton") then
      self.isMouseDown = true
      cursorX, cursorY = GetCursorPosition()
    end
  end)
  itemsFrameUI:HookScript("OnMouseUp", StopMoving)
  itemsFrameUI:HookScript("OnHide", StopMoving)

  -- // CONTENT OF THE FRAME // --

  -- random variables
  itemsFrameUI.timeSinceLastUpdate = 0;
  itemsFrameUI.timeSinceLastRefresh = 0;

  -- generating the fixed content shared between the 3 tabs
  generateFrameContent();

  -- scroll frame
  itemsFrameUI.ScrollFrame = CreateFrame("ScrollFrame", nil, itemsFrameUI, "UIPanelScrollFrameTemplate");
  itemsFrameUI.ScrollFrame:SetPoint("TOPLEFT", itemsFrameUI, "TOPLEFT", 4, - 4);
  itemsFrameUI.ScrollFrame:SetPoint("BOTTOMRIGHT", itemsFrameUI, "BOTTOMRIGHT", - 4, 4);
  itemsFrameUI.ScrollFrame:SetClipsChildren(true);

  itemsFrameUI.ScrollFrame:SetScript("OnMouseWheel", ScrollFrame_OnMouseWheel);

  itemsFrameUI.ScrollFrame.ScrollBar:ClearAllPoints();
  itemsFrameUI.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", itemsFrameUI.ScrollFrame, "TOPRIGHT", - 12, - 38); -- the bottomright is updated in the OnUpdate (to manage the resize button)

  -- close button
  itemsFrameUI.closeButton = CreateFrame("Button", "closeButton", itemsFrameUI, "NysTDL_CloseButton");
  itemsFrameUI.closeButton:SetPoint("TOPRIGHT", itemsFrameUI, "TOPRIGHT", -1, -1);
  itemsFrameUI.closeButton:SetScript("onClick", function(self) self:GetParent():Hide(); end);

  -- resize button
  itemsFrameUI.resizeButton = CreateFrame("Button", nil, itemsFrameUI, "NysTDL_TooltipResizeButton")
  itemsFrameUI.resizeButton.tooltip = L["Left click - resize"].."\n"..L["Right click - reset"];
  itemsFrameUI.resizeButton:SetPoint("BOTTOMRIGHT", -3, 3)
  itemsFrameUI.resizeButton:SetScript("OnMouseDown", function(self, button)
    if (button == "LeftButton") then
      itemsFrameUI:StartSizing("BOTTOMRIGHT")
      self:GetHighlightTexture():Hide() -- more noticeable
      self.MiniTooltip:Hide()
    end
  end)
  itemsFrameUI.resizeButton:SetScript("OnMouseUp", function(self, button)
    if (button == "LeftButton") then
      itemsFrameUI:StopMovingOrSizing()
      self:GetHighlightTexture():Show()
      self.MiniTooltip:Show()
    end
  end)
  itemsFrameUI.resizeButton:SetScript("OnHide", function(self)  -- same as on mouse up, just security
    itemsFrameUI:StopMovingOrSizing()
    self:GetHighlightTexture():Show()
  end)
  itemsFrameUI.resizeButton:RegisterForClicks("RightButtonUp")
  itemsFrameUI.resizeButton:HookScript("OnClick", function() -- reset size
    itemsFrameUI:SetSize(340, 400);
  end)

  -- Generating the tabs --
  AllTab, DailyTab, WeeklyTab = SetTabs(itemsFrameUI, 3, L["All"], L["Daily"], L["Weekly"]);

  -- Initializing the frame with the current data
  itemsFrame:Init();

  itemsFrameUI:Hide();
end
