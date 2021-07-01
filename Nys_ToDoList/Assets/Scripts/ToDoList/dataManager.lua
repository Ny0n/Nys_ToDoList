-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local chat = addonTable.chat
local utils = addonTable.utils
local widgets = addonTable.widgets
local database = addonTable.database
local autoReset = addonTable.autoReset
local mainFrame = addonTable.mainFrame
local dataManager = addonTable.dataManager
local optionsManager = addonTable.optionsManager
local tutorialsManager = addonTable.tutorialsManager

-- Variables
local L = core.L

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

local T_Find = {
	-- where to look in the global saved database variable
	locations = { "global", "profile" },
	tables = { "itemsList", "categoriesList", "tabsList" },
	tablesToReturn = {},
}
function dataManager:Find(ID)
	-- returns all necessary data concerning a given ID
	-- usage: local exists, isGlobal, tableName, tableData, itemsList, categoriesList, tabsList = dataManager:Find(ID)

	local found, tableName, tableData = false

	for _,loc in pairs(T_Find.locations) do -- global, profile
		wipe(T_Find.tablesToReturn)

		for _,table in pairs(T_Find.tables) do -- "itemsList", "categoriesList", "tabsList"
			tinsert(T_Find.tablesToReturn, NysTDL.db[loc][table])
			if NysTDL.db[loc][table] and NysTDL.db[loc][table][ID] ~= nil then -- presence test
				found = true
				tableName = table
				tableData = NysTDL.db[loc][table][ID]
			end
		end

		if found then
			return true, loc == "global", tableName, tableData, unpack(T_Find.tablesToReturn)
		end
	end

	return false
end

function dataManager:IsProtected(ID)
	local exists, _, tableName, dataTable = dataManager:Find(ID)
	if not exists then error("ID does not exist?!") end -- TODO

	if tableName == "itemsList" then -- item
		return dataTable.favorite or dataTable.description
	elseif tableName == "categoriesList" then -- category
		return false -- TODO
	elseif tableName == "tabsList" then -- tab
		return false -- TODO
	end
end

function dataManager:GetCategoryOrdersLoc(catID, tabID)
	-- since categories are either located in an other category (as a sub-category) or in a tab,
	-- this is to easily get the good orders table where a category is in a certain tab
	local catData, _, categoriesList, tabsList = select(4, dataManager:Find(catID))
	local parentCatID = catData.parentsInTabIDs[tabID] -- nil or parentCatID
	return parentCatID and categoriesList[parentCatID].orderedContentIDs or tabsList[tabID].orderedCatIDs
end

local T_UpdateTabsDisplay = {
	itemsList = {},
	categoriesList = {},
}
function dataManager:UpdateTabsDisplay(originalTabID, modif, ID, catOrder)
	-- modif means adding/removing, modif = true --> adding, modif = false/nil --> removing
	if modif == false then modif = nil end
	-- ID is for only updating one specific ID, instead of going through everything
	local tableName, data, itemsList, categoriesList, tabsList = select(3, dataManager:Find(ID or originalTabID))

	if ID then
		itemsList = T_UpdateTabsDisplay.itemsList
		categoriesList = T_UpdateTabsDisplay.categoriesList
		wipe(itemsList)
		wipe(itemsList)
		if tableName == "categoriesList" then -- single category
			categoriesList[ID] = data
		elseif tableName == "itemsList" then -- single item
			itemsList[ID] = data
		end
	end

	for tabID,tabData in pairs(tabsList) do -- for every tab
		if tabID == "orderedTabIDs" then goto nextTab end
		if not tabData.shownIDs[originalTabID] then goto nextTab end -- that is showing the originalTabID

		-- we go through every category and every item, and for each that have
		-- the original tab equal to originalTabID, we add the current tab to their tabIDs
		for catID,catData in pairs(categoriesList) do
			if catData.originalTabID == originalTabID then -- important
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
		end

		for itemID,itemData in pairs(itemsList) do
			if itemData.originalTabID == originalTabID then -- important
				itemData.tabIDs[tabID] = modif
			end
		end

		::nextTab::
	end
end

function dataManager:UpdateShownTabID(tabID, shownTabID, state)
	-- to add/remove shown IDs in tabs
	local tabData = select(4, dataManager:Find(tabID))
	if state then
		tabData.shownIDs[shownTabID] = true
		dataManager:UpdateTabsDisplay(shownTabID, true)
	else
		dataManager:UpdateTabsDisplay(shownTabID)
		tabData.shownIDs[shownTabID] = nil
	end
end

-- // adding functions

-- item

function dataManager:CreateItem(itemName, tabID, catID)
	-- creates the formatted item table with the given arguments,
	-- this table will then be sent to AddItem who will properly
	-- add the item and its dependencies to the saved variables

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
	local exists, _, _, _, itemsList, categoriesList = dataManager:Find(next(itemData.tabIDs))
	if not exists then error("Tab does not exist?!") end -- TODO

	itemsList[itemID] = itemData -- adding action
	dataManager:UpdateTabsDisplay(itemData.originalTabID, true, itemID)
	for catID in pairs(itemData.catIDs) do
		-- we add it ordered in its category
		if not categoriesList[catID] then error("Category does not exist?!") end -- TODO
		local cIDs = categoriesList[catID].orderedContentIDs
		tinsert(cIDs, itemOrder[catID] > #cIDs and #cIDs + 1 or itemOrder[catID], itemID)
	end
end

-- category

function dataManager:CreateCategory(catName, tabID, parentCatID)
	-- creates the formatted category table with the given arguments,
	-- this table will then be sent to AddCategory who will properly
	-- add the category and its dependencies to the saved variables

	-- when creating a new category, there can only be one parent (if any),
	-- we can add others later

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
	local exists, _, _, _, itemsList, categoriesList, tabsList = dataManager:Find(next(catData.tabIDs))
	if not exists then error("Tab does not exist?!") end -- TODO

	categoriesList[catID] = catData -- adding action
	dataManager:UpdateTabsDisplay(catData.originalTabID, true, catID)
	for tabID in pairs(catData.tabIDs) do
		-- and we add it ordered in the right places
		local ordersloc = dataManager:GetCategoryOrdersLoc(catID, tabID)
		tinsert(ordersloc, catOrder[catID] > #ordersloc and #ordersloc + 1 or catOrder[catID], catID)
	end
end

-- tab

function dataManager:CreateTab(tabName, tabID, parentCatID)
	-- creates the formatted tab table with the given arguments,
	-- this table will then be sent to AddTab who will properly
	-- add the tab and its dependencies to the saved variables

	local newTab

	-- TODO

	return newTab
end

function dataManager:AddTab(tabData, tabID, tabOrder)
	-- TODO
end

-- // moving functions

-- item

function dataManager:MoveItem(itemID, newName, oldPos, newPos, oldCatID, newCatID, oldTabID, newTabID)
	local itemData = select(4, dataManager:Find(itemID))

	-- name
	if newName then
		itemData.name = newName
		return -- only a rename
	end

	-- position (order)
	if oldCatID ~= newCatID or oldPos ~= newPos then
		local oldCatData = select(4, dataManager:Find(oldCatID))
		local newCatData = select(4, dataManager:Find(newCatID))
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

function dataManager:MoveCategory(catID, newName, oldPos, newPos, oldParentID, newParentID, oldTabID, newTabID)
	local catData, itemsList, categoriesList, tabsList = select(4, dataManager:Find(catID))

	-- name
	if newName then
		catData.name = newName
		return -- only a rename
	end

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
			local tableName = select(3, dataManager:Find(contentID))
			if tableName == "categoriesList" then -- category
				dataManager:MoveCategory(contentID, nil, nil, nil, nil, nil, oldTabID, newTabID)
			else -- item
				dataManager:MoveItem(contentID, nil, nil, nil, nil, nil, oldTabID, newTabID)
			end
		end
	end

	-- TODO message?
end

-- tab

function dataManager:MoveTab(tabID, newName, oldPos, newPos, oldGlobalState, newGlobalState)
	-- TODO
end

-- // remove functions

-- item

function dataManager:DeleteItem(itemID)
	local exists, _, _, itemData, itemsList, categoriesList, tabsList = dataManager:Find(itemID)
	if not exists then error("Item does not exist?!") end -- TODO

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
end

-- category

function dataManager:DeleteCat(catID, empty)
	local exists, _, _, catData, itemsList, categoriesList, tabsList = dataManager:Find(catID)
	if not exists then error("Category does not exist?!") end -- TODO

	if dataManager:IsProtected(catID) then return end

  -- we delete the category and all its related data

	local undoData = dataManager:CreateUndo(catID)
	local nbToDelete = #catData.orderedContentIDs

	-- we delete everything inside the category, even sub-categories recursively
	for _,contentID in pairs(catData.orderedContentIDs) do
		if select(3, dataManager:Find(contentID)) == "categoriesList" then -- current ID is a sub-category
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
end

-- tab

function dataManager:DeleteTab(tabID, empty)
	local exists, _, _, tabData, itemsList, categoriesList, tabsList = dataManager:Find(tabID)
	if not exists then error("Tab does not exist?!") end -- TODO

	if dataManager:IsProtected(tabID) then return end -- TODO message "xxx is protected" ?

  -- we delete the tab and all its related data

	local undoData = dataManager:CreateUndo(catID)
	local nbToDelete = #tabData.orderedCatIDs

 	-- we delete everything inside the tab, this means every category inside of it
	for _,catID in pairs(tabData.orderedCatIDs) do
		dataManager:DeleteCat(catID)
	end

	if #tabsList.orderedCatIDs == 0 and not empty then -- we removed everything from the tab, now we delete it
		-- we remove the tab from its orders table
		tremove(tabsList.orderedTabIDs, select(2, utils:HasValue(tabsList.orderedTabIDs, tabID)))

		dataManager:AddUndo(undoData)
		nbToDelete = nbToDelete + 1
	  tabsList[tabID] = nil -- delete action
	end
	dataManager:AddUndo(nbToDelete - #tabsList.orderedCatIDs) -- to undo in one go everything that was removed
end

-- // undo feature

function dataManager:CreateUndo(ID)
	local exists, _, tableName, tableData, _, categoriesList, tabsList = dataManager:Find(ID)
	if not exists then error("Cannot create new undo: ID does not exist!") end -- TODO

	local newUndo = { -- number for clears, table for single data
    tableName = tableName,
    ID = ID,
    orders = {},
    data = tableData,
	}

	-- this is to keep the orders the removed object was if we want to undo the remove
	if tableName == "itemsList" then -- item
		for catID in pairs(tableData.catIDs) do
			newUndo.orders[catID] = select(2, utils:HasValue(categoriesList[catID].orderedContentIDs, ID))
		end
	elseif tableName == "categoriesList" then -- category
		for tabID in pairs(tableData.tabIDs) do
			local ordersLoc = dataManager:GetCategoryOrdersLoc(ID, tabID)
			newUndo.orders[tabID] = select(2, utils:HasValue(ordersLoc, ID))
		end
	elseif tableName == "tabsList" then -- tab
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
	elseif toUndo.tableName == "itemsList" then -- item
		dataManager:AddItem(toUndo.data, toUndo.ID, toUndo.orders)
	elseif toUndo.tableName == "categoriesList" then -- category
		dataManager:AddCategory(toUndo.data, toUndo.ID, toUndo.orders)
	elseif toUndo.tableName == "tabList" then -- tab
		-- TODO
	end
end

--/*******************/ ITEM CONTROL /*************************/--

function dataManager:UncheckTab(tabID)
	local itemsList = select(5, dataManager:Find(tabID))

	for itemID,itemData in pairs(itemsList) do
		if not itemData.tabIDs[tabID] then goto nextItem end
		itemData.checked = false
		::nextItem::
	end
end

function dataManager:CheckTab(tabID)
	local itemsList = select(5, dataManager:Find(tabID))

	for itemID,itemData in pairs(itemsList) do
		if not itemData.tabIDs[tabID] then goto nextItem end
		itemData.checked = true
		::nextItem::
	end
end
