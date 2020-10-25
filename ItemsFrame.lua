--------------------------------------
-- Namespaces
--------------------------------------
local _, tdlTable = ...;
tdlTable.itemsFrame = {}; -- adds itemsFrame table to addon namespace

local config = tdlTable.config;
local itemsFrame = tdlTable.itemsFrame;


-- Variables declaration:--
local itemsFrameUI, toggleBtn;
local AllTab, DailyTab, WeeklyTab;

local checkBtn = {};
local minusBtn = {};
local addBtn = {};
local label = {};
local editBox = {};

local All = {}

local lastLoadedTab;
local ItemsFrame_Update;
local ItemsFrame_UpdateTime;
local refreshRate = 1;


function itemsFrame:Toggle()
	if (not itemsFrameUI:IsShown()) then -- We update the frame if we are about to show it
		ItemsFrame_UpdateTime();
		ItemsFrame_Update();
	end
	itemsFrameUI:SetShown(not itemsFrameUI:IsShown());
end

function itemsFrame:ToggleBtn()
	toggleBtn:SetShown(not toggleBtn:IsShown());
end

function itemsFrame:SetChecked(btnName)
	checkBtn[btnName]:SetChecked(true);
	ItemsFrame_Update();
end

--------------------------------------
-- Script functions
--------------------------------------
local function ScrollFrame_OnMouseWheel(self, delta)
	local newValue = self:GetVerticalScroll() - (delta * 35);

	if (newValue < 0) then
		newValue = 0;
	elseif (newValue > self:GetVerticalScrollRange()) then
		newValue = self:GetVerticalScrollRange();
	end

	self:SetVerticalScroll(newValue);
end

local function resetBtns(tabName)
	local ressetedSomething = false;

	for i=1,#All do
		if (tabName == "All") then
			if (config:HasItem(All, checkBtn[All[i]]:GetName())) then -- the All table isn't in the saved variable
				if (checkBtn[All[i]]:GetChecked()) then
					ressetedSomething = true;
				end

				checkBtn[All[i]]:SetChecked(false);
			end
		elseif (config:HasItem(ToDoListSV_itemsList[tabName], checkBtn[All[i]]:GetName())) then
			if (checkBtn[All[i]]:GetChecked()) then
				ressetedSomething = true;
			end

			checkBtn[All[i]]:SetChecked(false);
		end
	end
	ItemsFrame_Update();
	if (ressetedSomething) then -- so that we print this message only if there was checked items before the reset
		config:Print("Resseted "..tabName.." succesfully!")
	end
end

local function UpdateNextDailyReset()
	timeUntil = config:GetTimeUntilReset();
	AllTab.nextDailyReset:SetText("Next daily reset: "..timeUntil.hour.."h "..timeUntil.min.."m "..timeUntil.sec.."s")
end

local function UpdateNextWeeklyReset()
	timeUntil = config:GetTimeUntilReset();
	AllTab.nextWeeklyReset:SetText("Next weekly reset: "..timeUntil.days.."d "..timeUntil.hour.."h "..timeUntil.min.."m "..timeUntil.sec.."s")
end

local function inChatIsDone(all,daily,weekly)
	if (all == 0 and AllTab.remainingNumber ~= 0 and next(All) ~= nil) then
		config:Print("You've finished everything! (yay :D)");
	elseif (daily == 0 and DailyTab.remainingNumber ~= 0 and next(ToDoListSV_itemsList["Daily"]) ~= nil) then
		config:Print("You've finished everything for today!");
	elseif (weekly == 0 and WeeklyTab.remainingNumber ~= 0 and next(ToDoListSV_itemsList["Weekly"]) ~= nil) then
		config:Print("You've finished everything for this week!");
	end
end

local function UpdateRemainingNumber()
	local numberAll,numberDaily,numberWeekly = 0,0,0;
	for i=1,#All do
		if (not checkBtn[All[i]]:GetChecked()) then
			if (config:HasItem(ToDoListSV_itemsList["Daily"],checkBtn[All[i]]:GetName())) then
				numberDaily = numberDaily + 1;
			end
			if (config:HasItem(ToDoListSV_itemsList["Weekly"],checkBtn[All[i]]:GetName())) then
				numberWeekly = numberWeekly + 1;
			end
			numberAll = numberAll + 1;
		end
	end

	inChatIsDone(numberAll, numberDaily, numberWeekly)

	AllTab.remaining:SetText("Remaining: "..numberAll)
	AllTab.remainingNumber = numberAll;

	DailyTab.remaining:SetText("Remaining: "..numberDaily)
	DailyTab.remainingNumber = numberDaily;

	WeeklyTab.remaining:SetText("Remaining: "..numberWeekly)
	WeeklyTab.remainingNumber = numberWeekly;
end

function config:GetRemainingNumber()
	return AllTab.remainingNumber, DailyTab.remainingNumber, WeeklyTab.remainingNumber;
end

local function UpdateCheckButtons()
	for i=1,#All do
		if (checkBtn[All[i]]:GetChecked()) then
			checkBtn[All[i]].text:SetTextColor(0,1,0);
		else
			checkBtn[All[i]].text:SetTextColor(1,0.85,0);
		end
	end
end

-- Saved variables functions:

local function loadSavedVariables()
	for i=1,#All do
		if (config:HasItem(ToDoListSV_checkedButtons, checkBtn[All[i]]:GetName())) then
			checkBtn[All[i]]:SetChecked(true);
		end
	end
end

local function SaveSavedVariables()
	for i=1,#All do
    local isPresent, pos = config:HasItem(ToDoListSV_checkedButtons, checkBtn[All[i]]:GetName());

		if (checkBtn[All[i]]:GetChecked() and not isPresent) then
      table.insert(ToDoListSV_checkedButtons, checkBtn[All[i]]:GetName());
		end

		if (not checkBtn[All[i]]:GetChecked() and isPresent) then
			table.remove(ToDoListSV_checkedButtons, pos);
		end
	end
end

local function autoReset()
	if time() > ToDoListSV_autoReset["Weekly"] then
		ToDoListSV_autoReset["Daily"] = config:GetSecondsToReset().daily;
		ToDoListSV_autoReset["Weekly"] = config:GetSecondsToReset().weekly;
		resetBtns("Daily");
		resetBtns("Weekly");
	elseif time() > ToDoListSV_autoReset["Daily"] then
		ToDoListSV_autoReset["Daily"] = config:GetSecondsToReset().daily;
		resetBtns("Daily");
	end
end

-- Items modifications
function itemsFrame:UpdateAllTable()
	All = {}
	-- Completing the All table
	for k,val in pairs(ToDoListSV_itemsList) do
		if (k ~= "Daily" and k ~= "Weekly") then
			for _,v in pairs(val) do
				table.insert(All, v);
			end
		end
	end
end

local function addItem(self, db)
	local modif = false;
	local stop = false; -- we can't use return; here, so we do it manually (but it's horrible yes)
	local name, case, cat;
	local new = false;

	if (type(db) ~= "table") then
		name = self:GetParent():GetText(); -- we get the name the player entered
		self:GetParent():SetText("");
		case = self:GetParent():GetParent():GetName(); -- we get the tab we're on
		cat = self:GetParent():GetName(); -- we get the category we're adding the item in
	else
		name = db.name;
		case = db.case;
		cat = db.cat;
	end

	if case == "All" then
		case = nil;
	end

	if (name ~= "") then -- if we typed something
		local isPresent0, isPresent1, isPresent2, isPresent3, hasKey;

		isPresent1 = (select(1, config:HasItem(All, name))); -- does it already exists in All?


		hasKey = config:HasKey(ToDoListSV_itemsList, cat);
		if (not hasKey) then ToDoListSV_itemsList[cat] = {}; new = true; end -- that means we'll be adding something to a new category, so we create the table to hold all theses shiny new items

		if (case == nil) then
			isPresent0 = (select(1, config:HasItem(ToDoListSV_itemsList[cat], name)));-- does it already exists in the typed category?
		else
			isPresent0 = (select(1, config:HasItem(ToDoListSV_itemsList[case], name)));-- does it already exists in Daily/Weekly?
			isPresent3 = (select(1, config:HasItem(ToDoListSV_itemsList[cat], name)));-- does it already exists in the typed category?
			if (isPresent1 and not isPresent3) then -- if it already exists but not in this category
				config:Print("This item name already exists!");
				stop = true;
			end
		end

		if (not stop) then
			if (not isPresent0) then
				if (case == "Daily") then
					isPresent2 = (select(1, config:HasItem(ToDoListSV_itemsList["Weekly"], name)));
				elseif (case == "Weekly") then
					isPresent2 = (select(1, config:HasItem(ToDoListSV_itemsList["Daily"], name)));
				else
					stop = true;
					if (not isPresent1) then
						table.insert(ToDoListSV_itemsList[cat], name);
						config:Print("\""..name.."\" added to "..cat.."!");
						modif = true;
					else
						config:Print("This item name already exists!");
					end
				end
				if (not stop) then
					if (not isPresent1) then
						table.insert(ToDoListSV_itemsList[cat], name);
						table.insert(ToDoListSV_itemsList[case], name);
						config:Print("\""..name.."\" added to "..case.."!");
						modif = true;
					elseif (not isPresent2) then
						table.insert(ToDoListSV_itemsList[case], name);
						config:Print("\""..name.."\" added to "..case.."!");
						modif = true;
					else
						config:Print("No item can be daily and weekly!");
					end
				end
			else
				config:Print("This item is already here in this category!");
			end
		end
	else
		config:Print("Please enter the name of the item!");
	end

	if (new and not modif) then -- if we didn't add anything and it was supposed to create a new category, we cancel our move and nil this false new empty category
		ToDoListSV_itemsList[cat] = nil;
	end

	itemsFrame:RefreshTab(cat, name, "Add", modif);
end

local function removeItem(self)
	local modif = false;
	local isPresent, pos;

	name = self:GetParent():GetName(); -- we get the name of the tied check button
	case = self:GetParent():GetParent():GetName(); -- we get the tab we're on
	cat = (select(2,self:GetParent():GetPoint())):GetName(); -- we get the category we're in
	if case == "All" then
		case = nil;
	end

	if (case ~= nil) then -- if we're not in the All tab
		table.remove(ToDoListSV_itemsList[case], (select(2,config:HasItem(ToDoListSV_itemsList[case], name))));
		config:Print("\""..name.."\" removed from "..case.."!");
		modif = true;
	else
		-- All part
		table.remove(ToDoListSV_itemsList[cat], (select(2,config:HasItem(ToDoListSV_itemsList[cat], name))));
		-- Daily part
		isPresent, pos = config:HasItem(ToDoListSV_itemsList["Daily"], name);
		if (isPresent) then
			table.remove(ToDoListSV_itemsList["Daily"], pos);
		end
		-- Weekly part
		isPresent, pos = config:HasItem(ToDoListSV_itemsList["Weekly"], name);
		if (isPresent) then
			table.remove(ToDoListSV_itemsList["Weekly"], pos);
		end
		config:Print("\""..name.."\" removed!");
		modif = true;
	end

	itemsFrame:RefreshTab(case, name, "Remove", modif);
end

local function addCategory()
	local db = {}

	db.cat = itemsFrameUI.categoryEditBox:GetText();
	if (db.cat == "") then
		config:Print("Please enter a category name!")
		return;
	end

	db.name = itemsFrameUI.nameEditBox:GetText();
	if (db.name == "") then
		config:Print("Please enter the name of the item!")
		return;
	end

	db.case = itemsFrameUI.label1:GetParent():GetName();

	itemsFrameUI.categoryEditBox:SetText("");
	itemsFrameUI.nameEditBox:SetText("");
	addItem(nil, db);
end


--	Frame update:
ItemsFrame_Update = function(...)
	itemsFrame:UpdateAllTable();
	UpdateRemainingNumber();
	UpdateCheckButtons();
	SaveSavedVariables();
end

ItemsFrame_UpdateTime = function()
	autoReset();
	UpdateNextDailyReset();
	UpdateNextWeeklyReset();
end

local function ItemsFrame_OnUpdate(self, elapsed) -- Updating the itemsFrame every 1 second
	self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed;
	while (self.TimeSinceLastUpdate > refreshRate) do
		ItemsFrame_UpdateTime();
		self.TimeSinceLastUpdate = self.TimeSinceLastUpdate - refreshRate;
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

local function loadCategories(tab,category,categorylabel,totalLength,constraint, catName)
	if (totalLength == 0) then -- doing that only one time
		for i=1,#All do
			checkBtn[All[i]]:Hide();
			minusBtn[All[i]]:Hide();
		end
	end

	if (constraint ~= nil) then
		local cat = {}
		for i=1,#category do
			if (select(1,config:HasItem(constraint,category[i]))) then
				table.insert(cat,category[i]);
			end
		end
		category = cat;
	end

	if (config:HasAtLeastOneItem(All,category)) then
		categorylabel:SetParent(tab);
		categorylabel:SetPoint("TOPLEFT", tab.dummyLabel, "TOPLEFT", 0, -totalLength*23);
		categorylabel:Show();

		editBox[categorylabel:GetName()]:SetParent(tab);
		editBox[categorylabel:GetName()]:SetPoint("LEFT", categorylabel, "LEFT", 150, 0);
		editBox[categorylabel:GetName()]:Show();
		totalLength = totalLength + 1;

		local buttonsLength = 1;
		for i=1,#All do
			if ((select(1,config:HasItem(category,checkBtn[All[i]]:GetName())))) then
				checkBtn[All[i]]:SetParent(tab);
				checkBtn[All[i]]:SetPoint("TOPLEFT", categorylabel, "TOPLEFT", 30, -22*buttonsLength+5);
				totalLength = totalLength + 1;
				buttonsLength = buttonsLength + 1;

				checkBtn[All[i]]:Show();
				minusBtn[All[i]]:Show();
			end
		end
	else
		categorylabel:Hide();
		editBox[categorylabel:GetName()]:Hide();

		if (constraint == nil) then -- if there is no more item in a category, we delete the corresponding label and table
			ToDoListSV_itemsList[catName] = nil;
			addBtn[categorylabel:GetName()] = nil;
			editBox[categorylabel:GetName()] = nil;
			label[categorylabel:GetName()] = nil;
		end
	end
	return totalLength;
end

local function loadMovable()
	-- All items transformed as checkboxes
	for i=1,#All,1 do
		checkBtn[All[i]] = CreateFrame("CheckButton", All[i], itemsFrameUI, "UICheckButtonTemplate");
		checkBtn[All[i]].text:SetText(All[i]);
		checkBtn[All[i]].text:SetFontObject("GameFontNormalLarge");
		checkBtn[All[i]]:SetScript("OnClick", ItemsFrame_Update);

		minusBtn[All[i]] = config:CreateMinusButton(checkBtn[All[i]]);
		minusBtn[All[i]]:SetScript("OnClick", removeItem);
	end

	-- Category labels
	for k,i in pairs(ToDoListSV_itemsList) do
		if (k ~= "Daily" and k ~= "Weekly") then
			label[k] = config:CreateNoPointsLabel(itemsFrameUI,k,tostring(k.." :"));
			editBox[k] = config:CreateNoPointsLabelEditBox(k);
			editBox[k]:SetScript("OnEnterPressed", function(self) addItem(addBtn[self:GetName()]) end); -- if we press enter, it's blike we clicked on the add button
			addBtn[k] = config:CreateAddButton(editBox[k]);
			addBtn[k]:SetScript("OnClick", addItem);
		end
	end
end

-------------------------------------------------------------------------------------------
-- Contenting:<3 --------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

----------------------------------
-- All tab content
----------------------------------
local function AllTabContent()
	-- Reset button
	AllTab.resetAllBtn = config:CreateButton("CENTER", AllTab, "TOP", 0, -40, "Reset All");
	AllTab.resetAllBtn:SetScript("OnClick", function(self) resetBtns(self:GetParent():GetName()) end);

	-- Position dummy
	AllTab.dummyLabel = config:CreateDummy(AllTab,5,-140);

	-- Labels
	AllTab.nextDailyReset = config:CreateLabel("TOPLEFT",AllTab,"TOPLEFT",50,-80,"Next daily reset:");
	AllTab.nextWeeklyReset = config:CreateLabel("TOPLEFT",AllTab,"TOPLEFT",25,-105,"Next weekly reset:");
	AllTab.remaining = config:CreateLabel("TOPLEFT",AllTab,"TOPLEFT",100,-135,"Remaining:");
	AllTab.line = config:CreateLabel("TOPLEFT",AllTab,"TOPLEFT",35,-155,"_____________________________");
end

local function loadAllTab()
	local length = 0;
	for k,i in pairs(ToDoListSV_itemsList) do
		if (k ~= "Daily" and k ~= "Weekly") then
			length = loadCategories(AllTab,i,label[k],length, nil, k);
		end
	end

	itemsFrameUI.label1:SetParent(AllTab);
	itemsFrameUI.label1:SetPoint("TOPLEFT", AllTab.dummyLabel, "TOPLEFT", 60, -length*23 - 10);

	itemsFrameUI.label2:SetParent(AllTab);
	itemsFrameUI.label2:SetPoint("TOPLEFT", itemsFrameUI.label1, "TOPLEFT", -55, -25);
	itemsFrameUI.categoryEditBox:SetParent(AllTab);
	itemsFrameUI.categoryEditBox:SetPoint("RIGHT", itemsFrameUI.label2, "RIGHT", 150, 0);

	itemsFrameUI.label3:SetParent(AllTab);
	itemsFrameUI.label3:SetPoint("TOPLEFT", itemsFrameUI.label1, "TOPLEFT", -55, -50);
	itemsFrameUI.nameEditBox:SetParent(AllTab);
	itemsFrameUI.nameEditBox:SetPoint("RIGHT", itemsFrameUI.label3, "RIGHT", 150, 0);
end

----------------------------------
-- Daily tab content
----------------------------------
local function DailyTabContent()
	-- Reset button
	DailyTab.resetDailyBtn = config:CreateButton("CENTER", DailyTab, "TOP", 0, -40, "Reset Daily");
	DailyTab.resetDailyBtn:SetScript("OnClick", function(self) resetBtns(self:GetParent():GetName()) end);

	-- Position dummy
	DailyTab.dummyLabel = config:CreateDummy(DailyTab,5,-100);

	-- Labels
	DailyTab.remaining = config:CreateLabel("TOPLEFT",DailyTab,"TOPLEFT",100,-80,"Remaining:");
	DailyTab.line = config:CreateLabel("TOPLEFT",DailyTab,"TOPLEFT",40,-100,"___________________________");
end

local function loadDailyTab()
	local length = 0;
	for k,i in pairs(ToDoListSV_itemsList) do
		if (k ~= "Daily" and k ~= "Weekly") then
			length = loadCategories(DailyTab,i,label[k],length,ToDoListSV_itemsList["Daily"], k);
		end
	end

	itemsFrameUI.label1:SetParent(DailyTab);
	itemsFrameUI.label1:SetPoint("TOPLEFT", DailyTab.dummyLabel, "TOPLEFT", 60, -length*23 - 10);

	itemsFrameUI.label2:SetParent(DailyTab);
	itemsFrameUI.label2:SetPoint("TOPLEFT", itemsFrameUI.label1, "TOPLEFT", -55, -25);
	itemsFrameUI.categoryEditBox:SetParent(DailyTab);
	itemsFrameUI.categoryEditBox:SetPoint("RIGHT", itemsFrameUI.label2, "RIGHT", 150, 0);

	itemsFrameUI.label3:SetParent(DailyTab);
	itemsFrameUI.label3:SetPoint("TOPLEFT", itemsFrameUI.label1, "TOPLEFT", -55, -50);
	itemsFrameUI.nameEditBox:SetParent(DailyTab);
	itemsFrameUI.nameEditBox:SetPoint("RIGHT", itemsFrameUI.label3, "RIGHT", 150, 0);
end

----------------------------------
-- Weekly tab content
----------------------------------
local function WeeklyTabContent()
	-- Reset button
	WeeklyTab.resetWeeklyBtn = config:CreateButton("CENTER", WeeklyTab, "TOP", 0, -40, "Reset Weekly");
	WeeklyTab.resetWeeklyBtn:SetScript("OnClick", function(self) resetBtns(self:GetParent():GetName()) end);

	-- Position dummy
	WeeklyTab.dummyLabel = config:CreateDummy(WeeklyTab,5,-100);

	-- Labels
	WeeklyTab.remaining = config:CreateLabel("TOPLEFT",WeeklyTab,"TOPLEFT",100,-80,"Remaining:");
	WeeklyTab.line = config:CreateLabel("TOPLEFT",WeeklyTab,"TOPLEFT",40,-100,"___________________________");
end

local function loadWeeklyTab()
	local length = 0;
	for k,i in pairs(ToDoListSV_itemsList) do
		if (k ~= "Daily" and k ~= "Weekly") then
			length = loadCategories(WeeklyTab,i,label[k],length,ToDoListSV_itemsList["Weekly"], k);
		end
	end

	itemsFrameUI.label1:SetParent(WeeklyTab);
	itemsFrameUI.label1:SetPoint("TOPLEFT", WeeklyTab.dummyLabel, "TOPLEFT", 60, -length*23 - 10);

	itemsFrameUI.label2:SetParent(WeeklyTab);
	itemsFrameUI.label2:SetPoint("TOPLEFT", itemsFrameUI.label1, "TOPLEFT", -55, -25);
	itemsFrameUI.categoryEditBox:SetParent(WeeklyTab);
	itemsFrameUI.categoryEditBox:SetPoint("RIGHT", itemsFrameUI.label2, "RIGHT", 150, 0);

	itemsFrameUI.label3:SetParent(WeeklyTab);
	itemsFrameUI.label3:SetPoint("TOPLEFT", itemsFrameUI.label1, "TOPLEFT", -55, -50);
	itemsFrameUI.nameEditBox:SetParent(WeeklyTab);
	itemsFrameUI.nameEditBox:SetPoint("RIGHT", itemsFrameUI.label3, "RIGHT", 150, 0);
end

----------------------------------
-- Creating the tabs
----------------------------------
-- Selecting the tab
local function Tab_OnClick(self)
	PanelTemplates_SetTab(self:GetParent(), self:GetID());

	local scrollChild = itemsFrameUI.ScrollFrame:GetScrollChild();
	if (scrollChild) then
		scrollChild:Hide();
	end

	itemsFrameUI.ScrollFrame:SetScrollChild(self.content);

	-- we update the frame before loading the tab if there are changes pending
	ItemsFrame_Update();

	-- Loading the good tab
	if (self:GetName() == "ToDoListconfigTab1") then loadAllTab() end
	if (self:GetName() == "ToDoListconfigTab2") then loadDailyTab() end
	if (self:GetName() == "ToDoListconfigTab3") then loadWeeklyTab() end

	-- we update the frame after loading the tab to refresh the display
	ItemsFrame_Update();

	lastLoadedTab = self;

	self.content:Show();
end

-- if the last tab we were on is getting an update
-- because of an add or remove of an item, we re-update it
function itemsFrame:RefreshTab(cat, name, action, modif)
	if (modif) then
		-- Removing case
		if (action == "Remove") then
			if (cat == nil) then
				local isPresent, pos = config:HasItem(ToDoListSV_checkedButtons, checkBtn[name]:GetName());
				if (checkBtn[name]:GetChecked() and isPresent) then
		      table.remove(ToDoListSV_checkedButtons, pos);
				end

				checkBtn[name]:Hide();	-- get out of my view mate
				minusBtn[name] = nil;
				checkBtn[name] = nil;
			end

			Tab_OnClick(lastLoadedTab); -- we reload the tab to instantly display the changes
		end

		-- Adding case
		if (action == "Add") then
			-- we create the new check button
			if (checkBtn[name] == nil) then
				checkBtn[name] = CreateFrame("CheckButton", name, itemsFrameUI, "UICheckButtonTemplate");
				checkBtn[name].text:SetText(name);
				checkBtn[name].text:SetFontObject("GameFontNormalLarge");
				checkBtn[name]:SetScript("OnClick", ItemsFrame_Update);

				minusBtn[name] = config:CreateMinusButton(checkBtn[name]);
				minusBtn[name]:SetScript("OnClick", removeItem);
			end
			-- we create the corresponding label (if it is a new one)
			if (label[cat] == nil) then
				label[cat] = config:CreateNoPointsLabel(itemsFrameUI,cat,tostring(cat.." :"));
				editBox[cat] = config:CreateNoPointsLabelEditBox(cat);
				editBox[cat]:SetScript("OnEnterPressed", function(self) addItem(addBtn[self:GetName()]) end); -- if we press enter, it's blike we clicked on the add button
				addBtn[cat] = config:CreateAddButton(editBox[cat]);
				addBtn[cat]:SetScript("OnClick", addItem);
			end

			Tab_OnClick(lastLoadedTab); -- we reload the tab to instantly display the changes
		end
	end
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

		tab.content = CreateFrame("Frame",  (select(i, ...)), itemsFrameUI.ScrollFrame);
		tab.content:SetSize(308, 1); -- y is determined by number of elements
		tab.content:Hide();

		table.insert(contents, tab.content);

		if (i == 1) then -- position
			tab:SetPoint("TOPLEFT", itemsFrameUI, "BOTTOMLEFT", 5, 7);
		else
			tab:SetPoint("TOPLEFT", _G[frameName.."Tab"..(i - 1)], "TOPRIGHT", -14, 0);
		end
	end

	return unpack(contents);
end

---Creating the main window----
function config:CreateItemsFrame()

	itemsFrameUI = CreateFrame("Frame", "ToDoListconfig", UIParent, "UIPanelDialogTemplate");
	itemsFrameUI:SetSize(350, 400);
	itemsFrameUI:SetPoint("CENTER"); -- Doesn't need to be ("CENTER", UIParent, "CENTER")

	itemsFrameUI.Title:ClearAllPoints();
	itemsFrameUI.Title:SetFontObject("GameFontHighlight");
	itemsFrameUI.Title:SetPoint("LEFT", ToDoListconfigTitleBG, "LEFT", (itemsFrameUI:GetWidth()/2)-50, 1);
	itemsFrameUI.Title:SetText("To do list");

	itemsFrameUI.label1 = itemsFrameUI:CreateFontString(nil); -- info label 1
	itemsFrameUI.label1:SetFontObject("GameFontHighlightLarge");
	itemsFrameUI.label1:SetText("Add a new category:");

	itemsFrameUI.label2 = itemsFrameUI:CreateFontString(nil); -- info label
	itemsFrameUI.label2:SetFontObject("GameFontHighlightLarge");
	itemsFrameUI.label2:SetText("Category name:");

	itemsFrameUI.categoryEditBox = CreateFrame("EditBox", nil, itemsFrameUI, "InputBoxTemplate"); -- edit box to put the new category name
	itemsFrameUI.categoryEditBox:SetSize(130, 30);
	itemsFrameUI.categoryEditBox:SetAutoFocus(false);
	itemsFrameUI.categoryEditBox:SetScript("OnKeyDown", function(self, key) if (key == "TAB") then itemsFrameUI.nameEditBox:SetFocus() end end) -- to switch easily between the two edit boxes
	itemsFrameUI.categoryEditBox:SetScript("OnEnterPressed", addCategory); -- if we press enter, it's like we clicked on the add button

	itemsFrameUI.label3 = itemsFrameUI:CreateFontString(nil); -- info label
	itemsFrameUI.label3:SetFontObject("GameFontHighlightLarge");
	itemsFrameUI.label3:SetText("Item name:");

	itemsFrameUI.nameEditBox = CreateFrame("EditBox", nil, itemsFrameUI, "InputBoxTemplate"); -- edit box tp put the name of the first item
	itemsFrameUI.nameEditBox:SetSize(130, 30);
	itemsFrameUI.nameEditBox:SetAutoFocus(false);
	itemsFrameUI.nameEditBox:SetScript("OnKeyDown", function(self, key) if (key == "TAB") then itemsFrameUI.categoryEditBox:SetFocus() end end)
	itemsFrameUI.nameEditBox:SetScript("OnEnterPressed", addCategory); -- if we press enter, it's like we clicked on the add button

	itemsFrameUI.addBtn = config:CreateAddButton(itemsFrameUI.nameEditBox);
	itemsFrameUI.addBtn:SetScript("onClick", addCategory)

	itemsFrameUI.TimeSinceLastUpdate = 0;

	itemsFrameUI.ScrollFrame = CreateFrame("ScrollFrame", nil, itemsFrameUI, "UIPanelScrollFrameTemplate");
	itemsFrameUI.ScrollFrame:SetPoint("TOPLEFT", ToDoListconfigDialogBG, "TOPLEFT", 4, -8);
	itemsFrameUI.ScrollFrame:SetPoint("BOTTOMRIGHT", ToDoListconfigDialogBG, "BOTTOMRIGHT", -3, 4);
	itemsFrameUI.ScrollFrame:SetClipsChildren(true);

	itemsFrameUI.ScrollFrame:SetScript("OnMouseWheel", ScrollFrame_OnMouseWheel);

	itemsFrameUI.ScrollFrame.ScrollBar:ClearAllPoints();
  itemsFrameUI.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", itemsFrameUI.ScrollFrame, "TOPRIGHT", -12, -18);
  itemsFrameUI.ScrollFrame.ScrollBar:SetPoint("BOTTOMRIGHT", itemsFrameUI.ScrollFrame, "BOTTOMRIGHT", -7, 18);

	itemsFrameUI:SetScript("OnUpdate", ItemsFrame_OnUpdate);

	itemsFrameUI:SetMovable(true);
	itemsFrameUI:SetClampedToScreen(true);
	itemsFrameUI:EnableMouse(true);

	itemsFrameUI:RegisterForDrag("LeftButton");	-- to move the frame
	itemsFrameUI:SetScript("OnDragStart", itemsFrameUI.StartMoving);
	itemsFrameUI:SetScript("OnDragStop", itemsFrameUI.StopMovingOrSizing);

	-- Generating the tabs:--
	AllTab, DailyTab, WeeklyTab = SetTabs(itemsFrameUI, 3, "All", "Daily", "Weekly");

	-- Generating the core --
	itemsFrame:UpdateAllTable();
	loadMovable();
	loadSavedVariables();

	-- Generating the content --
	AllTabContent();
	DailyTabContent();
	WeeklyTabContent();

	-- Updating everything once and hiding the UI
	ItemsFrame_UpdateTime(); -- for the auto reset check (we could wait 1 sec, but nah we don't have the time)

	-- Selecting the first tab (All)
	Tab_OnClick(_G["ToDoListconfigTab1"]);

	itemsFrameUI:Hide();

	-- Creating the button to easily toggle the frame
	toggleBtn = CreateFrame("Button", "ToDoListToggleButton", UIParent, "UIPanelButtonTemplate");
	toggleBtn:SetSize(100,35);
	toggleBtn:SetPoint("Center");
	toggleBtn:SetText("ToDoList");
	toggleBtn:SetNormalFontObject("GameFontNormalLarge");
	toggleBtn:SetHighlightFontObject("GameFontHighlightLarge");

	toggleBtn:SetMovable(true);
	toggleBtn:EnableMouse(true);
	toggleBtn:SetClampedToScreen(true);
	toggleBtn:RegisterForDrag("LeftButton");
	toggleBtn:SetScript("OnDragStart", toggleBtn.StartMoving);
	toggleBtn:SetScript("OnDragStop", toggleBtn.StopMovingOrSizing);

	toggleBtn:SetScript("OnClick", itemsFrame.Toggle);
end
