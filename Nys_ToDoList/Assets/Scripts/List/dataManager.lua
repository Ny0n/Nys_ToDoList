-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local chat = addonTable.chat
local enums = addonTable.enums
local utils = addonTable.utils
local widgets = addonTable.widgets
local database = addonTable.database
local mainFrame = addonTable.mainFrame
local dataManager = addonTable.dataManager
local resetManager = addonTable.resetManager
local optionsManager = addonTable.optionsManager
local tutorialsManager = addonTable.tutorialsManager

-- Variables
local L = core.L

local maxNameWidth = {
	[enums.item] = 240,
	[enums.category] = 220,
	[enums.tab] = 80,
}

-- global aliases
local wipe = wipe
local unpack = unpack
local tinsert = table.insert
local tremove = table.remove

--/*******************/ DATA MANAGMENT /*************************/--

-- id func
function dataManager:newID()
	local newID = NysTDL.db.global.nextID
	NysTDL.db.global.nextID = NysTDL.db.global.nextID + 1
	return newID
end

-- misc functions

function dataManager:Find(ID)
	-- returns all necessary data concerning a given ID
	-- usage: local enum, isGlobal, idData, itemsList, categoriesList, tabsList = dataManager:Find(ID)

	for i=1,2 do -- global, profile
		local isGlobal = i==2
		local locations = dataManager:GetData(isGlobal, true)
		for enum,table in pairs(locations) do -- itemsList, categoriesList, tabsList
			if table[ID] ~= nil then -- presence test
				return enum, isGlobal, table[ID], dataManager:GetData(isGlobal)
			end
		end
	end

	error("ID not found, please post the trace as an issue on GitHub")
end

function dataManager:IsGlobal(ID)
	return (select(2, dataManager:Find(ID)))
end

function dataManager:GetData(isGlobal, tableMode)
	-- returns itemsList, categoriesList, and tabsList located either in the global or profile SV
	-- as a table if asked so

	local loc = isGlobal and NysTDL.db.global or NysTDL.db.profile
	if tableMode then
		return {
			[enums.item] = loc.itemsList,
			[enums.category] = loc.categoriesList,
			[enums.tab] = loc.tabsList
		}
	else
		return loc.itemsList, loc.categoriesList, loc.tabsList
	end
end

function dataManager:GetName(ID)
	return select(3, dataManager:Find(ID)).name
end

-- iterator function

-- // here is a function to iterate over the addon's data
-- enum either means items, categories or tabs
-- 		depending on what enum it is, I have manually added
--		specific checks and possibilities to ease the code in other places
-- location can be several values:
-- 		nil => iterate over the profile and the global tables
-- 		false => iterate over the profile table
-- 		true => iterate over the global table
-- 		number => iterate over the coresponding number's ID tables, while adding checks

function dataManager:ForEach(enum, location)
	-- // check part
	local isGlobal, getdatapos, checkFunc = location
	if enum == enums.item then
		getdatapos = 1
		if type(location) == enums.idtype then -- specific tab or cat ID
			enum, isGlobal = dataManager:Find(location)
			local loc
			if enum == enums.category then
				loc = "catIDs"
			elseif enum == enums.tab then
				loc = "tabIDs"
			else
				error("Coding error, bad ID", 2)
			end
			checkFunc = function(ID, data)
				if not data[loc][location] then return false end
				return true
			end
		end
	elseif enum == enums.category then
		getdatapos = 2
		if type(location) == enums.idtype then -- specific tab ID
			enum, isGlobal = dataManager:Find(location)
			if enum == enums.tab then
				checkFunc = function(ID, data)
					if not data.tabIDs[location] then return false end
					return true
				end
			else
				error("Coding error, bad ID", 2)
			end
		end
	elseif enum == enums.tab then
		getdatapos = 3
		if type(location) == enums.idtype then -- specific shown ID
			enum, isGlobal = dataManager:Find(location)
			if enum == enums.tab then
				checkFunc = function(ID, data)
					if ID == "orderedTabIDs" then return false end -- every time
					if not data.shownIDs[location] then return false end
					return true
				end
			else
				error("Coding error, bad ID", 2)
			end
		else -- in any case, there is something to check for any tab iteration
			checkFunc = function(ID, data)
				if ID == "orderedTabIDs" then return false end -- every time
				return true
			end
		end
	else
		error("Forgot ForEach argument #1", 2)
	end

	-- // iteration part
	local table, key, data = (select(getdatapos, dataManager:GetData(isGlobal)))
	return function()
		::redo::

		-- first we get the next value
		key, data = next(table, key)

		if checkFunc and not checkFunc(key, data) then goto redo end

		-- then we check what to return
		if key == nil and isGlobal == nil then
			-- if we finished one table and isGlobal was nil, then we start the other table
			isGlobal = not isGlobal
			table = (select(getdatapos, dataManager:GetData(isGlobal)))
			key = nil
			goto redo
		end
		return key, data, isGlobal
	end
end

-- // adding functions

-- item

function dataManager:CreateItem(itemName, tabID, catID)
	-- creates the formatted item table with the given arguments,
	-- this table will then be sent to AddItem who will properly
	-- add the item and its dependencies to the saved variables

	-- first, we check what needs to be checked
	if not dataManager:CheckName(itemName, enums.item) then return end

	local newItem = { -- itemData
    name = itemName,
    originalTabID = tabID,
    tabIDs = {}, -- we display the item in these tabs, updated later
    catIDs = { -- for convenience when deleting items, so that we can remove them from their respective categories easily
      [catID] = true,
			-- ...
    },
    -- item specific data
    checked = false,
    accountWide = false, -- user set, used in global tabs
    accountChecked = { -- user set, used in global tabs
      -- [profileName] = false or true, -- first one is self, and is the only one for profile items
      -- [profileName] = false or true, -- others are used only for global items
      -- ...
    },
    favorite = false,
    description = false,
  }

	return newItem
end

function dataManager:AddItem(itemData, itemID, itemOrder)
	-- itemData is either coming from CreateItem or is already a full fleshed item coming from the undo table
	itemID = itemID or dataManager:newID()
	itemOrder = itemOrder or {[next(itemData.catIDs)] = 1} -- an item either is new and only has one cat, or comes from an undo and already has orders

	-- we add the item to the saved variables
	-- so first we get where we are, aka tab, global?, and corresponding saved variables
	local itemsList, categoriesList = select(4, dataManager:Find(next(itemData.tabIDs)))

	itemsList[itemID] = itemData -- adding action
	dataManager:UpdateTabsDisplay(itemData.originalTabID, true, itemID)
	for catID in pairs(itemData.catIDs) do
		-- we add it ordered in its category
		if not categoriesList[catID] then error("Category does not exist?!") end -- TODO
		local cIDs = categoriesList[catID].orderedContentIDs
		tinsert(cIDs, itemOrder[catID] > #cIDs and #cIDs + 1 or itemOrder[catID], itemID) -- saved order or first
	end

	return itemID
end

-- category

function dataManager:CreateCategory(catName, tabID, parentCatID)
	-- creates the formatted category table with the given arguments,
	-- this table will then be sent to AddCategory who will properly
	-- add the category and its dependencies to the saved variables

	-- when creating a new category, there can only be one parent (if any),
	-- we can add others later

	-- first, we check what needs to be checked
	if not dataManager:CheckName(catName, "categoriesList") then return end

	local newCategory = { -- catData
    name = catName,
    originalTabID = tabID,
    tabIDs = {}, -- we display the category in these tabs, updated later
    closedInTabIDs = {
      -- [tabID] = true,
      -- [tabID] = true,
      -- ...
    },
    parentsInTabIDs = {
			[tabID] = parentCatID, -- nil or parentCatID
      -- [tabID] = parentCatID, -- in tabID tab, the category has a parent, and it's catID
      -- [tabID] = nil, -- in tabID tab, the category is not a sub-category
      -- ...
		},
    orderedContentIDs = { -- content of the cat, ordered (tinsert(contentOrderedIDs, 1, ID)), SECOND LOOP ON THIS FOR ITEMS AND RECURSIVELY ON SUB-CATEGORIES
      -- [catID or itemID], -- [1]
      -- [catID or itemID], -- [2]
      -- ... -- [...]
    },
  }

	return newCategory
end

function dataManager:AddCategory(catData, catID, catOrder)
	-- catData is either coming from CreateCategory or is already a full fleshed category coming from the undo table
	catID = catID or dataManager:newID()
	catOrder = catOrder or {[next(catData.tabIDs)] = 1} -- a category either is new and only has one tab, or comes from an undo and already has orders

	-- we add the category to the saved variables
	-- so first we get where we are, aka tab, global?, and corresponding saved variables
	local categoriesList = select(5, dataManager:Find(next(catData.tabIDs)))

	categoriesList[catID] = catData -- adding action
	dataManager:UpdateTabsDisplay(catData.originalTabID, true, catID)
	for tabID in pairs(catData.tabIDs) do
		-- and we add it ordered in the right places
		local ordersloc = dataManager:GetCategoryOrdersLoc(catID, tabID)
		tinsert(ordersloc, catOrder[catID] > #ordersloc and #ordersloc + 1 or catOrder[catID], catID) -- saved order or first
	end

	return catID
end

-- tab

function dataManager:CreateTab(tabName)
	-- creates the formatted tab table with the given arguments,
	-- this table will then be sent to AddTab who will properly
	-- add the tab and its dependencies to the saved variables

	-- first, we check what needs to be checked
	if not dataManager:CheckName(tabName, "tabsList") then return end

	local newTab = { -- tabData
    name = "tabName",
		orderedCatIDs = { -- content of the tab, ordered (table.insert(contentOrderedIDs, 1, ID)), FIRST LOOP ON THIS FOR CATEGORIES
      -- [catID], -- [1]
      -- [catID], -- [2]
      -- ... -- [...]
    },
    -- reset data
    reset = { -- content is user set
      isSameEachDay = true,
      sameEachDay = resetManager:NewResetData(), -- isSameEachDay reset data
      days = { -- the actual reset times used for the auto reset on each given day
        -- [2] = resetData,
        -- [3] = resetData,
        -- ...
      },
			saves = { -- so that when we uncheck isSameEachDay, we recover each day's own reset data
				-- [2] = resetData,
				-- [3] = resetData,
				-- ...
			},
			nextResetTimes = { -- for when we log on or reload the addon, we first check if a reset date has passed
				n = 0,
				-- [1 (n++)] = 115884212 (time() + timeUntil)
				-- [2 (n++)] = 115847721 (time() + timeUntil)
				-- ...
			},
    },
		-- tab specific data
		shownIDs = { -- user set
      [tabID] = true, -- self forced
      -- [tabID] = true,
      -- ...
    },
    hideCheckedItems = false, -- user set
    deleteCheckedItems = false, -- user set
  }

	return newTab
end

function dataManager:AddTab(tabData, isGlobal, tabID, tabOrder)
	-- catData is either coming from CreateTab or is already a full fleshed tab coming from the undo table
	tabID = tabID or dataManager:newID()

	-- we add the tab to the saved variables

	-- so first we get where we are, aka corresponding saved variables
	local tabsList = select(3, dataManager:GetData(isGlobal))

	tabOrder = tabOrder or #tabsList.orderedTabIDs + 1 -- a tab either is new and is put last in line, or comes from an undo and already has an order

	tabsList[tabID] = tabData -- adding action

	for shownID in pairs(tabData.shownIDs) do
		dataManager:UpdateShownTabID(tabID, shownID, true)
	end

	-- and we add it ordered in the tabs table
	local oIDs = tabsList.orderedTabIDs
	tinsert(oIDs, tabOrder <= #oIDs and tabOrder or #oIDs + 1, tabID) -- saved order or last

	return tabID
end

-- // moving functions

-- item

function dataManager:MoveItem(itemID, oldPos, newPos, oldCatID, newCatID, oldTabID, newTabID)
	local itemData = select(3, dataManager:Find(itemID))

	-- position (order)
	if oldCatID ~= newCatID or oldPos ~= newPos then
		local oldCatData = select(3, dataManager:Find(oldCatID))
		local newCatData = select(3, dataManager:Find(newCatID))
		tremove(oldCatData.orderedContentIDs, oldPos)
		tinsert(newCatData.orderedContentIDs, newPos, itemID)
		-- cat
		itemData.catIDs[oldCatID] = nil
		itemData.catIDs[newCatID] = true
	end

	-- tab
	if oldTabID ~= newTabID then
		dataManager:UpdateTabsDisplay(oldTabID, false, itemID)
		itemData.originalTabID = newTabID
		dataManager:UpdateTabsDisplay(newTabID, true, itemID)
	end

	-- TODO message?
end

-- category

function dataManager:MoveCategory(catID, oldPos, newPos, oldParentID, newParentID, oldTabID, newTabID)
	local catData, itemsList, categoriesList, tabsList = select(3, dataManager:Find(catID))

	-- position (order)
	if oldPos ~= newPos or oldParentID ~= newParentID then
		local oldOrdersLoc = oldParentID and categoriesList[oldParentID].orderedContentIDs or tabsList[oldTabID].orderedCatIDs
		local newOrdersLoc = newParentID and categoriesList[newParentID].orderedContentIDs or tabsList[newTabID].orderedCatIDs
		tremove(oldOrdersLoc, oldPos)
		tinsert(newOrdersLoc, newPos, catID)
		catData.parentsInTabIDs[oldTabID] = oldParentID
		catData.parentsInTabIDs[newTabID] = newParentID
	end

	-- tab
	if oldTabID ~= newTabID then
		-- category part
		dataManager:UpdateTabsDisplay(oldTabID, false, catID)
		catData.originalTabID = newTabID
		dataManager:UpdateTabsDisplay(newTabID, true, catID)
		catData.closedInTabIDs[newTabID] = catData.closedInTabIDs[oldTabID] -- we keep the closed state
		catData.closedInTabIDs[oldTabID] = nil

		-- content part
		for _,contentID in pairs(catData.orderedContentIDs) do
			local enum = dataManager:Find(contentID)
			if enum == enums.category then -- category
				dataManager:MoveCategory(contentID, nil, nil, nil, nil, oldTabID, newTabID)
			else -- item
				dataManager:MoveItem(contentID, nil, nil, nil, nil, oldTabID, newTabID)
			end
		end
	end

	-- TODO message?
end

-- tab

function dataManager:MoveTab(tabID, oldPos, newPos, oldGlobalState, newGlobalState)
	-- TODO
end

-- // remove functions

-- item

function dataManager:DeleteItem(itemID)
	local itemData, itemsList, categoriesList = select(3, dataManager:Find(itemID))

	if dataManager:IsProtected(itemID) then return end

  -- we delete the item and all its related data

	local undoData = dataManager:CreateUndo(itemID)

	-- for every cat the item is in, we remove it from the contents
	for catID in pairs(itemData.catIDs) do
		local cIDs = categoriesList[catID].orderedContentIDs
  	tremove(cIDs, select(2, utils:HasValue(cIDs, itemID)))
	end

	dataManager:AddUndo(undoData)
  itemsList[itemID] = nil -- delete action

	return true
end

-- category

function dataManager:DeleteCat(catID, empty)
	local catData, _, categoriesList = select(3, dataManager:Find(catID))

	if dataManager:IsProtected(catID) then return end

  -- we delete the category and all its related data

	local undoData = dataManager:CreateUndo(catID)
	local nbToDelete = #catData.orderedContentIDs

	-- we delete everything inside the category, even sub-categories recursively
	for _,contentID in pairs(catData.orderedContentIDs) do
		if dataManager:Find(contentID) == enums.category then -- current ID is a sub-category
			dataManager:DeleteCat(contentID)
		else -- current ID is an item
			dataManager:DeleteItem(contentID)
		end
	end

	if #catData.orderedContentIDs == 0 and not empty then -- we removed everything from the cat, now we delete it
		-- we remove the category from every content table it can be found in
		for tabID in pairs(catData.tabIDs) do
			local ordersLoc = dataManager:GetCategoryOrdersLoc(catID, tabID)
	  	tremove(ordersLoc, select(2, utils:HasValue(ordersLoc, catID)))
		end

		dataManager:AddUndo(undoData)
		nbToDelete = nbToDelete + 1
	  categoriesList[catID] = nil -- delete action
	end
	dataManager:AddUndo(nbToDelete - #catData.orderedContentIDs) -- to undo in one go everything that was removed

	return true
end

-- tab

function dataManager:DeleteTab(tabID)
	local tabData, _, _, tabsList = select(3, dataManager:Find(tabID))

	if dataManager:IsProtected(tabID) then return end -- TODO message "xxx is protected" ?

  -- we delete the tab and all its related data

	local undoData = dataManager:CreateUndo(tabID)
	local nbToDelete = #tabData.orderedCatIDs

	-- first we remove every shown tab ID
	for shownTabID in pairs(tabData.shownIDs) do
		if shownTabID ~= tabID then
			dataManager:UpdateShownTabID(tabID, shownTabID, false)
		end
	end

 	-- we delete everything inside the tab, this means every category inside of it
	for _,catID in pairs(tabData.orderedCatIDs) do
		dataManager:DeleteCat(catID) -- TODO protected?
	end

	if #tabData.orderedCatIDs == 0 then -- we removed everything from the tab, now we delete it
		-- we remove the tab from its orders table
		tremove(tabsList.orderedTabIDs, select(2, utils:HasValue(tabsList.orderedTabIDs, tabID)))

		dataManager:AddUndo(undoData)
		nbToDelete = nbToDelete + 1
	  tabsList[tabID] = nil -- delete action
	end
	dataManager:AddUndo(nbToDelete - #tabsList.orderedCatIDs) -- to undo in one go everything that was removed

	return true
end

-- // undo feature

function dataManager:CreateUndo(ID)
	local enum, isGlobal, tableData, _, categoriesList, tabsList = dataManager:Find(ID)

	local newUndo = { -- number for clears, table for single data
    enum = enum,
    ID = ID,
    orders = {},
    data = utils:Deepcopy(tableData),
		isGlobal = isGlobal, -- used exclusively for tabs
	}

	-- this is to keep the orders the removed object was if we want to undo the remove
	if enum == enums.item then -- item
		for catID in pairs(tableData.catIDs) do
			newUndo.orders[catID] = select(2, utils:HasValue(categoriesList[catID].orderedContentIDs, ID))
		end
	elseif enum == enums.category then -- category
		for tabID in pairs(tableData.tabIDs) do
			local ordersLoc = dataManager:GetCategoryOrdersLoc(ID, tabID)
			newUndo.orders[tabID] = select(2, utils:HasValue(ordersLoc, ID))
		end
	elseif enum == enums.tab then -- tab
		newUndo.orders = select(2, utils:HasValue(tabsList.orderedTabIDs, ID))
	end

	return newUndo
end

function dataManager:AddUndo(undoData)
	-- this is so we can add undos at the right time, and possibly not at creation
	-- because the table data / orders can be modified in between the two actions.
	-- undoData can also be a pure number, to keep track of how many undos to undo after a clear
	tinsert(NysTDL.db.profile.undoTable, undoData)
end

function dataManager:Undo()
	-- when undoing, there are 4 possible cases:
	-- undoing a clear, an item deletion, a category deletion, or a tab deletion

	if #NysTDL.db.profile.undoTable == 0 then
		-- TODO print "no undos"
		return
	end

	local toUndo = tremove(NysTDL.db.profile.undoTable) -- remove last
	if type(toUndo) == "number" then -- clear
		if toUndo <= 0 then toUndo = 1 end -- when we find a "0", we pass it like it was never here, and directly go undo the next item
		for i=1, toUndo do dataManager:Undo() end
		-- TODO messages "undo clear" and others
	elseif toUndo.enum == enums.item then -- item
		dataManager:AddItem(toUndo.data, toUndo.ID, toUndo.orders)
	elseif toUndo.enum == enums.category then -- category
		dataManager:AddCategory(toUndo.data, toUndo.ID, toUndo.orders)
	elseif toUndo.enum == enums.tab then -- tab
		dataManager:AddTab(toUndo.data, toUndo.isGlobal, toUndo.ID, toUndo.orders)
	end
end

--/*******************/ DATA CONTROL /*************************/--

-- misc

function dataManager:GetCategoryOrdersLoc(catID, tabID)
	-- since categories are either located in an other category (as a sub-category) or in a tab,
	-- this is to easily get the good orders table where a category is in a certain tab
	local catData, _, categoriesList, tabsList = select(3, dataManager:Find(catID))
	local parentCatID = catData.parentsInTabIDs[tabID] -- nil or parentCatID
	return parentCatID and categoriesList[parentCatID].orderedContentIDs or tabsList[tabID].orderedCatIDs
end

function dataManager:CheckName(name, enum)
	if #name == 0 then -- empty
		-- TODO message
		return false
	elseif widgets:GetWidth(name) > maxNameWidth[enum] then -- width
		-- TODO message
		return false
	end

	return true
end

function dataManager:Rename(ID, newName)
	local enum, _, dataTable = dataManager:Find(ID)

	if not dataManager:CheckName(newName, enum) then return end

	dataTable.name = newName
	return true
end

function dataManager:IsProtected(ID)
	local enum, _, dataTable = dataManager:Find(ID)

	if enum == enums.item then -- item
		return dataTable.favorite or dataTable.description
	elseif enum == enums.category then -- category
		return false -- TODO
	elseif enum == enums.tab then -- tab
		return false -- TODO
	end
end

-- items

function dataManager:ToggleChecked(itemID)
	local itemData = select(3, dataManager:Find(itemID))
	itemData.checked = not itemData.checked
	return itemData.checked
end

function dataManager:ToggleFavorite(itemID)
	local itemData = select(3, dataManager:Find(itemID))
	itemData.favorite = not itemData.favorite
	return itemData.favorite
end

function dataManager:UpdateDescription(itemID, description)
	local itemData = select(3, dataManager:Find(itemID))
	if description == "" then description = false end
	itemData.description = description
	return itemData.description
end

-- categories

-- tabs

local T_UpdateTabsDisplay = {
	itemsList = {},
	categoriesList = {},
}
function dataManager:UpdateTabsDisplay(originalTabID, modif, ID)
	-- // big important func to update what is shown in what tab

	-- both originalTabID and ID are the same global or profile state
	-- modif means adding/removing, modif = true --> adding, modif = false/nil --> removing
	if modif == false then modif = nil end
	-- ID is for only updating one specific ID (itemID.tabIDs or catID.tabIDs), instead of going through everything
	local enum, isGlobal, data, itemsList, categoriesList = dataManager:Find(ID or originalTabID)

	-- we check if it concerns only one ID
	if ID then
		itemsList = T_UpdateTabsDisplay.itemsList
		categoriesList = T_UpdateTabsDisplay.categoriesList
		wipe(itemsList)
		wipe(categoriesList)
		if enum == enums.category then -- single category
			categoriesList[ID] = data
		elseif enum == enums.item then -- single item
			itemsList[ID] = data
		end
	end

	for tabID,tabData in dataManager:ForEach(enums.tab, originalTabID) do -- for every tab that is showing the originalTabID
		-- we go through every category and every item, and for each that have
		-- the original tab equal to originalTabID, we add/remove the current tab to their tabIDs

		-- categories
		for catID,catData in ID and pairs(categoriesList) or dataManager:ForEach(enums.category, isGlobal) do
			catData.tabIDs[tabID] = modif
			if not catData.parentsInTabIDs[catData.originalTabID] then -- if it's not a sub-category, we edit it in its tab orders
				if modif and not utils:HasValue(tabData.orderedCatIDs, catID) and not ID then
					-- we add it ordered in the tab if it wasn't here already
					local ordersLoc = tabData.orderedCatIDs
					tinsert(ordersLoc, 1, catID)
				elseif not modif then
					tremove(tabData.orderedCatIDs, select(2, utils:HasValue(tabData.orderedCatIDs, catID)))
				end
			end
		end

		-- items
		for itemID,itemData in ID and pairs(itemsList) or dataManager:ForEach(enums.item, isGlobal) do
				itemData.tabIDs[tabID] = modif
		end
	end
end

function dataManager:UpdateShownTabID(tabID, shownTabID, state)
	-- to add/remove shown IDs in tabs
	local isGlobal1, tabData = select(2, dataManager:Find(tabID))
	local isGlobal2, shownTabData = select(2, dataManager:Find(shownTabID))

	if isGlobal1 ~= isGlobal2 then -- should never happen (im just being a bit too paranoid :s)
		error("Coding error, cannot add/remove shown IDs with different global state")
	end

	if state then
		tabData.shownIDs[shownTabID] = true
		dataManager:UpdateTabsDisplay(shownTabID, true)
	else
		dataManager:UpdateTabsDisplay(shownTabID, false)
		tabData.shownIDs[shownTabID] = nil
	end
end

function dataManager:UncheckTab(tabID)
	for itemID,itemData in dataManager:ForEach(enums.item, tabID) do
		itemData.checked = false
	end
end

function dataManager:CheckTab(tabID)
	for itemID,itemData in dataManager:ForEach(enums.item, tabID) do
		itemData.checked = true
	end
end

function dataManager:ClearTab(tabID)
	local removed = 0
	for catID,catData in dataManager:ForEach(enums.category, tabID) do
		if dataManager:DeleteCat(catID) then
			removed = removed + 1
		end
	end
	dataManager:AddUndo(removed)
end

function dataManager:DoIfFoundTabMatch(maxTime, checkedType, callback, doAll)
	-- // loops over every tab, and calls one (doAll=false/nil) or for all matching tabs (doAll=true) time the callback,
	-- if the next requirements are met:
	-- - the tab has resets
	-- - one of its resets are scheduled before maxTime
	-- - it has more than one checkedType item inside of it

	for tabID,tabData in dataManager:ForEach(enums.tab) do -- for each tab
		if next(tabData.nextResetTimes) then -- if it has resets
			if dataManager:GetRemainingNumbers(nil, tabID)[checkedType] > 0 then -- and if it has unchecked items
				for _, nextResetTime in pairs(tabData.nextResetTimes) do -- then for each reset times it has
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

--/*******************/ UTILS /*************************/--

local T_GetRemainingNumbers = {}
function dataManager:GetRemainingNumbers(isGlobal, tabID, catID)
	-- // big func to get every numbers of checked/unchecked items,
	-- depending on the given location. the inputs can be one of these:
	-- dataManager:GetRemainingNumbers(nil/false/true) -- will search through EVERY item, in either profile+global/profile/global
	-- dataManager:GetRemainingNumbers(nil, tabID) -- will search through every item found in the tab
	-- dataManager:GetRemainingNumbers(nil, nil, catID) -- will search through every item found in the cat
	-- dataManager:GetRemainingNumbers(nil, tabID, catID) -- will search through every item found in the cat, that are also in the tab

	local t = T_GetRemainingNumbers
	wipe(t)
	t.checked = 0
	t.checkedFavs = 0
	t.checkedDesc = 0
	t.unchecked = 0
	t.uncheckedFavs = 0
	t.uncheckedDesc = 0
	t.total = 0

	local location = catID or tabID or isGlobal

	for itemID,itemData in dataManager:ForEach(enums.item, location) do -- for each item that is in the cat
		if tabID and not itemData.tabIDs[tabID] then goto next end

		if itemData.checked then
			t.checked = t.checked + 1
			if itemData.favorite then t.checkedFavs = t.checkedFavs + 1 end
			if itemData.description then t.checkedDesc = t.checkedDesc + 1 end
		else
			t.unchecked = t.unchecked + 1
			if itemData.favorite then t.uncheckedFavs = t.uncheckedFavs + 1 end
			if itemData.description then t.uncheckedDesc = t.uncheckedDesc + 1 end
		end
		t.total = t.total + 1

		::next::
	end

	return t
end
