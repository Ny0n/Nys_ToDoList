--/*******************/ IMPORTS /*************************/--

-- File init

local dataManager = NysTDL.dataManager
NysTDL.dataManager = dataManager

-- Primary aliases

local libs = NysTDL.libs
local core = NysTDL.core
local chat = NysTDL.chat
local enums = NysTDL.enums
local utils = NysTDL.utils
local widgets = NysTDL.widgets
local database = NysTDL.database
local resetManager = NysTDL.resetManager

-- Secondary aliases

local L = libs.L
local AceConfigRegistry = libs.AceConfigRegistry
local addonName = core.addonName

--/*******************************************************/--

-- the access to mainFrame is controlled:
-- this file can only call mainFrame funcs if it is specifically authorized to do so,
-- it's to counter the fact that for some database updates
-- (var migration, profile change, default tabs creation...)
-- I have to call funcs here before the list is created

dataManager.authorized = true
local refreshAuthorized = true

local dummyFunc = function()end

local _mainFrame = NysTDL.mainFrame
local mainFrame = setmetatable({}, {
	__index = function(t,k)
		if not dataManager.authorized then return dummyFunc end
		if not refreshAuthorized and k == "Refresh" then return dummyFunc end
		return _mainFrame[k] -- access the original table
	end,
})

local _tabsFrame = NysTDL.tabsFrame
local tabsFrame = setmetatable({}, {
	__index = function(t,k)
		if not dataManager.authorized then return dummyFunc end
		return _tabsFrame[k] -- access the original table
	end,
})

-- Variables

local private = {}

local undoing = false
local clearing = false

-- // WoW & Lua APIs

local wipe, select = wipe, select
local type, pairs, ipairs = type, pairs, ipairs
local tinsert, tremove = table.insert, table.remove

--/*******************/ DATA MANAGMENT /*************************/--

local keyID_SetRefresh
function dataManager:SetRefresh(state, refreshID)
	-- this is pure optimization, this func allows me to englobe any code I want with these two lines:
	-- local refreshID = dataManager:SetRefresh(false)
	-- code...
	-- dataManager:SetRefresh(true, refreshID)
	-- making the code unable to call mainFrame:Refresh()
	-- also works with recursive calls

	if refreshAuthorized == state then return end
	if not state then -- disable calls
		refreshAuthorized = false
		keyID_SetRefresh = dataManager:NewID()
		return keyID_SetRefresh
	else -- enable calls
		if refreshID == keyID_SetRefresh then
			refreshAuthorized = true
		end
	end
end

local keyID_SetUndoing
function dataManager:SetUndoing(state, undoingID)
	-- this func, very similar to SetRefresh,
	-- allows me to merge multiple clear undos as one print in the end
	-- (this may be overkill, but I know that this works,
	-- and I don't want to find an other way since the Undo func is a recursive nightmare)

	if undoing == state then return end
	if state then -- undoing start
		undoing = true
		keyID_SetUndoing = dataManager:NewID()
		return keyID_SetUndoing
	else -- stop undoing
		if undoingID == keyID_SetUndoing then
			undoing = false
		end
	end
end

---This function returns the global saved variable `NysTDL.acedb.global.nextID` as it is,
---then increments it by one, using the hexadecimal base.
---@return string newID
function dataManager:NewID()
	--[[
		! the benefit of this func over using an integer with string.format("%x", ...) is that no numbers are used !
		-- I'm incrementing NysTDL.acedb.global.nextID hexadecimally using only strings --
		-> this means that I am not bound to the limits of lua numbers,
			but to the limit of lua strings, which in hex terms, is infinitely bigger.
	]]

	-- hexadecimal
	local base = "0123456789abcdef"
	local newChar = "1"

	-- // script start

	local g = NysTDL.acedb.global

	-- safeguard
	local sg = function()
		local success, result = pcall(time) -- Overkill, I know, but better safe than sorry ;)
		if success then
			g.nextID = string.format("%x", result)
		else
			g.nextID = "001"
		end
	end

	if type(g.nextID) ~= "string" or #g.nextID == 0 then sg() end -- safeguard #1
	g.nextID = g.nextID:lower()

	local newID = g.nextID -- first we save the ID that will be returned by this call (nextID)

	-- and then, we increment nextID by one

	---------------------

	local index = #g.nextID

	repeat
		local char = g.nextID:sub(index, index)
		if #char == 0 then
			g.nextID = newChar .. g.nextID
			break
		end

		local baseIndex = base:find(char)
		if not baseIndex then -- safeguard #2
			sg()
			return dataManager:NewID()
		end

		baseIndex = baseIndex + 1
		if baseIndex > #base then -- was last char
			baseIndex = 1
		end

		g.nextID = g.nextID:sub(1, index-1) .. base:sub(baseIndex, baseIndex) .. g.nextID:sub(index+1, #g.nextID)
		index = index - 1
	until baseIndex ~= 1

	---------------------

	return newID
end

---Returns true if the given ID is valid and exists in the database, false otherwise.
---@param ID any
---@return boolean
function dataManager:IsID(ID)
	if type(ID) ~= enums.idtype then return false end
	-- if not string.match(ID, '^[0-9a-f]+-[0-9a-f]+-[0-5][0-9a-f]+-[089ab][0-9a-f]+-[0-9a-f]+$') then return end
	if not pcall(dataManager.Find, dataManager, ID) then return false end -- raises an error if the ID is not found

	return true
end

-- misc functions

---Finds and returns all necessary data concerning a given ID,
---and throws an error if it wasn't found in the database.
---@param ID string
---@return enumObject enum
---@return boolean isGlobal
---@return table objectData
---@return table itemsList
---@return table categoriesList
---@return table tabsList
function dataManager:Find(ID)
	for i=1,2 do -- global, profile
		local isGlobal = i==2
		local locations = dataManager:GetData(isGlobal, true)
		for enum, tbl in pairs(locations) do -- itemsList, categoriesList, tabsList
			if tbl[ID] ~= nil then -- presence test
				return enum, isGlobal, tbl[ID], dataManager:GetData(isGlobal)
			end
		end
	end

	error("ID not found") -- KEEP
end

---Returns true if the ID is a global object, false if it's a profile one.
---@param ID string
---@return boolean isGlobal
function dataManager:IsGlobal(ID)
	return (select(2, dataManager:Find(ID)))
end

local T_GetData = {}
---Returns all of the object tables, either the global or the profile ones (`isGlobal`).
---@param isGlobal boolean
---@param tableMode boolean Do not use
---@return table itemsList
---@return table categoriesList
---@return table tabsList
function dataManager:GetData(isGlobal, tableMode)
	-- returns itemsList, categoriesList, and tabsList located either in the global or profile SV
	-- as a table if asked so

	local loc = isGlobal and NysTDL.acedb.global or NysTDL.acedb.profile
	if tableMode then
		wipe(T_GetData)
		T_GetData[enums.item] = loc.itemsList
		T_GetData[enums.category] = loc.categoriesList
		T_GetData[enums.tab] = loc.tabsList
		return T_GetData
	else
		return loc.itemsList, loc.categoriesList, loc.tabsList
	end
end

---@param ID string
---@return string name
function dataManager:GetName(ID)
	return select(3, dataManager:Find(ID)).name or ""
end

---Returns the position data (location & number) of a given ID. `loc` is the table the object is located in.
---
---If the ID is a CATEGORY, then we can specify in which tab we want to know where it is,
---or the current tab if none is given (since it can be either a sub-cat with a parent order, or a normal cat with a tab order).
---
---@param ID string
---@param tabID string
---@param onlyPos boolean Do not return the location
---@return table loc
---@return number pos
function dataManager:GetPosData(ID, tabID, onlyPos)
	tabID = tabID or database.ctab()

	local enum, _, data, _, categoriesList, tabsList = dataManager:Find(ID)

	local loc
	if enum == enums.item then -- item
		loc = select(3, dataManager:Find(data.catID)).orderedContentIDs
	elseif enum == enums.category then -- category
		dataManager:Find(tabID) -- tab check
		loc = data.parentCatID and categoriesList[data.parentCatID].orderedContentIDs or tabsList[tabID].orderedCatIDs
	elseif enum == enums.tab then -- tab
		loc = tabsList.orderedTabIDs
	end

	local pos = select(2, utils:HasValue(loc, ID))
	if onlyPos then
		return pos
	else
		return loc, pos
	end
end

---Returns the quantity of the given enum.
---@param enum enumObject
---@param isGlobal boolean Unused
---@return number
function dataManager:GetQuantity(enum, isGlobal)
	if enum ~= enums.item and enum ~= enums.category and enum ~= enums.tab then return 0 end

	-- OPTIMIZED VERSION
	return enums.quantities[enum]

	-- LOOP VERSION (always true, doesn't require outside variables)
	-- returns the quantity of the given enum, in the given global state
	-- isGlobal can be:
	-- --> nil == global + profile
	-- --> false == profile
	-- --> true == global

	-- if isGlobal ~= nil and type(isGlobal) ~= "boolean" then isGlobal = true end

	-- local quantity = 0
	-- for _ in dataManager:ForEach(enum, isGlobal) do
	-- 	quantity = quantity + 1
	-- end
	-- return quantity
end

---Updates the total number of each object in the database.
function dataManager:UpdateQuantities()
	local enumTypes = { enums.item, enums.category, enums.tab }
	for _,enum in pairs(enumTypes) do
		enums.quantities[enum] = 0
		for _ in dataManager:ForEach(enum) do
			enums.quantities[enum] = enums.quantities[enum] + 1
		end
	end
end

---Iterator function. Use in for loops in the same way as `ipairs()` or `pairs()`.
---
---See func details to understand how the params are used.
---
---@param enum enumObject
---@param location nil|false|true|number
---@return function
function dataManager:ForEach(enum, location)
	--[[
		* this func is used everywhere to loop through items, categories and tabs.
		this is used in a for loop like pairs():

		for itemID,itemData in dataManager:ForEach(enums.item) do
			-- body...
		end

		* every time, the loop variables are the ID and the DATA of the targeted loop object

		* usage:
			enum 		==> either enums.item, enums.category, or enums.tab (depending on what you want to loop on)
			location 	==> can be multiple things:
				-> **nil/false/true** (will loop in either profile+global/profile/global saved variables)
				-> if the enum is enums.item:
						--> **ID** (specific tab or cat ID, we will only loop through items that are in the given cat, or that are in the given tab)
				-> if the enum is enums.category:
						--> **ID** (specific tab ID, we will only loop through categories that are in the given tab)
				-> if the enum is enums.tab:
						--> **ID** (specific shown tab ID, we will only loop through tabs that are showing the given tab)
	]]

	-- // check part
	local isGlobal, getdatapos, checkFunc = location
	if enum == enums.item then
		getdatapos = 1
		if dataManager:IsID(location) then -- specific tab or cat ID
			enum, isGlobal = dataManager:Find(location)
			if enum == enums.category then
				checkFunc = function(ID, data)
					if data.catID ~= location then return false end
					return true
				end
			elseif enum == enums.tab then
				checkFunc = function(ID, data)
					if not data.tabIDs[location] then return false end
					return true
				end
			else
				error("Wrong location in ForEach call", 2) -- KEEP
			end
		end
	elseif enum == enums.category then
		getdatapos = 2
		if dataManager:IsID(location) then -- specific tab ID
			enum, isGlobal = dataManager:Find(location)
			if enum == enums.tab then
				checkFunc = function(ID, data)
					if not data.tabIDs[location] then return false end
					return true
				end
			else
				error("Wrong location in ForEach call", 2) -- KEEP
			end
		end
	elseif enum == enums.tab then
		getdatapos = 3
		if dataManager:IsID(location) then -- specific shown ID
			enum, isGlobal = dataManager:Find(location)
			if enum == enums.tab then
				checkFunc = function(ID, data)
					if ID == "orderedTabIDs" then return false end -- every time
					if not data.shownIDs[location] then return false end
					return true
				end
			else
				error("Wrong location in ForEach call", 2) -- KEEP
			end
		else -- in any case, there is something to check for any tab iteration
			checkFunc = function(ID, data)
				if ID == "orderedTabIDs" then return false end -- every time
				return true
			end
		end
	else
		error("Wrong enum in ForEach call", 2) -- KEEP
	end

	-- // iteration part
	local table, key, data = (select(getdatapos, dataManager:GetData(isGlobal)))
	return function()
		repeat
			local redo = false

			-- first we get the next value
			key, data = next(table, key)

			if key and checkFunc and not checkFunc(key, data) then redo = true end

			-- then we check what to return
			if not redo and key == nil and isGlobal == nil then
				-- if we finished one table and isGlobal was nil, then we start the other table
				isGlobal = not isGlobal
				table = (select(getdatapos, dataManager:GetData(isGlobal)))
				key = nil
				redo = true
			end
		until not redo

		return key, data, isGlobal
	end
end

-- // object adding functions

-- item

---Adds the given item to the database.
---@param itemID string
---@param itemData table
---@return string|nil itemID
---@return table itemData
function private:AddItem(itemID, itemData)
	if dataManager:GetQuantity(enums.item) >= enums.maxQuantities[enums.item] then -- temp limit
		chat:Print(utils:SafeStringFormat(L["Cannot add %s"].." ("..L["Max quantity reached"]..")", L["Item"]:lower()))
		return
	end

	wipe(itemData.tabIDs)
	itemData.tabIDs[itemData.originalTabID] = true -- by default, an item/cat can only be added to one tab, the shownTabIDs do the rest after

	-- we get where we are
	local itemsList, categoriesList = select(4, dataManager:Find(itemData.originalTabID))

	-- we add the item to the saved variables

	itemsList[itemID] = itemData -- adding action

	-- then we update its data
	private:UpdateTabsDisplay(itemData.originalTabID, true, itemID)
	-- we add it ordered in its category
	local itemOrder = dataManager:GetNextFavPos(itemData.catID)
	tinsert(categoriesList[itemData.catID].orderedContentIDs, itemOrder, itemID)

	-- refresh the mainFrame
	mainFrame:UpdateWidget(itemID, enums.item)
	mainFrame:Refresh()

	enums.quantities[enums.item] = enums.quantities[enums.item] + 1

	return itemID, itemData
end

---Creates and adds a new item to the database.
---@param itemName string
---@param tabID string
---@param catID string
---@return string|nil itemID
---@return table itemData
function dataManager:CreateItem(itemName, tabID, catID)
	-- creates the formatted item table with the given arguments,
	-- this table will then be sent to AddItem who will properly
	-- add the item and its dependencies to the saved variables

	-- first, we check what needs to be checked
	if not private:CheckName(itemName, enums.item) then return end

	local itemData = { -- itemData
		name = itemName,
		originalTabID = tabID,
		tabIDs = { -- we display the item in these tabs, updated later
			-- [tabID] = true,
			-- ...
		},
		catID = catID, -- for convenience when deleting items, so that we can remove them from its respective category easily
		-- item specific data
		-- accountWide = false, -- user set, used in global tabs
		-- accountChecked = { -- user set, used in global tabs
		--   -- [profileName] = false or true, -- first one is self, and is the only one for profile items
		--   -- [profileName] = false or true, -- others are used only for global items
		--   -- ...
		-- },
		checked = false,
		favorite = false,
		description = false,
	}

	return private:AddItem(dataManager:NewID(), itemData)
end

-- category

---Adds the given category to the database.
---@param catID string
---@param catData table
---@return string|nil catID
---@return table catData
function private:AddCategory(catID, catData)
	if dataManager:GetQuantity(enums.category) >= enums.maxQuantities[enums.category] then -- temp limit
		chat:Print(utils:SafeStringFormat(L["Cannot add %s"].." ("..L["Max quantity reached"]..")", L["Category"]:lower()))
		return
	end

	wipe(catData.tabIDs)
	catData.tabIDs[catData.originalTabID] = true -- by default, an item/cat can only be added to one tab, the shownTabIDs do the rest after

	-- we get where we are
	local categoriesList = select(5, dataManager:Find(catData.originalTabID))

	-- we add the category to the saved variables

	categoriesList[catID] = catData -- adding action

	-- then we update its data
	private:UpdateTabsDisplay(catData.originalTabID, true, catID)
	if catData.parentCatID then
		-- we add it ordered in its category/categories
		local catOrder = dataManager:GetNextFavPos(catData.parentCatID)
		tinsert(categoriesList[catData.parentCatID].orderedContentIDs, catOrder, catID)
	end

	-- refresh the mainFrame
	mainFrame:UpdateWidget(catID, enums.category)
	mainFrame:Refresh()

	enums.quantities[enums.category] = enums.quantities[enums.category] + 1

	return catID, catData
end

---Creates and adds a new category to the database.
---@param catName string
---@param tabID string
---@param parentCatID string|nil
---@return string|nil catID
---@return table catData
function dataManager:CreateCategory(catName, tabID, parentCatID)
	-- creates the formatted category table with the given arguments,
	-- this table will then be sent to AddCategory who will properly
	-- add the category and its dependencies to the saved variables

	-- when creating a new category, there can only be one parent (if any),
	-- we can add others later

	-- first, we check what needs to be checked
	if not private:CheckName(catName, enums.category) then return end
	if parentCatID and not dataManager:IsID(parentCatID) then
		-- chat:Print(L["The given parent category is not valid"]) -- TDLATER
		return
	end

	local catData = { -- catData
		name = catName,
		originalTabID = tabID,
		tabIDs = { -- we display the category in these tabs, updated later
			-- [tabID] = true,
			-- ...
		},
		closedInTabIDs = {
			-- [tabID] = true,
			-- ...
		},
		parentCatID = parentCatID,
		orderedContentIDs = { -- content of the cat, ordered (tinsert(contentOrderedIDs, 1, ID)), SECOND LOOP ON THIS FOR ITEMS AND RECURSIVELY ON SUB-CATEGORIES
			-- [catID or itemID], -- [1]
			-- [catID or itemID], -- [2]
			-- ... -- [...]
		},
	}

	catData.tabIDs[tabID] = true

	return private:AddCategory(dataManager:NewID(), catData)
end

-- tab

---Adds the given tab to the database.
---@param tabID string
---@param tabData table
---@param isGlobal boolean
---@return string|nil tabID
---@return table tabData
function private:AddTab(tabID, tabData, isGlobal)
	if dataManager:GetQuantity(enums.tab) >= enums.maxQuantities[enums.tab] then -- temp limit
		chat:Print(utils:SafeStringFormat(L["Cannot add %s"].." ("..L["Max quantity reached"]..")", L["Tab"]:lower()))
		return
	end

	-- we get where we are
	local tabsList = select(3, dataManager:GetData(isGlobal))

	-- we add the tab to the saved variables

	tabsList[tabID] = tabData -- adding action

	-- then we update its data
	tabData.shownIDs[tabID] = true -- self forced
	for shownID in pairs(tabData.shownIDs) do
		dataManager:UpdateShownTabID(tabID, shownID, true)
	end
	tinsert(tabsList.orderedTabIDs, tabID) -- position (last)

	-- refresh the mainFrame
	database.ctab(tabID)
	mainFrame:Refresh()

	-- AND refresh the tabsFrame & tab options
	tabsFrame:UpdateTab(tabID)
	AceConfigRegistry:NotifyChange(addonName)

	enums.quantities[enums.tab] = enums.quantities[enums.tab] + 1

	return tabID, tabData
end

---Creates and adds a new tab to the database.
---@param tabName string
---@param isGlobal boolean
---@return string|nil tabID
---@return table tabData
function dataManager:CreateTab(tabName, isGlobal)
	-- creates the formatted tab table with the given arguments,
	-- this table will then be sent to AddTab who will properly
	-- add the tab and its dependencies to the saved variables

	-- first, we check what needs to be checked
	if not private:CheckName(tabName, enums.tab) then return end

	local tabData = { -- tabData
		name = tabName,
		orderedCatIDs = { -- content of the tab, ordered (table.insert(contentOrderedIDs, 1, ID)), FIRST LOOP ON THIS FOR CATEGORIES
			-- [catID], -- [1]
			-- [catID], -- [2]
			-- ... -- [...]
		},
		-- tab specific data
		shownIDs = { -- user set
			-- [tabID] = true,
			-- ...
		},
		hideCheckedItems = false, -- user set
		deleteCheckedItems = false, -- user set
		hideCompletedCategories = true, -- user set
	}

	resetManager:InitTabData(tabData)

	return private:AddTab(dataManager:NewID(), tabData, isGlobal)
end

-- // moving functions

-- item

---Moves the item to the given pos, either in its current category, or a new one.
---@param itemID string
---@param newPos number
---@param newCatID string
function dataManager:MoveItem(itemID, newPos, newCatID)
	-- // this func is used to move items from one cat to another, and/or from one position to an other
	-- usage: dataManager:MoveItem(itemID, [newPos], [newCatID])

	-- / *** first things first, we validate all of the data *** /

	local itemData = select(3, dataManager:Find(itemID))

	--> old data

	-- loc, pos, cat
	local oldLoc, oldPos = dataManager:GetPosData(itemID)
	local oldCatID = itemData.catID

	--> new data

	-- cat
	newCatID = newCatID or oldCatID

	-- loc
	local newLoc = select(3, dataManager:Find(newCatID)).orderedContentIDs

	-- pos
	if type(newPos) ~= "number" then
		newPos = 1
	else
		newPos = utils:Clamp(newPos, 1, #newLoc + 1)
	end

	-- this check is to place the object correctly in case we just move its position inside its table,
	-- because when we'll remove it from the oldPos, everything will go down by one, the newPos too
	if newLoc == oldLoc
	and newPos > oldPos then
		newPos = newPos - 1
	end

	-- / *** then, we can start moving *** /

	tremove(oldLoc, oldPos)
	tinsert(newLoc, newPos, itemID)
	itemData.catID = newCatID
	dataManager:UpdateItemTab(itemID)

	mainFrame:Refresh()
end

---Helper to update an item's originalTabID and everything that goes with it when moving it.
---@param itemID string
function dataManager:UpdateItemTab(itemID)
	-- considering it's the same tab as the originalTabID of the category it is in

	local itemData = select(3, dataManager:Find(itemID))
	local catData = select(3, dataManager:Find(itemData.catID))

	local oldTabID = itemData.originalTabID
	local newTabID = catData.originalTabID

	private:UpdateTabsDisplay(oldTabID, false, itemID)
	itemData.originalTabID = newTabID
	private:UpdateTabsDisplay(newTabID, true, itemID)
end

-- category

---Moves the category to the given pos, depending on the given arguments.
---
---See func details to understand how the params are used.
---
---@param catID string
---@param newPos number
---@param newParentID string
---@param fromTabID string
---@param toTabID string
function dataManager:MoveCategory(catID, newPos, newParentID, fromTabID, toTabID)
	-- // this is the big func used to move categories from:
	--	- sub-cat 		--> normal cat
	--	- normal cat 	--> sub-cat
	--	- sub-cat 		--> sub-cat (order change in parent cat)
	-- 	- normal cat 	--> normal cat (order change in tab)
	-- this func also does the modifications to change the original tab of a category
	-- usage: dataManager:MoveCategory(catID, [newPos], [newParentID], [fromTabID], [toTabID])
	-- newParentID == nil --> ignore, newParentID == false --> no parent, newParentID == ID --> new parent

	-- / *** first things first, we validate all of the data *** /

	local catData, _, categoriesList, tabsList = select(3, dataManager:Find(catID))

	--> old data

	-- fromTab
	fromTabID = fromTabID or database.ctab()

	-- loc, pos, parentCat
	local oldLoc, oldPos = dataManager:GetPosData(catID, fromTabID)
	local oldParentID = catData.parentCatID

	--> new data

	-- toTab
	toTabID = toTabID or database.ctab()

	-- parentCat
	if newParentID == nil then
		newParentID = oldParentID -- ignore arg, we don't update the parent state
	elseif newParentID == false then
		newParentID = nil
	end

	-- loc
	dataManager:Find(toTabID) -- tab check
	local newLoc = newParentID and categoriesList[newParentID].orderedContentIDs or tabsList[toTabID].orderedCatIDs

	-- pos
	if type(newPos) ~= "number" then
		newPos = 1
	else
		newPos = utils:Clamp(newPos, 1, #newLoc + 1)
	end

	-- this check is to place the object correctly in case we just move its position inside its table,
	-- because when we'll remove it from the oldPos, everything will go down by one, the newPos too
	if newLoc == oldLoc
	and newPos > oldPos then
		newPos = newPos - 1
	end

	-- / *** then, we can start moving (oof) *** /

	-- position (order)
	if oldParentID and not newParentID then -- from sub-cat to normal cat
		tremove(oldLoc, oldPos)

		-- SPECIAL INSERT:
		-- since we're transforming the cat from a sub-cat to a normal one,
		-- we have to insert it back in each tab it is shown in
		tinsert(newLoc, newPos, catID)
		local firstParentID = tremove(dataManager:GetParents(catID))
		for tabID in pairs(catData.tabIDs) do
			if tabID ~= toTabID then -- if it's not the tab where we specifically decided to put it to newPos
				local loc, pos = dataManager:GetPosData(firstParentID, tabID)
				tinsert(loc, pos, catID) -- we put it over the cat we just extracted it from
			end
		end
	elseif not oldParentID and newParentID then -- from normal cat to sub-cat
		-- SPECIAL REMOVE:
		-- since we're transforming the cat from a normal cat to a sub one,
		-- we have to remove it from each tab it was shown in
		for tabID in pairs(catData.tabIDs) do
			local loc, pos = dataManager:GetPosData(catID, tabID)
			tremove(loc, pos)
		end

		tinsert(newLoc, newPos, catID)
	else -- from sub-cat to (maybe other) sub-cat (pos change) OR from normal cat to normal cat (pos change)
		tremove(oldLoc, oldPos)
		tinsert(newLoc, newPos, catID)
	end

	catData.parentCatID = newParentID

	-- tab
	if fromTabID ~= toTabID then
		-- category part
		private:UpdateTabsDisplay(fromTabID, false, catID)
		catData.originalTabID = toTabID
		private:UpdateTabsDisplay(toTabID, true, catID)

		-- we keep the closed state
		catData.closedInTabIDs[toTabID] = catData.closedInTabIDs[fromTabID]
		catData.closedInTabIDs[fromTabID] = nil

		-- content part
		for _,contentID in pairs(catData.orderedContentIDs) do
			local enum = dataManager:Find(contentID)
			if enum == enums.category then -- category
				dataManager:MoveCategory(contentID, nil, nil, fromTabID, toTabID)
			else -- item
				dataManager:UpdateItemTab(contentID)
			end
		end
	end

	mainFrame:Refresh()
end

-- tab

---Moves the tab to the given pos.
---@param tabID string
---@param newPos number
function dataManager:MoveTab(tabID, newPos)
	local loc, oldPos = dataManager:GetPosData(tabID)

	-- pos
	if type(newPos) ~= "number" then
		newPos = 1
	else
		newPos = utils:Clamp(newPos, 1, #loc + 1)
	end

	if newPos > oldPos then
		newPos = newPos - 1
	end

	tremove(loc, oldPos)
	tinsert(loc, newPos, tabID)

	mainFrame:Refresh()
	tabsFrame:Refresh()
end

-- luacheck: push ignore

---Future function used to move a tab from global to profile and vice-versa.
---@param tabID string
---@param newGlobalState boolean true = global, false = profile
function dataManager:ChangeTabGlobalState(tabID, newGlobalState)
	local oldGlobalState, tabData = select(2, dataManager:Find(tabID))
	-- TDLATER ChangeTabGlobalState

	-- TDLATER ChangeTabGlobalState message
	mainFrame:Refresh()
end

-- luacheck: pop

-- // remove functions

-- item

---Deletes the given item from the database.
---@param itemID string
---@return boolean success
function dataManager:DeleteItem(itemID)
	if dataManager:IsProtected(itemID) then return false end

	local itemData, itemsList = select(3, dataManager:Find(itemID))

	-- // we delete the item and all its related data

	-- we update its data (pretty much the reverse actions of the Add func)
	private:UpdateTabsDisplay(itemData.originalTabID, false, itemID)
	tremove(dataManager:GetPosData(itemID))

	local undoData = private:CreateUndo(itemID)
	private:AddUndo(undoData)
	itemsList[itemID] = nil -- delete action

	-- we hide a potentially opened desc frame
	widgets:DescFrameHide(itemID)

	-- refresh the mainFrame
	mainFrame:DeleteWidget(itemID)
	mainFrame:Refresh()

	enums.quantities[enums.item] = enums.quantities[enums.item] - 1

	return true
end

-- category

---Deletes the given category from the database.
---@param catID string
---@return boolean success
function dataManager:DeleteCat(catID)
	if dataManager:IsProtected(catID) then return false end

	local refreshID = dataManager:SetRefresh(false)

	local catData, _, categoriesList = select(3, dataManager:Find(catID))

	-- // we delete the category and all its related data

	-- we delete everything inside the category, even sub-categories recursively
	-- IMPORTANT: the use of a copy to iterate on is necessary, because in the loop,
	-- I'm going to delete elements in the very table I would be looping on
	local copy = utils:Deepcopy(catData.orderedContentIDs)
	local nbToUndo = 0

	for _,contentID in pairs(copy) do
		local result, nb = nil, 0
		if dataManager:Find(contentID) == enums.category then -- current ID is a sub-category
			result, nb = dataManager:DeleteCat(contentID) -- TDLATER crash quand delete tab qui a des sub-cats ?
		else -- current ID is an item
			result = dataManager:DeleteItem(contentID)
		end
		nbToUndo = nbToUndo + nb
		if result then nbToUndo = nbToUndo + 1 end
	end

	local undoData = private:CreateUndo(catID)
	local result

	if #catData.orderedContentIDs == 0 then -- we removed everything from the cat, now we delete it
		-- we update its data (pretty much the reverse actions of the Add func)
		private:UpdateTabsDisplay(catData.originalTabID, false, catID)

		private:AddUndo(undoData)
		categoriesList[catID] = nil -- delete action

		mainFrame:DeleteWidget(catID)

		enums.quantities[enums.category] = enums.quantities[enums.category] - 1
		result = true
	else
		if not clearing then
			chat:Print(L["Could not empty category"].." ("..L["Some of its content is protected"]..")")
		end
	end

	if nbToUndo > 0 then
		private:AddUndo(nbToUndo + (result and 1 or 0)) -- to undo in one go everything that was removed
	end

	dataManager:SetRefresh(true, refreshID)

	-- refresh the mainFrame
	mainFrame:Refresh()

	return result, nbToUndo
end

-- tab

---Deletes the given tab from the database.
---@param tabID string
---@return boolean success
function dataManager:DeleteTab(tabID)
	if dataManager:IsProtected(tabID) then return false end

	local refreshID = dataManager:SetRefresh(false)

	local isGlobal, tabData, _, categoriesList, tabsList = select(2, dataManager:Find(tabID))

  -- // we delete the tab and all its related data

	-- first we remove all of its shown IDs
	for shownTabID in pairs(tabData.shownIDs) do
		if shownTabID ~= tabID then
			dataManager:UpdateShownTabID(tabID, shownTabID, false)
		end
	end

	-- we delete everything inside the tab, this means every category inside of it
	local copy = utils:Deepcopy(tabData.orderedCatIDs)
	local nbToUndo = 0

	clearing = true
	for _,catID in pairs(copy) do
		if categoriesList[catID].originalTabID == tabID then -- (SPECIFIC: a tab deletion only deletes what's original to the tab, not everything that's shown inside of it)
			local result, nb = dataManager:DeleteCat(catID)
			if result or nb > 0 then
				nbToUndo = nbToUndo + 1
			end
		end
	end
	clearing = false

	local undoData = private:CreateUndo(tabID)
	local result

	if #tabData.orderedCatIDs == 0 then -- we removed everything from the tab, now we delete it
		-- we update its data (pretty much the reverse actions of the Add func)

		-- then we remove it from any other tab shown ID
		for forTabID, forTabData in dataManager:ForEach(enums.tab, isGlobal) do
			if forTabID ~= tabID then -- for every other tab
				if forTabData.shownIDs[tabID] then -- if it's showing the tab we're deleting
					dataManager:UpdateShownTabID(forTabID, tabID, false)
				end
			end
		end
		local loc, pos = dataManager:GetPosData(tabID)
		tremove(loc, pos)

		private:AddUndo(undoData)
		tabsList[tabID] = nil -- delete action

		enums.quantities[enums.tab] = enums.quantities[enums.tab] - 1

		if database.ctab() == tabID then
			database.ctab(loc[pos-1]) -- when deleting the tab we were on, we refocus a new one
		end

		-- AND refresh the tabsFrame
		tabsFrame:DeleteTab(tabID)

		result = true
	else
		chat:Print(L["Could not empty tab"].." ("..L["Some of its content is protected"]..")")
	end

	if nbToUndo > 0 then
		private:AddUndo(nbToUndo + (result and 1 or 0)) -- to undo in one go everything that was removed
	end

	dataManager:SetRefresh(true, refreshID)

	-- refresh the mainFrame
	mainFrame:Refresh()

	return result, nbToUndo
end

-- // undo feature

---Creates an undo data table from the given object.
---
---This is what gets added to the `NysTDL.acedb.profile.undoTable` saved variable (@see private:AddUndo()).
---
---@param ID string
---@return table undoData
function private:CreateUndo(ID)
	local enum, isGlobal, tableData = dataManager:Find(ID)

	local newUndo = { -- number for clears, table for single data
		enum = enum, -- what are we saving to undo?
		ID = ID, -- ID
		data = utils:Deepcopy(tableData), -- data
		isGlobal = isGlobal, -- used exclusively for tabs
	}

	return newUndo
end

---The actual adding of the undoData to the saved variable.
---@param undoData table|number
function private:AddUndo(undoData)
	-- this is so we can add undos at the right time, and possibly not at creation
	-- because the table data / orders can be modified in between the two actions.
	-- undoData can also be a pure number, to keep track of how many undos to undo after a clear
	tinsert(NysTDL.acedb.profile.undoTable, undoData)
end

---Undoes the last clear/object deletion found in `NysTDL.acedb.profile.undoTable`.
---@return boolean success
function dataManager:Undo()
	-- when undoing, there are 4 possible cases:
	-- undoing a clear, an item deletion, a category deletion, or a tab deletion
	if #NysTDL.acedb.profile.undoTable == 0 then
		chat:PrintForced(L["Nothing to undo"])
		return false
	end

	local refreshID = dataManager:SetRefresh(false)

	local success
	local toUndo = tremove(NysTDL.acedb.profile.undoTable) -- remove last
	if toUndo then -- if we got something to undo
		if type(toUndo) == "number" then -- clear
			if toUndo > 0 then -- undoing a clear
				local undoingID = dataManager:SetUndoing(true)

				for i=1, toUndo do
					success = not not dataManager:Undo()
					if not success then
						tinsert(NysTDL.acedb.profile.undoTable, toUndo-(i-1))
						chat:PrintForced(L["Undo interrupted"])
						break
					end
				end

				dataManager:SetUndoing(false, undoingID)

				if not undoing and success then
					chat:Print(L["Undo successful"])
				end
			else -- when we find a "0", we pass it like it was never here, and directly go undo the next item
				success = not not dataManager:Undo()
			end
		else
			if toUndo.enum == enums.item then -- item
				success = not not private:AddItem(toUndo.ID, toUndo.data)
			elseif toUndo.enum == enums.category then -- category
				success = not not private:AddCategory(toUndo.ID, toUndo.data)
			elseif toUndo.enum == enums.tab then -- tab
				success = not not private:AddTab(toUndo.ID, toUndo.data, toUndo.isGlobal)
			end
			if not success then -- cancel
				tinsert(NysTDL.acedb.profile.undoTable, toUndo)
			else
				if not undoing then
					local type = ((toUndo.enum == enums.item) and L["Item"]:lower())
					or ((toUndo.enum == enums.category) and L["Category"]:lower())
					or ((toUndo.enum == enums.tab) and L["Tab"]:lower())
					chat:Print(utils:SafeStringFormat(L["Added %s back"].." ("..type..")", "\""..dataManager:GetName(toUndo.ID).."\""))
				end
			end
		end
	end

	dataManager:SetRefresh(true, refreshID)

	-- refresh the mainFrame
	mainFrame:Refresh()

	return success
end

--/*******************/ DATA CONTROL /*************************/--

-- misc

----@see private:UpdateTabsDisplay
---@param catID string
---@param catData table
---@param tabID string
---@param tabData table
---@param shownTabID string
---@param modif boolean|nil
function private:UpdateCatShownTabID(catID, catData, tabID, tabData, shownTabID, modif)
	if catData.originalTabID == shownTabID then -- important
		catData.tabIDs[tabID] = modif
		if not catData.parentCatID then -- if it's not a sub-category, we edit it in its tab orders
			if modif and not utils:HasValue(tabData.orderedCatIDs, catID) then
				-- we add it ordered in the tab if it wasn't here already
				tinsert(tabData.orderedCatIDs, 1, catID) -- TDLATER, IF I ever do cat fav it's not pos 1
			elseif not modif and utils:HasValue(tabData.orderedCatIDs, catID) then
				tremove(tabData.orderedCatIDs, select(2, utils:HasValue(tabData.orderedCatIDs, catID)))
			end
		end
	end
end

----@see private:UpdateTabsDisplay
---@param itemID string
---@param itemData table
---@param tabID string
---@param tabData table
---@param shownTabID string
---@param modif boolean|nil
function private:UpdateItemShownTabID(itemID, itemData, tabID, tabData, shownTabID, modif)
	if itemData.originalTabID == shownTabID then -- important
		itemData.tabIDs[tabID] = modif
	end
end

---Function to update what is shown in which tab.
---
---See func details to understand how the params are used.
---
---@param shownTabID string
---@param modif boolean|nil
---@param ID string|nil
function private:UpdateTabsDisplay(shownTabID, modif, ID)
	-- both shownTabID and ID are the same global or profile state
	-- modif means adding/removing, modif = true --> adding, modif = false/nil --> removing
	-- ID is for only updating one specific ID (itemID.tabIDs or catID.tabIDs), instead of going through everything
	if modif == false then modif = nil end
	local enum, isGlobal, data = dataManager:Find(ID or shownTabID)

	for tabID,tabData in dataManager:ForEach(enums.tab, shownTabID) do -- for every tab that is showing the originalTabID
		-- we go through every category and every item, and for each that have
		-- the original tab equal to shownTabID, we add/remove the current tab to their tabIDs

		if ID then -- if it concerns only one ID
			if enum == enums.category then -- single category
				private:UpdateCatShownTabID(ID, data, tabID, tabData, shownTabID, modif)
			elseif enum == enums.item then -- single item
				private:UpdateItemShownTabID(ID, data, tabID, tabData, shownTabID, modif)
			end
		else -- if it concerns everything
			if tabID ~= shownTabID then -- if the tab is NOT the original shownTabID
				-- categories
				for catID,catData in dataManager:ForEach(enums.category, isGlobal) do
					private:UpdateCatShownTabID(catID, catData, tabID, tabData, shownTabID, modif)
				end
				-- items
				for itemID,itemData in dataManager:ForEach(enums.item, isGlobal) do
					private:UpdateItemShownTabID(itemID, itemData, tabID, tabData, shownTabID, modif)
				end
			end
		end
	end
end

---Helper to check if the given name is valid for the given enumObject.
---@param name string
---@param enum enumObject
---@return boolean isValid
function private:CheckName(name, enum)
	if #name == 0 then -- empty
		chat:Print(L["Name cannot be empty"])
		return false
	else
		local w, mw = math.floor(widgets:GetWidth(name)), enums.maxNameWidth[enum]
		if w > mw then -- width
			if utils:HasHyperlink(name) then -- this is for making more space for items that have hyperlinks in them
				mw = mw + enums.hyperlinkNameBonus
		    if w <= mw then
					return true
				end
			end
			chat:Print(L["Name is too large"]..string.format(" (%i/%i)", w, mw))
			return false
		end
	end

	return true
end

---Tries to rename the given object.
---@param ID string
---@param newName string
---@return boolean success
function dataManager:Rename(ID, newName)
	local enum, _, dataTable = dataManager:Find(ID)

	if not private:CheckName(newName, enum) then return false end

	dataTable.name = newName

	if enum == enums.tab then
		-- refresh the tabsFrame
		tabsFrame:UpdateTab(ID)
	else
		-- refresh the mainFrame
		mainFrame:UpdateWidget(ID, enum)
		mainFrame:Refresh()
	end

	return true
end

---Checks wether the given object is protected from deletion or not.
---@param ID string
---@return boolean isProtected
function dataManager:IsProtected(ID)
	local enum, _, _, _, _, tabsList = dataManager:Find(ID)

	if enum == enums.item then -- item
		-- return dataTable.favorite or dataTable.description
		return false
	elseif enum == enums.category then -- category
		return false -- TDLATER IsProtected category
	elseif enum == enums.tab then -- tab
		return #tabsList.orderedTabIDs <= 1
	end
end

-- items

---Changes the checked state of the given item.
---@param itemID string
---@param state nil|false|true nil => toggle | false => uncheck | true => check
---@return boolean newState
function dataManager:ToggleChecked(itemID, state)
	local itemData = select(3, dataManager:Find(itemID))

	if state == nil then
		itemData.checked = not itemData.checked
	elseif state == false then
		itemData.checked = false
	elseif state == true then
		itemData.checked = true
	end

	-- refresh the mainFrame
	if NysTDL.acedb.profile.instantRefresh then
		mainFrame:Refresh()
	else
		mainFrame:UpdateVisuals()
	end

	return itemData.checked
end

---Changes the favorite state of the given item.
---@param itemID string
---@param state nil|false|true nil => toggle | false => unfav | true => fav
---@return boolean newState
function dataManager:ToggleFavorite(itemID, state)
	local itemData = select(3, dataManager:Find(itemID))

	local new
	if state == nil then
		new = not itemData.favorite
	elseif state == false then
		new = false
	elseif state == true then
		new = true
	end

	if new == nil or new == itemData.favorite then
		return itemData.favorite
	end

	itemData.favorite = new

	-- we change the sort order of the item
	if itemData.favorite then -- if we passed it from non-fav to fav
		dataManager:MoveItem(itemID, 1)
	else -- if we passed it from fav to non-fav
		dataManager:MoveItem(itemID, dataManager:GetNextFavPos(itemData.catID))
	end

	-- refresh the mainFrame
	mainFrame:UpdateItemButtons(itemID)
	mainFrame:Refresh()

	return itemData.favorite
end

---Sets a new description for the given item.
---@param itemID string
---@param description string|nil
---@return string|boolean newDescription false if no description
function dataManager:UpdateDescription(itemID, description)
	local itemData = select(3, dataManager:Find(itemID))

	if type(description) ~= "string" or #description == 0 then
		description = false
	end

	itemData.description = description

	-- refresh the mainFrame
	mainFrame:UpdateItemButtons(itemID)

	return itemData.description
end

-- categories

---Returns the number of categories in the given tab.
---@param tabID string
---@return number
function dataManager:GetNbCategory(tabID)
	return #select(3, dataManager:Find(tabID)).orderedCatIDs
end

---Changes the closed state of the given category in the given tab.
---@param catID string
---@param tabID string
---@param state nil|false|true nil => toggle | false => close | true => open
function dataManager:ToggleClosed(catID, tabID, state)
	dataManager:Find(tabID) -- raises an error if the ID is not valid

	local catData = select(3, dataManager:Find(catID))
	if state == nil then
		catData.closedInTabIDs[tabID] = not catData.closedInTabIDs[tabID] or nil
	elseif state == false then
		catData.closedInTabIDs[tabID] = true
	elseif state == true then
		catData.closedInTabIDs[tabID] = nil
	end

	-- refresh the mainFrame
	mainFrame:Refresh()
end

---Finds and returns the next available favorite item position in the given category.
---@param catID string
---@return number
function dataManager:GetNextFavPos(catID)
	local catData = select(3, dataManager:Find(catID))
	local lastFavPos = 0
	for contentOrder,contentID in ipairs(catData.orderedContentIDs) do -- for everything that is in the cat
		local enum, _, contentData = dataManager:Find(contentID)
		if enum == enums.item then
			if contentData.favorite then
				lastFavPos = contentOrder
			end
		end
	end

	return lastFavPos + 1
end

local T_GetParents = {}
---Recursively finds and returns a table containing each parent category for a given item/category.
---(if we give a category, it is also by default considered as a parent)
---@param ID string
---@return table parents
function dataManager:GetParents(ID)
	local enum, _, data = dataManager:Find(ID)

	wipe(T_GetParents)

	local parentCatID
	if enum == enums.category then
		tinsert(T_GetParents, ID)
		parentCatID	= data.parentCatID
	elseif enum == enums.item then
		parentCatID	= data.catID
	end

	while parentCatID ~= nil do
		tinsert(T_GetParents, parentCatID)
		local parentCatData = select(3, dataManager:Find(parentCatID))
		parentCatID = parentCatData.parentCatID
	end

	return T_GetParents
end

---Returns true if the given cat has at least one sub-category inside of it.
---@param catID string
---@return boolean
function dataManager:IsParent(catID)
	local catData = select(3, dataManager:Find(catID))
	local contentWidgets = mainFrame:GetContentWidgets() -- to avoid using dataManager:Find() for each loop item (it's just for optimization)

	for _,contentID in ipairs(catData.orderedContentIDs) do -- for everything that is in the cat
		if contentWidgets[contentID].enum == enums.category then
			return true
		end
	end

	return false
end

---Returns true if the given cat is completed, aka "Is everything inside checked?" (recursively).
---@param catID string
---@return boolean
function dataManager:IsCategoryCompleted(catID)
	local total, checked = dataManager:GetCatCheckedNumbers(catID)
	return total > 0 and total == checked
end

-- tabs

---Function to change `tabData.shownIDs`.
---@param tabID string
---@param shownTabID string
---@param state boolean
function dataManager:UpdateShownTabID(tabID, shownTabID, state)
	-- to add/remove shown IDs in tabs
	local isGlobal1, tabData = select(2, dataManager:Find(tabID))
	local isGlobal2 = select(2, dataManager:Find(shownTabID))

	if isGlobal1 ~= isGlobal2 then -- should never happen (im just being a bit too paranoid :s)
		error("Cannot add/remove shown IDs with different global state") -- KEEP
	end

	if state then
		tabData.shownIDs[shownTabID] = true
		private:UpdateTabsDisplay(shownTabID, true)
	else
		private:UpdateTabsDisplay(shownTabID, false)
		tabData.shownIDs[shownTabID] = nil
	end

	-- refresh the mainFrame
	mainFrame:Refresh()
end

---Calls dataManager:ToggleChecked on everything in the given tab.
---@param tabID string
---@param state any See dataManager:ToggleChecked
function dataManager:ToggleTabChecked(tabID, state)
	local refreshID = dataManager:SetRefresh(false)

	for itemID in dataManager:ForEach(enums.item, tabID) do
		dataManager:ToggleChecked(itemID, state)
	end

	dataManager:SetRefresh(true, refreshID)

	-- refresh the mainFrame
	mainFrame:Refresh()
end

---Calls dataManager:ToggleClosed on everything in the given tab.
---@param tabID string
---@param state any See dataManager:ToggleClosed
function dataManager:ToggleTabClosed(tabID, state)
	local refreshID = dataManager:SetRefresh(false)

	for catID in dataManager:ForEach(enums.category, tabID) do
		dataManager:ToggleClosed(catID, tabID, state)
	end

	dataManager:SetRefresh(true, refreshID)

	-- refresh the mainFrame
	mainFrame:Refresh()
end

---Deletes everything in the given tab (if it is not protected, @see dataManager:IsProtected).
---@param tabID string
function dataManager:ClearTab(tabID)
	local copy = {}
	for catID,catData in dataManager:ForEach(enums.category, tabID) do
		copy[catID] = catData
	end

	local refreshID = dataManager:SetRefresh(false)

	clearing = true
	local nbToUndo = 0
	for catID in pairs(copy) do
		local result, nb = dataManager:DeleteCat(catID)
		if result or nb > 0 then
			nbToUndo = nbToUndo + 1
		end
	end
	clearing = false

	private:AddUndo(nbToUndo)

	dataManager:SetRefresh(true, refreshID)

	for _,_ in dataManager:ForEach(enums.category, tabID) do -- luacheck: ignore -- if there are cats left
		chat:Print(L["Could not empty tab"].." ("..L["Some of its content is protected"]..")")
		break
	end

	-- refresh the mainFrame
	mainFrame:Refresh()
end

local T_DeleteCheckedItems = {}
---Deletes every checked item in the given tab.
---@param tabID string
function dataManager:DeleteCheckedItems(tabID)
	wipe(T_DeleteCheckedItems)
	for itemID,itemData in dataManager:ForEach(enums.item, tabID) do
		if itemData.originalTabID == tabID and itemData.checked then -- if the item is native to the tab and checked
			T_DeleteCheckedItems[itemID] = itemData
		end
	end

	local refreshID = dataManager:SetRefresh(false)

	local nbToUndo = 0
	for itemID,itemData in pairs(T_DeleteCheckedItems) do -- for each item in the tab
		itemData.checked = false -- so that if we undo it, it doesn't get deleted right away
		if dataManager:DeleteItem(itemID) then
			nbToUndo = nbToUndo + 1
		else
			itemData.checked = true
		end
	end

	if nbToUndo > 0 then
		private:AddUndo(nbToUndo)
	end

	dataManager:SetRefresh(true, refreshID)
end

---Loops over every tab, and calls one (doAll=false/nil) or for all matching tabs (doAll=true) time the callback,
---if the next requirements are met:
--- - the tab has resets
--- - one of its resets are scheduled before maxTime
--- - it has more than one checkedType item inside of it
---@param maxTime number
---@param checkedType string See dataManager:GetRemainingNumbers
---@param callback function
---@param doAll boolean
function dataManager:DoIfFoundTabMatch(maxTime, checkedType, callback, doAll)

	for tabID,tabData in dataManager:ForEach(enums.tab) do -- for each tab
		if next(tabData.reset.nextResetTimes) then -- if it has resets
			if dataManager:GetRemainingNumbers(nil, tabID)[checkedType] > 0 then -- and if it has unchecked items
				for _, nextResetTime in pairs(tabData.reset.nextResetTimes) do -- then for each reset times it has
					if maxTime > nextResetTime then -- if one of them is coming in less than 24 hours
						callback(tabID, tabData)
						if doAll then break
						else return end -- only once if not said otherwise
					end
				end
			end
		end
	end
end

---Finds out if the given object is hidden in the given tab.
---@param ID string
---@param tabID string
---@return boolean
function dataManager:IsHidden(ID, tabID)
	if mainFrame.editMode then return false end

	local enum, _, objectData = dataManager:Find(ID)
	local tabData = select(3, dataManager:Find(tabID))

	if enum == enums.item then
		return tabData.hideCheckedItems and objectData.checked
	elseif enum == enums.category then
		return tabData.hideCompletedCategories and dataManager:IsCategoryCompleted(ID)
	end

	return false
end

--/*******************/ UTILS /*************************/--

local T_GetRemainingNumbers = {}
---Big function to get every numbers of checked/unchecked items, depending on the given location.
---
---See func details to understand how the params are used.
---
---@param isGlobal boolean
---@param tabID string
---@param catID string
---@return table remainingNumbers
function dataManager:GetRemainingNumbers(isGlobal, tabID, catID)
	-- The inputs can be one of these:
	-- 		dataManager:GetRemainingNumbers(nil/false/true) -- will search through EVERY item, in either profile+global/profile/global
	-- 		dataManager:GetRemainingNumbers(nil, tabID) -- will search through every item found in the tab
	-- 		dataManager:GetRemainingNumbers(nil, nil, catID) -- will search through every item found in the cat
	-- 		dataManager:GetRemainingNumbers(nil, tabID, catID) -- will search through every item found in the cat, that are also in the tab

	local t = T_GetRemainingNumbers
	wipe(t)

	-- // remaining numbers calculated:

	-- desc items
	t.totalDesc = nil
	t.checkedDesc = 0
	t.uncheckedDesc = 0

	-- fav items
	t.totalFav = nil
	t.checkedFav = 0
	t.uncheckedFav = 0

	-- items that are neither fav nor desc
	t.totalNormal = nil
	t.checkedNormal = 0
	t.uncheckedNormal = 0

	-- total
	t.total = nil
	t.totalChecked = 0
	t.totalUnchecked = 0

	local location = catID or tabID or isGlobal
	for _,itemData in dataManager:ForEach(enums.item, location) do -- for each item that is in the cat
		if not tabID or itemData.tabIDs[tabID] then
			if itemData.checked then
				t.totalChecked = t.totalChecked + 1
				if itemData.description then t.checkedDesc = t.checkedDesc + 1 end
				if itemData.favorite then t.checkedFav = t.checkedFav + 1 end
				if not itemData.description and not itemData.favorite then t.checkedNormal = t.checkedNormal + 1 end
			else
				t.totalUnchecked = t.totalUnchecked + 1
				if itemData.description then t.uncheckedDesc = t.uncheckedDesc + 1 end
				if itemData.favorite then t.uncheckedFav = t.uncheckedFav + 1 end
				if not itemData.description and not itemData.favorite then t.uncheckedNormal = t.uncheckedNormal + 1 end
			end
		end
	end

	t.totalDesc = t.checkedDesc + t.uncheckedDesc
	t.totalFav = t.checkedFav + t.uncheckedFav
	t.totalNormal = t.checkedNormal + t.uncheckedNormal
	t.total = t.totalChecked + t.totalUnchecked

	return t
end

local T_GetCatNumbers = {}
---Less hardcore than GetRemainingNumbers, this func returns the general content of the given gategory.
---@param catID string
---@return table catNumbers
function dataManager:GetCatNumbers(catID)
	-- //
	-- returns a table containing the following keys:
	-- - total 			-- subCats + items
	-- 	- subCats 		-- nb of subCats
	-- 	- items 		-- nb of items
	-- 		- desc 		-- at least have a desc
	-- 		- favs 		-- at least is fav
	-- 		- normal 	-- no desc and not fav

	local t = T_GetCatNumbers
	wipe(t)

	-- // numbers calculated:

	t.total = nil
	t.subCats = 0
	t.items = 0
	t.desc = 0
	t.favs = 0
	t.normal = 0

	local catData = select(3, dataManager:Find(catID))
	local contentWidgets = mainFrame:GetContentWidgets() -- to avoid using dataManager:Find() for each loop item (it's just for optimization)
	for _,contentID in ipairs(catData.orderedContentIDs) do -- for everything that is in the cat
		local widget = contentWidgets[contentID]
		if widget.enum == enums.category then
			t.subCats = t.subCats + 1
		elseif widget.enum == enums.item then
			t.items = t.items + 1
			local itemData = widget.itemData
			if itemData.checked then t.checked = t.checked + 1 end
			if itemData.description then t.desc = t.desc + 1 end
			if itemData.favorite then t.favs = t.favs + 1 end
			if not itemData.description and not itemData.favorite then t.normal = t.normal + 1 end
		end
	end

	t.total = t.subCats + t.items

	return t
end

---Less less hardcore than GetRemainingNumbers, this func returns the general content of the given gategory.
---@param catID string
---@return number total
---@return number checked
function dataManager:GetCatCheckedNumbers(catID)
	-- // -- ITEMS COMPLETION
	-- returns two values: return total, checked
	-- 		- total 		-- total nb of items (RECURSIVELY)
	-- 		- checked 		-- nb of checked items (RECURSIVELY)

	-- // numbers calculated:

	local total = 0
	local checked = 0

	local catData = select(3, dataManager:Find(catID))
	local contentWidgets = mainFrame:GetContentWidgets() -- to avoid using dataManager:Find() for each loop item (it's just for optimization)
	for _,contentID in ipairs(catData.orderedContentIDs) do -- for everything that is in the cat
		local widget = contentWidgets[contentID]
		if widget.enum == enums.category then
			local subTotal, subChecked = dataManager:GetCatCheckedNumbers(widget.catID)
			total, checked = total + subTotal, checked + subChecked
		elseif widget.enum == enums.item then
			total = total + 1
			if widget.itemData.checked then checked = checked + 1 end
		end
	end

	return total, checked
end
