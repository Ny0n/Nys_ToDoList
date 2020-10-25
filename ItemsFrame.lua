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
local remainingCheckAll, remainingCheckDaily, remainingCheckWeekly = 0,0,0;

local checkBtn = {};
local removeBtn = {};
local addBtn = {};
local label = {};
local editBox = {};
local labelHover = {};
local labelNewCatHover;

local All = {};

local ItemsFrame_Update;
local ItemsFrame_UpdateTime;
local Tab_OnClick;
local refreshRate = 1;

--------------------------------------
-- General functions
--------------------------------------

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

function itemsFrame:ResetBtns(tabName)
	local uncheckedSomething = false;

	for i=1,#All do
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
			config:Print("Unchecked "..tabName.."!");
		else
			config:Print("Unchecked "..tabName.." tab!");
		end
	end
end

local function inChatIsDone(all,daily,weekly)
	if (all == 0 and remainingCheckAll ~= 0 and next(All) ~= nil) then
		config:Print("You've done everything! (yay :D)");
	elseif (daily == 0 and remainingCheckDaily ~= 0 and next(ToDoListSV.itemsList["Daily"]) ~= nil) then
		config:Print("Everything's done for today!");
	elseif (weekly == 0 and remainingCheckWeekly ~= 0 and next(ToDoListSV.itemsList["Weekly"]) ~= nil) then
		config:Print("Everything's done for this week!");
	end
end

local function UpdateRemainingNumber()
	local numberAll,numberDaily,numberWeekly = 0,0,0;
	for i=1,#All do
		if (not checkBtn[All[i]]:GetChecked()) then
			if (config:HasItem(ToDoListSV.itemsList["Daily"],checkBtn[All[i]]:GetName())) then
				numberDaily = numberDaily + 1;
			end
			if (config:HasItem(ToDoListSV.itemsList["Weekly"],checkBtn[All[i]]:GetName())) then
				numberWeekly = numberWeekly + 1;
			end
			numberAll = numberAll + 1;
		end
	end

	inChatIsDone(numberAll, numberDaily, numberWeekly);

	local tab = itemsFrameUI.remaining:GetParent();
	if (tab == AllTab) then
		itemsFrameUI.remaining:SetText("Remaining: ".."|cff00ffb3"..numberAll.."|r");
		remainingCheckAll = numberAll;
	elseif (tab == DailyTab) then
		itemsFrameUI.remaining:SetText("Remaining: ".."|cff00ffb3"..numberDaily.."|r");
		remainingCheckDaily = numberDaily;
	elseif (tab == WeeklyTab) then
		itemsFrameUI.remaining:SetText("Remaining: ".."|cff00ffb3"..numberWeekly.."|r");
		remainingCheckWeekly = numberWeekly;
	end
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

-- Saved variable functions:

local function loadSavedVariable()
	for i=1,#All do
		if (config:HasItem(ToDoListSV.checkedButtons, checkBtn[All[i]]:GetName())) then
			checkBtn[All[i]]:SetChecked(true);
		end
	end
end

local function SaveSavedVariable()
	for i=1,#All do
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
		itemsFrame:ResetBtns("Daily");
		itemsFrame:ResetBtns("Weekly");
	elseif time() > ToDoListSV.autoReset["Daily"] then
		ToDoListSV.autoReset["Daily"] = config:GetSecondsToReset().daily;
		itemsFrame:ResetBtns("Daily");
	end
end

-- Items modifications
function UpdateAllTable()
	All = {}
	-- Completing the All table
	for k,val in pairs(ToDoListSV.itemsList) do
		if (k ~= "Daily" and k ~= "Weekly") then
			for _,v in pairs(val) do
				table.insert(All, v);
			end
		end
	end
	table.sort(All); -- so that every item will be sorted alphabetically in the list
end

local function addItem(self, db)
	local modif = false;
	local stop = false; -- we can't use return; here, so we do it manually (but it's horrible yes)
	local name, case, cat;
	local new = false;

	if (type(db) ~= "table") then
		name = self:GetParent():GetText(); -- we get the name the player entered
		case = self:GetParent():GetParent():GetName(); -- we get the tab we're on
		cat = self:GetParent():GetName(); -- we get the category we're adding the item in

		local l = config:CreateNoPointsLabel(itemsFrameUI, nil, name);
		if (l:GetWidth()>240) then -- is it too big?
			config:Print("This item name is too big!")
			return;
		end

		self:GetParent():SetText(""); -- we clear the editbox
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


		hasKey = config:HasKey(ToDoListSV.itemsList, cat);
		if (not hasKey) then ToDoListSV.itemsList[cat] = {}; new = true; end -- that means we'll be adding something to a new category, so we create the table to hold all theses shiny new items

		if (case == nil) then
			isPresent0 = (select(1, config:HasItem(ToDoListSV.itemsList[cat], name)));-- does it already exists in the typed category?
		else
			isPresent0 = (select(1, config:HasItem(ToDoListSV.itemsList[case], name)));-- does it already exists in Daily/Weekly?
			isPresent3 = (select(1, config:HasItem(ToDoListSV.itemsList[cat], name)));-- does it already exists in the typed category?
			if (isPresent1 and not isPresent3) then -- if it already exists but not in this category
				config:Print("This item name already exists!");
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
						config:Print("\""..name.."\" added to "..cat.."!");
						modif = true;
					else
						config:Print("This item name already exists!");
					end
				end
				if (not stop) then
					if (not isPresent1) then
						table.insert(ToDoListSV.itemsList[cat], name);
						table.insert(ToDoListSV.itemsList[case], name);
						config:Print("\""..name.."\" added to "..case.."!");
						modif = true;
					elseif (not isPresent2) then
						table.insert(ToDoListSV.itemsList[case], name);
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
		ToDoListSV.itemsList[cat] = nil;
	end

	itemsFrame:RefreshTab(cat, name, "Add", modif);
end

local function removeItem(self)
	local modif = false;
	local isPresent, pos;

	name = self:GetParent():GetName(); -- we get the name of the tied check button
	cat = (select(2,self:GetParent():GetPoint())):GetName(); -- we get the category we're in

	-- All part
	table.remove(ToDoListSV.itemsList[cat], (select(2,config:HasItem(ToDoListSV.itemsList[cat], name))));
	-- Daily part
	isPresent, pos = config:HasItem(ToDoListSV.itemsList["Daily"], name);
	if (isPresent) then
		table.remove(ToDoListSV.itemsList["Daily"], pos);
	end
	-- Weekly part
	isPresent, pos = config:HasItem(ToDoListSV.itemsList["Weekly"], name);
	if (isPresent) then
		table.remove(ToDoListSV.itemsList["Weekly"], pos);
	end
	config:Print("\""..name.."\" removed!");
	modif = true;

	itemsFrame:RefreshTab(case, name, "Remove", modif);
end

local function addCategory()
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
	if (l:GetWidth()>220) then
		config:Print("This categoty name is too big!")
		return;
	end

	db.name = itemsFrameUI.nameEditBox:GetText();
	if (db.name == "") then
		config:Print("Please enter the name of the item!")
		return;
	end

	local l = config:CreateNoPointsLabel(itemsFrameUI, nil, db.name);
	if (l:GetWidth()>230) then
		config:Print("This item name is too big!")
		return;
	end

	db.case = itemsFrameUI.labelAddACategory:GetParent():GetName();

	itemsFrameUI.categoryEditBox:SetText("");
	itemsFrameUI.nameEditBox:SetText("");
	addItem(nil, db);
end

-- Frame update: --
ItemsFrame_Update = function(...)
	UpdateAllTable();
	UpdateRemainingNumber();
	UpdateCheckButtons();
	SaveSavedVariable();
end

ItemsFrame_UpdateTime = function()
	autoReset();
end

local function ItemsFrame_OnMouseUp() -- we click on a label
	if (labelNewCatHover) then -- if it's the add a new category label
		ToDoListSV.newCatClosed = not ToDoListSV.newCatClosed;
	elseif (next(labelHover)) then -- if we are mouse hovering one of the category labels
		local isPresent, pos = config:HasItem(ToDoListSV.closedCategories,unpack(labelHover));
		if (isPresent) then
			table.remove(ToDoListSV.closedCategories,pos); -- if it was closed, we open it
		else
			table.insert(ToDoListSV.closedCategories,tostringall(unpack(labelHover))); -- vice versa
		end
	end
	Tab_OnClick(_G[ToDoListSV.lastLoadedTab]); -- we reload the frame to display the changes
end

local function ItemsFrame_OnUpdate(self, elapsed) -- Updating the itemsFrame every 1 second
	self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed;

	-- update for the labels: (every frame)
	for k,i in pairs(ToDoListSV.itemsList) do
		if (k ~= "Daily" and k ~= "Weekly") then
			if (label[k]:IsMouseOver()) then -- for every label in the current tab, if our mouse is over one of them,
				label[k]:SetTextColor(0,0.8,1,1); -- we change its visual
				local isPresent, pos = config:HasItem(labelHover,k);
				if (not isPresent) then
					table.insert(labelHover,k); -- we add its category name in a table variable
				end
			else
				local isPresent, pos = config:HasItem(labelHover,k);
				if (isPresent) then
					table.remove(labelHover,pos); -- if we're not hovering it, we delete it from that table
				end
				label[k]:SetTextColor(1,1,1,1); -- back to the default color
			end
		end
	end

	if (itemsFrameUI.labelAddACategory:IsMouseOver()) then -- for every label in the current tab, if our mouse is over one of them,
		itemsFrameUI.labelAddACategory:SetTextColor(0,0.8,1,1); -- we change its visual
		if (not labelNewCatHover) then
			labelNewCatHover = true;
		end
	else
		itemsFrameUI.labelAddACategory:SetTextColor(1,1,1,1); -- back to the default color
		if (labelNewCatHover) then
			labelNewCatHover = false;
		end
	end

	while (self.timeSinceLastUpdate > refreshRate) do -- every one second
		ItemsFrame_UpdateTime();
		self.timeSinceLastUpdate = self.timeSinceLastUpdate - refreshRate;
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
	for i=1,#All,1 do
		checkBtn[All[i]] = CreateFrame("CheckButton", All[i], itemsFrameUI, "UICheckButtonTemplate");
		checkBtn[All[i]].text:SetText(All[i]);
		checkBtn[All[i]].text:SetFontObject("GameFontNormalLarge");
		checkBtn[All[i]]:SetScript("OnClick", ItemsFrame_Update);

		removeBtn[All[i]] = config:CreateRemoveButton(checkBtn[All[i]]);
		removeBtn[All[i]]:SetScript("OnClick", removeItem);
	end

	-- Category labels
	for k,i in pairs(ToDoListSV.itemsList) do
		if (k ~= "Daily" and k ~= "Weekly") then
			label[k] = config:CreateNoPointsLabel(itemsFrameUI,k,tostring(k.." :"));
			editBox[k] = config:CreateNoPointsLabelEditBox(k);
			editBox[k]:SetScript("OnEnterPressed", function(self) addItem(addBtn[self:GetName()]) end); -- if we press enter, it's like we clicked on the add button
			addBtn[k] = config:CreateAddButton(editBox[k]);
			addBtn[k]:SetScript("OnClick", addItem);
		end
	end
end

local function loadCategories(tab,category,categoryLabel,constraint,catName,lastData)
	if (lastData == nil) then -- doing that only one time
		lastData = nil;
		for i=1,#All do
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
		for i=1,#category do
			if (select(1,config:HasItem(constraint,category[i]))) then
				table.insert(cat,category[i]);
			end
		end
		category = cat;
	end

	if (config:HasAtLeastOneItem(All,category)) then -- litterally
		-- category label
		if (lastData == nil) then
			lastLabel = itemsFrameUI.dummyLabel;
			l = 0;
		else
			lastLabel = lastData["categoryLabel"];
			if ((select(1,config:HasItem(ToDoListSV.closedCategories, lastData["catName"])))) then
				l = 1;
			else
				l = #lastData["category"] + 1;
			end
		end

		if (l == 0) then m = 0; else m = 1; end -- just for a proper clean height
		categoryLabel:SetParent(tab);
		categoryLabel:SetPoint("TOPLEFT", lastLabel, "TOPLEFT", 0, (-l*22)-(m*5)); -- here
		categoryLabel:Show();

		if (not (select(1,config:HasItem(ToDoListSV.closedCategories, catName)))) then -- if the category is opened, we display all of its items
			-- edit box
			editBox[categoryLabel:GetName()]:SetParent(tab);
			editBox[categoryLabel:GetName()]:SetPoint("LEFT", categoryLabel, "RIGHT", 10, 0);

			local x = (categoryLabel:GetWidth());
			if (x+120>270) then
				editBox[categoryLabel:GetName()]:SetWidth(270-x);
			else
				editBox[categoryLabel:GetName()]:SetPoint("LEFT", categoryLabel, "LEFT", 160, 0);
			end

			editBox[categoryLabel:GetName()]:Show();

			-- checkboxes
			local buttonsLength = 0;
			for i=1,#All do
				if ((select(1,config:HasItem(category,checkBtn[All[i]]:GetName())))) then
					buttonsLength = buttonsLength + 1;

					checkBtn[All[i]]:SetParent(tab);
					checkBtn[All[i]]:SetPoint("TOPLEFT", categoryLabel, "TOPLEFT", 30, -22*buttonsLength+5);

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
			for i=1,#All do
				if ((select(1,config:HasItem(category,checkBtn[All[i]]:GetName())))) then
					buttonsLength = buttonsLength + 1;

					checkBtn[All[i]]:SetParent(tab);
					checkBtn[All[i]]:SetPoint("TOPLEFT", categoryLabel, "TOPLEFT", 30, -22*buttonsLength+5);
				end
			end
		end

	else
		if (not next(ToDoListSV.itemsList[catName])) then -- if there is no more item in a category, we delete the corresponding elements
			ToDoListSV.itemsList[catName] = nil;
			addBtn[categoryLabel:GetName()] = nil;
			editBox[categoryLabel:GetName()] = nil;
			label[categoryLabel:GetName()] = nil;
			isPresent, pos = config:HasItem(ToDoListSV.closedCategories,catName); -- we verify if it was a closed category (can happen with the /tdl clear command)
			if (isPresent) then
				table.remove(ToDoListSV.closedCategories,pos);
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

local function loadAddACategory(tab)
	itemsFrameUI.labelAddACategory:SetParent(tab);
	itemsFrameUI.labelAddACategory:SetPoint("TOPLEFT", itemsFrameUI.lineTop, "TOPLEFT", 30, -35);

	itemsFrameUI.labelCategoryName:SetParent(tab);
	itemsFrameUI.labelCategoryName:SetPoint("TOPLEFT", itemsFrameUI.labelAddACategory, "TOPLEFT", -55, -30);
	itemsFrameUI.categoryEditBox:SetParent(tab);
	itemsFrameUI.categoryEditBox:SetPoint("RIGHT", itemsFrameUI.labelCategoryName, "RIGHT", 150, 0);

	itemsFrameUI.labelFirstItemName:SetParent(tab);
	itemsFrameUI.labelFirstItemName:SetPoint("TOPLEFT", itemsFrameUI.labelAddACategory, "TOPLEFT", -55, -55);
	itemsFrameUI.nameEditBox:SetParent(tab);
	itemsFrameUI.nameEditBox:SetPoint("RIGHT", itemsFrameUI.labelFirstItemName, "RIGHT", 150, 0);

	itemsFrameUI.lineBottom:SetParent(tab);
	if (ToDoListSV.newCatClosed) then -- if the creation of new categories is closed
		-- we hide and adapt the height of every component
		itemsFrameUI.labelCategoryName:Hide();
		itemsFrameUI.categoryEditBox:Hide();
		itemsFrameUI.labelFirstItemName:Hide();
		itemsFrameUI.nameEditBox:Hide();

		itemsFrameUI.lineBottom:SetPoint("TOPLEFT",itemsFrameUI.labelAddACategory,"TOPLEFT",-30,-25);
	else
		-- or else we show and adapt the height of every component again
		itemsFrameUI.labelCategoryName:Show();
		itemsFrameUI.categoryEditBox:Show();
		itemsFrameUI.labelFirstItemName:Show();
		itemsFrameUI.nameEditBox:Show();

		itemsFrameUI.lineBottom:SetPoint("TOPLEFT",itemsFrameUI.labelAddACategory,"TOPLEFT",-30,-80);
	end
end

-------------------------------------------------------------------------------------------
-- Contenting:<3 --------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

-- generating the content
local function generateTab(tab,case)
	-- We sort all of the categories in alphabetical order
	local tempTable = {}
	for t in pairs(ToDoListSV.itemsList) do table.insert(tempTable, t) end
	table.sort(tempTable);

	-- we load everything
	local lastData = nil;
	for _,n in pairs(tempTable) do
		if (n ~= "Daily" and n ~= "Weekly") then
			lastData = loadCategories(tab,ToDoListSV.itemsList[n],label[n], case, n, lastData);
		end
	end
end

-- loading the content (top to bottom)
local function loadTab(tab,case)
	itemsFrameUI.remaining:SetParent(tab);
	itemsFrameUI.remaining:SetPoint("TOPLEFT", tab, "TOPLEFT", 100, -20);
	itemsFrameUI.lineTop:SetParent(tab);
	itemsFrameUI.lineTop:SetPoint("TOPLEFT", tab, "TOPLEFT", 40, -40);

	-- loading the "add a new category" menu
	loadAddACategory(tab);

	-- Nothing label:
	itemsFrameUI.nothingLabel:SetParent(tab);
	if (next(case) ~= nil) then -- if there is something to show in the tab we're in
		itemsFrameUI.nothingLabel:Hide();
	else
		itemsFrameUI.nothingLabel:SetPoint("CENTER", itemsFrameUI.lineBottom, "CENTER", 0, -33); -- to correctly center this text on diffent screen sizes
		itemsFrameUI.nothingLabel:Show();
	end

	itemsFrameUI.dummyLabel:SetParent(tab);
	itemsFrameUI.dummyLabel:SetPoint("TOPLEFT", itemsFrameUI.lineBottom, "TOPLEFT", -35, -35);

	-- generating all of the content (items, checkboxes, editboxes, category labels...)
	generateTab(tab,case);
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
	if (self:GetName() == "ToDoListUIFrameTab1") then loadTab(AllTab,All) end
	if (self:GetName() == "ToDoListUIFrameTab2") then loadTab(DailyTab,ToDoListSV.itemsList["Daily"]) end
	if (self:GetName() == "ToDoListUIFrameTab3") then loadTab(WeeklyTab,ToDoListSV.itemsList["Weekly"]) end

	-- we update the frame after loading the tab to refresh the display
	ItemsFrame_Update();

	ToDoListSV.lastLoadedTab = self:GetName();

	self.content:Show();
end

-- if the last tab we were on is getting an update
-- because of an add or remove of an item, we re-update it
function itemsFrame:RefreshTab(cat, name, action, modif)
	if (modif) then
		-- Removing case
		if (action == "Remove") then
			if (cat == nil) then
				local isPresent, pos = config:HasItem(ToDoListSV.checkedButtons, checkBtn[name]:GetName());
				if (checkBtn[name]:GetChecked() and isPresent) then
		      table.remove(ToDoListSV.checkedButtons, pos);
				end

				checkBtn[name]:Hide();	-- get out of my view mate
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
				checkBtn[name]:SetScript("OnClick", ItemsFrame_Update);

				removeBtn[name] = config:CreateRemoveButton(checkBtn[name]);
				removeBtn[name]:SetScript("OnClick", removeItem);
			end
			-- we create the corresponding label (if it is a new one)
			if (label[cat] == nil) then
				label[cat] = config:CreateNoPointsLabel(itemsFrameUI,cat,tostring(cat.." :"));
				editBox[cat] = config:CreateNoPointsLabelEditBox(cat);
				editBox[cat]:SetScript("OnEnterPressed", function(self) addItem(addBtn[self:GetName()]) end); -- if we press enter, it's blike we clicked on the add button
				addBtn[cat] = config:CreateAddButton(editBox[cat]);
				addBtn[cat]:SetScript("OnClick", addItem);
			end

			Tab_OnClick(_G[ToDoListSV.lastLoadedTab]); -- we reload the tab to instantly display the changes
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

	itemsFrameUI = CreateFrame("Frame", "ToDoListUIFrame", UIParent, "UIPanelDialogTemplate");
	itemsFrameUI:SetSize(350, 400);
	itemsFrameUI:SetPoint("CENTER");

	itemsFrameUI.Title:ClearAllPoints();
	itemsFrameUI.Title:SetFontObject("GameFontHighlight");
	itemsFrameUI.Title:SetPoint("LEFT", ToDoListUIFrameTitleBG, "LEFT", (itemsFrameUI:GetWidth()/2)-50, 1);
	itemsFrameUI.Title:SetText("To do list");

	itemsFrameUI.remaining = config:CreateNoPointsLabel(itemsFrameUI,nil,"Remaining:");
	itemsFrameUI.lineTop = config:CreateNoPointsLabel(itemsFrameUI,nil,"|cff00ccff___________________________|r");

	itemsFrameUI.labelAddACategory = itemsFrameUI:CreateFontString(nil); -- info label 1
	itemsFrameUI.labelAddACategory:SetFontObject("GameFontHighlightLarge");
	itemsFrameUI.labelAddACategory:SetText("Add a new category");

	itemsFrameUI.labelCategoryName = itemsFrameUI:CreateFontString(nil); -- info label 2
	itemsFrameUI.labelCategoryName:SetFontObject("GameFontHighlightLarge");
	itemsFrameUI.labelCategoryName:SetText("Category name:");

	itemsFrameUI.categoryEditBox = CreateFrame("EditBox", nil, itemsFrameUI, "InputBoxTemplate"); -- edit box to put the new category name
	itemsFrameUI.categoryEditBox:SetSize(130, 30);
	itemsFrameUI.categoryEditBox:SetAutoFocus(false);
	itemsFrameUI.categoryEditBox:SetScript("OnKeyDown", function(self, key) if (key == "TAB") then itemsFrameUI.nameEditBox:SetFocus() end end) -- to switch easily between the two edit boxes
	itemsFrameUI.categoryEditBox:SetScript("OnEnterPressed", addCategory); -- if we press enter, it's like we clicked on the add button

	itemsFrameUI.labelFirstItemName = itemsFrameUI:CreateFontString(nil); -- info label 3
	itemsFrameUI.labelFirstItemName:SetFontObject("GameFontHighlightLarge");
	itemsFrameUI.labelFirstItemName:SetText("1st item name:");

	itemsFrameUI.nameEditBox = CreateFrame("EditBox", nil, itemsFrameUI, "InputBoxTemplate"); -- edit box tp put the name of the first item
	itemsFrameUI.nameEditBox:SetSize(130, 30);
	itemsFrameUI.nameEditBox:SetAutoFocus(false);
	itemsFrameUI.nameEditBox:SetScript("OnKeyDown", function(self, key) if (key == "TAB") then itemsFrameUI.categoryEditBox:SetFocus() end end)
	itemsFrameUI.nameEditBox:SetScript("OnEnterPressed", addCategory); -- if we press enter, it's like we clicked on the add button

	itemsFrameUI.addBtn = config:CreateAddButton(itemsFrameUI.nameEditBox);
	itemsFrameUI.addBtn:SetScript("onClick", addCategory)

	itemsFrameUI.lineBottom = config:CreateLabel("TOPLEFT",itemsFrameUI,"TOPLEFT",0,0,"|cff00ccff___________________________|r");

	itemsFrameUI.nothingLabel = config:CreateNothingLabel(itemsFrameUI);

	itemsFrameUI.dummyLabel = config:CreateDummy(itemsFrameUI.lineBottom,0,0);

	itemsFrameUI.timeSinceLastUpdate = 0;

	itemsFrameUI.ScrollFrame = CreateFrame("ScrollFrame", nil, itemsFrameUI, "UIPanelScrollFrameTemplate");
	itemsFrameUI.ScrollFrame:SetPoint("TOPLEFT", ToDoListUIFrameDialogBG, "TOPLEFT", 4, -8);
	itemsFrameUI.ScrollFrame:SetPoint("BOTTOMRIGHT", ToDoListUIFrameDialogBG, "BOTTOMRIGHT", -3, 4);
	itemsFrameUI.ScrollFrame:SetClipsChildren(true);

	itemsFrameUI.ScrollFrame:SetScript("OnMouseWheel", ScrollFrame_OnMouseWheel);

	itemsFrameUI.ScrollFrame.ScrollBar:ClearAllPoints();
  itemsFrameUI.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", itemsFrameUI.ScrollFrame, "TOPRIGHT", -12, -18);
  itemsFrameUI.ScrollFrame.ScrollBar:SetPoint("BOTTOMRIGHT", itemsFrameUI.ScrollFrame, "BOTTOMRIGHT", -7, 18);

	itemsFrameUI:SetScript("OnUpdate", ItemsFrame_OnUpdate);
	itemsFrameUI:SetScript("OnMouseUp", ItemsFrame_OnMouseUp);

	itemsFrameUI:SetMovable(true);
	itemsFrameUI:SetClampedToScreen(true);
	itemsFrameUI:EnableMouse(true);

	itemsFrameUI:RegisterForDrag("LeftButton");	-- to move the frame
	itemsFrameUI:SetScript("OnDragStart", itemsFrameUI.StartMoving);
	itemsFrameUI:SetScript("OnDragStop", itemsFrameUI.StopMovingOrSizing);

	-- Generating the tabs:--
	AllTab, DailyTab, WeeklyTab = SetTabs(itemsFrameUI, 3, "All", "Daily", "Weekly");

	-- Generating the core --
	UpdateAllTable();
	loadMovable();
	loadSavedVariable();

	-- Updating everything once and hiding the UI
	ItemsFrame_UpdateTime(); -- for the auto reset check (we could wait 1 sec, but nah we don't have the time man)

	-- We load the good tab
	Tab_OnClick(_G[ToDoListSV.lastLoadedTab]);

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

function itemsFrame:ClearAll()
	if (next(checkBtn) ~= nil) then
		config:Print("Starting clear...");

		local last = ToDoListSV.lastLoadedTab;
		-- we put ourselves in the All tab to load every elements
		Tab_OnClick(_G["ToDoListUIFrameTab1"]);

		for k,v in pairs(removeBtn) do
			removeItem(v);
		end

		-- we refresh and go back to the tab we were on
		Tab_OnClick(_G[last]);

		config:Print("Clear succesful!");
	else
		config:Print("Nothing to clear!");
	end
end

-- Tests function (for me :p)
function Nys_Tests(yes)
	if (yes==1) then
		ToDoListSV.itemsList = {}
		ToDoListSV.itemsList = {
			["Legion"] = {
				"Legion wq", -- [1]
				"Class hall missions", -- [2]
			},
			["BFA"] = {
				"BFA wq", -- [1]
				"Warfronts (medals)", -- [2]
				"BFA missions", -- [3]
			},
			["Others"] = {
				"Molten front assault daily", -- [1]
				"Timeless isle", -- [2]
				"Fishing contest", -- [3]
				"Hexweave Cloth (Nyøny)", -- [4]
				"Korda Torros (Rare)", -- [5]
				"Argent tournament dailies", -- [6]
			},
			["Raids transmog"] = {
				"Blackrock foundry (heroic)", -- [1]
				"Terrace (lfr+normal)", -- [2]
				"Throne of thunder (heroic+lfr)", -- [3]
				"Siege of Orgrimmar (myth)", -- [4]
				"Throne of thunder (heroic)", -- [5]
			},
			["Draenor"] = {
				"Garrison missions", -- [1]
				"Reactivate follower", -- [2]
				"Harrison Jones", -- [3]
				"Recruit garrison follower", -- [4]
				"Garrison invasion", -- [5]
			},
			["Mount farm"] = {
				"Rukhmar", -- [1]
				"Archimonde (myth)", -- [2]
				"Black hand (myth)", -- [3]
				"Sha of fear", -- [4]
				"Mogu'shan Vaults", -- [5]
				"Garrosh Hellscream", -- [6]
				"Ragnaros + Alysrazor", -- [7]
			},
			["Weekly"] = {
				"Recruit garrison follower", -- [1]
				"Garrison invasion", -- [2]
				"Timeless isle", -- [3]
				"Fishing contest", -- [4]
				"Rukhmar", -- [5]
				"Archimonde (myth)", -- [6]
				"Black hand (myth)", -- [7]
				"Sha of fear", -- [8]
				"Mogu'shan Vaults", -- [9]
				"Garrosh Hellscream", -- [10]
				"Ragnaros + Alysrazor", -- [11]
				"Blackrock foundry (heroic)", -- [12]
				"Terrace (lfr+normal)", -- [13]
				"Siege of Orgrimmar (myth)", -- [14]
				"Hexweave Cloth (Nyøny)", -- [15]
				"Throne of thunder (heroic)", -- [16]
			},
			["Daily"] = {
				"Garrison missions", -- [1]
				"Reactivate follower", -- [2]
				"Harrison Jones", -- [3]
				"Legion wq", -- [4]
				"Class hall missions", -- [5]
				"BFA wq", -- [6]
				"Warfronts (medals)", -- [7]
				"BFA missions", -- [8]
				"Molten front assault daily", -- [9]
				"Korda Torros (Rare)", -- [10]
				"Argent tournament dailies", -- [11]
			},
		}
	elseif (yes==2) then
		ToDoListSV = nil;
	elseif (yes==3) then
		ToDoListSV.lastLoadedTab = "ToDoListUIFrameTab1";
	end
	print(1)
end
