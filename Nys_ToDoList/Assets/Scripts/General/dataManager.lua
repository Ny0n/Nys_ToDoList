-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local enums = addonTable.enums
local utils = addonTable.utils
local widgets = addonTable.widgets
local database = addonTable.database
local dataManager = addonTable.dataManager
local resetManager = addonTable.resetManager
local optionsManager = addonTable.optionsManager

-- the access to mainFrame is controlled:
-- this file can only call mainFrame funcs if it is specifically authorized to do so,
-- it's to counter the fact that for some database updates
-- (var migration, profile change, default tabs creation...)
-- i have to call funcs here before the list is created

dataManager.authorized = true
local _mainFrame = addonTable.mainFrame
local dummyFunc = function()end

local mainFrame = setmetatable({}, {
	__index = function (t,k)
		if not dataManager.authorized then return dummyFunc end
    return _mainFrame[k]   -- access the original table
  end,
})

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
local random = math.random

--/*******************/ DATA MANAGMENT /*************************/--

-- id func
function dataManager:NewID()
	-- uuid
	local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
	return (select(1, string.gsub(template, '[xy]', function(c)
		local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
		return string.format('%x', v)
	end)))

	-- local newID = NysTDL.db.global.nextID
	-- NysTDL.db.global.nextID = NysTDL.db.global.nextID + 1
	-- return newID
end

function dataManager:IsID(ID)
	if type(ID) ~= enums.idtype then return end
	if not string.match(ID, '^[0-9a-f]+-[0-9a-f]+-[0-5][0-9a-f]+-[089ab][0-9a-f]+-[0-9a-f]+$') then return end
	if not pcall(dataManager.Find, dataManager, ID) then return end -- raises an error if the ID is not found

	return true
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

	error("ID not found")
end

function dataManager:IsGlobal(ID)
	return (select(2, dataManager:Find(ID)))
end

local T_GetData = {}
function dataManager:GetData(isGlobal, tableMode)
	-- returns itemsList, categoriesList, and tabsList located either in the global or profile SV
	-- as a table if asked so

	local loc = isGlobal and NysTDL.db.global or NysTDL.db.profile
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
	--[[
	* this func is used everywhere to loop through items, categories and tabs.
	this is used in a for loop like pairs():
	for itemID,itemData in dataManager:ForEach(enums.item) do
		-- body...
	end
	* every time, the loop variables are the ID and the DATA of the targeted loop thing

	* usage:
	enum 			==> either enums.item, enums.category, or enums.tab (depending on what you want to loop on)
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
		if dataManager:IsID(location) then -- specific tab ID
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
		if dataManager:IsID(location) then -- specific shown ID
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

		-- print(key, data)
		return key, data, isGlobal
	end
end

-- // adding functions

-- item

local function addItem(itemID, itemData)
	wipe(itemData.tabIDs)
	itemData.tabIDs[itemData.originalTabID] = true -- by default, an item/cat can only be added to one tab, the shown tab IDs do the rest after

	-- we get where we are
	local itemsList, categoriesList = select(4, dataManager:Find(itemData.originalTabID))

	-- we add the item to the saved variables

	itemsList[itemID] = itemData -- adding action

	-- then we update its data
	dataManager:UpdateTabsDisplay(itemData.originalTabID, true, itemID)
	for catID in pairs(itemData.catIDs) do
		-- we add it ordered in its category/categories
		local itemOrder = dataManager:GetNextFavPos(catID)
		tinsert(categoriesList[catID].orderedContentIDs, itemOrder, itemID)
	end

	-- refresh the mainFrame
	mainFrame:UpdateWidget(itemID, enums.item)
	mainFrame:Refresh()

	return itemID, itemData
end

function dataManager:CreateItem(itemName, tabID, catID)
	-- creates the formatted item table with the given arguments,
	-- this table will then be sent to AddItem who will properly
	-- add the item and its dependencies to the saved variables

	-- first, we check what needs to be checked
	if not dataManager:CheckName(itemName, enums.item) then return end

	local itemData = { -- itemData
    name = itemName,
    originalTabID = tabID,
    tabIDs = { -- we display the item in these tabs, updated later
			-- [tabID] = true,
			-- ...
		},
    catIDs = { -- for convenience when deleting items, so that we can remove them from their respective categories easily
      -- [catID] = true,
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

	itemData.catIDs[catID] = true

	return addItem(dataManager:NewID(), itemData)
end

-- category

local function addCategory(catID, catData)
	wipe(catData.tabIDs)
	catData.tabIDs[catData.originalTabID] = true -- by default, an item/cat can only be added to one tab, the shown tab IDs do the rest after

	-- we get where we are
	local categoriesList = select(5, dataManager:Find(catData.originalTabID))

	-- we add the category to the saved variables

	categoriesList[catID] = catData -- adding action

	-- then we update its data
	dataManager:UpdateTabsDisplay(catData.originalTabID, true, catID)

	-- refresh the mainFrame
	mainFrame:UpdateWidget(catID, enums.category)
	mainFrame:Refresh()

	return catID, catData
end

function dataManager:CreateCategory(catName, tabID, parentCatID)
	-- creates the formatted category table with the given arguments,
	-- this table will then be sent to AddCategory who will properly
	-- add the category and its dependencies to the saved variables

	-- when creating a new category, there can only be one parent (if any),
	-- we can add others later

	-- first, we check what needs to be checked
	if not dataManager:CheckName(catName, enums.category) then return end

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
    parentsInTabIDs = {
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

	catData.tabIDs[tabID] = true
	catData.parentsInTabIDs[tabID] = parentCatID -- nil or parentCatID

	return addCategory(dataManager:NewID(), catData)
end

-- tab

local function addTab(tabID, tabData, isGlobal)
	-- we get where we are
	local tabsList = select(3, dataManager:GetData(isGlobal))

	-- we add the tab to the saved variables

	tabsList[tabID] = tabData -- adding action

	-- then we update its data
	tabData.shownIDs[tabID] = true -- self forced
	for shownID in pairs(tabData.shownIDs) do
		dataManager:UpdateShownTabID(tabID, shownID, true)
	end
	tinsert(tabsList.orderedTabIDs, #tabsList.orderedTabIDs + 1, tabID) -- position (last) -- TODO NOW redo

	-- refresh the mainFrame
	database.ctab(tabID)
	mainFrame:Refresh()

	return tabID, tabData
end

function dataManager:CreateTab(tabName, isGlobal)
	-- creates the formatted tab table with the given arguments,
	-- this table will then be sent to AddTab who will properly
	-- add the tab and its dependencies to the saved variables

	-- first, we check what needs to be checked
	if not dataManager:CheckName(tabName, enums.tab) then return end

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
  }

	resetManager:InitTabData(tabData)

	return addTab(dataManager:NewID(), tabData, isGlobal)
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
	mainFrame:Refresh()
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
	mainFrame:Refresh()
end

-- tab

function dataManager:MoveTab(tabID, oldPos, newPos, oldGlobalState, newGlobalState)
	-- TODO

	mainFrame:Refresh()
end

-- // remove functions

-- item

function dataManager:DeleteItem(itemID)
	if dataManager:IsProtected(itemID) then return end

	local itemData, itemsList, categoriesList = select(3, dataManager:Find(itemID))

  -- we delete the item and all its related data

	local undoData = dataManager:CreateUndo(itemID) -- XXX i wipe in add func the tabIDs so i can put the undo before it doesn't matter

	-- we update its data (pretty much the reverse actions of the Add func)
	dataManager:UpdateTabsDisplay(itemData.originalTabID, false, itemID)
	for catID in pairs(itemData.catIDs) do
		local cIDs = categoriesList[catID].orderedContentIDs
  	tremove(cIDs, select(2, utils:HasValue(cIDs, itemID)))
	end

	dataManager:AddUndo(undoData)
  itemsList[itemID] = nil -- delete action

	-- we hide a potentially opened desc frame
	widgets:DescFrameHide(itemID)

	-- refresh the mainFrame
	mainFrame:DeleteWidget(itemID)
	mainFrame:Refresh()

	return true
end

-- category

function dataManager:DeleteCat(catID)
	if dataManager:IsProtected(catID) then return end
	print("delete")

	local catData, _, categoriesList = select(3, dataManager:Find(catID))

  -- we delete the category and all its related data

	-- we delete everything inside the category, even sub-categories recursively
	local nbToDelete, key, contentID = #catData.orderedContentIDs
	for i=1,nbToDelete do -- not pairs bc im deleting things in the same table i would be looping on
		key, contentID = next(catData.orderedContentIDs, key) -- so i just use next
		if not dataManager:IsProtected(contentID) then -- if the thing we're about to delete is not protected (pre-check so that i can call DontRefreshNextTime not for nothing)
			mainFrame:DontRefreshNextTime()
			if dataManager:Find(contentID) == enums.category then -- current ID is a sub-category
				dataManager:DeleteCat(contentID)
			else -- current ID is an item
				dataManager:DeleteItem(contentID)
			end
		end
	end

	local undoData, result = dataManager:CreateUndo(catID)

	if #catData.orderedContentIDs == 0 then -- we removed everything from the cat, now we delete it
		-- we update its data (pretty much the reverse actions of the Add func)
		dataManager:UpdateTabsDisplay(catData.originalTabID, false, catID)

		dataManager:AddUndo(undoData)
		nbToDelete = nbToDelete + 1
	  categoriesList[catID] = nil -- delete action

		mainFrame:DeleteWidget(catID)
		result = true
	end

	dataManager:AddUndo(nbToDelete - #catData.orderedContentIDs) -- to undo in one go everything that was removed

	-- refresh the mainFrame
	mainFrame:Refresh()

	return result
end

-- tab

function dataManager:DeleteTab(tabID)
	if dataManager:IsProtected(tabID) then return end

	local tabData, _, categoriesList, tabsList = select(3, dataManager:Find(tabID))

  -- we delete the tab and all its related data

 	-- we delete everything inside the tab, this means every category inside of it
	local nbToDelete, key, catID = #tabData.orderedCatIDs
	for i=1,nbToDelete do
		key, catID = next(tabData.orderedCatIDs, key)
		if categoriesList[catID].originalTabID == tabID then --  (SPECIFIC: a tab deletion only deletes what's original to the tab, not everything that's shown inside of it)
			if not dataManager:IsProtected(catID) then -- if the thing we're about to delete is not protected (pre-check so that i can call DontRefreshNextTime not for nothing)
				mainFrame:DontRefreshNextTime()
				dataManager:DeleteCat(catID)
			end
		end
	end

	local undoData, result = dataManager:CreateUndo(tabID)

	if #tabData.orderedCatIDs == 0 then -- we removed everything from the tab, now we delete it
		-- we update its data (pretty much the reverse actions of the Add func)
		for shownTabID in pairs(tabData.shownIDs) do
			if shownTabID ~= tabID then
				mainFrame:DontRefreshNextTime()
				dataManager:UpdateShownTabID(tabID, shownTabID, false)
			end
		end
		local tabPos = select(2, utils:HasValue(tabsList.orderedTabIDs, tabID))
		tremove(tabsList.orderedTabIDs, tabPos)

		dataManager:AddUndo(undoData)
		nbToDelete = nbToDelete + 1

	  tabsList[tabID] = nil -- delete action

		database.ctab(tabsList.orderedTabIDs[tabPos-1]) -- when deleting a tab, we refocus a new tab (by default, the previous one)
		result = true
	end

	dataManager:AddUndo(nbToDelete - #tabData.orderedCatIDs) -- to undo in one go everything that was removed

	-- refresh the mainFrame
	mainFrame:Refresh()

	return result
end

-- // undo feature

function dataManager:CreateUndo(ID)
	local enum, isGlobal, tableData, _, categoriesList, tabsList = dataManager:Find(ID)

	local newUndo = { -- number for clears, table for single data
    enum = enum, -- what are we saving to undo?
    ID = ID, -- ID
    data = utils:Deepcopy(tableData), -- data
		isGlobal = isGlobal, -- used exclusively for tabs
	}

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
	print("UNDO")
	if #NysTDL.db.profile.undoTable == 0 then
		-- TODO print "no undos"
		return
	end

	local toUndo = tremove(NysTDL.db.profile.undoTable) -- remove last
	if type(toUndo) == "number" then -- clear
		if toUndo <= 0 then toUndo = 1 end -- when we find a "0", we pass it like it was never here, and directly go undo the next item
		for i=1, toUndo do
			mainFrame:DontRefreshNextTime()
			dataManager:Undo()
		end
		mainFrame:Refresh()
		-- TODO messages "undo clear" and others
	elseif toUndo.enum == enums.item then -- item
		addItem(toUndo.ID, toUndo.data)
		print("undid item")
	elseif toUndo.enum == enums.category then -- category
		addCategory(toUndo.ID, toUndo.data)
		print("undid cat")
	elseif toUndo.enum == enums.tab then -- tab
		addTab(toUndo.ID, toUndo.data, toUndo.isGlobal)
		print("undid tab")
	end
end

--/*******************/ DATA CONTROL /*************************/--

-- misc

local function updateCatShownTabID(catID, catData, tabID, tabData, shownTabID, modif)
	if catData.originalTabID == shownTabID then -- important
		catData.tabIDs[tabID] = modif
		if not catData.parentsInTabIDs[catData.originalTabID] then -- if it's not a sub-category, we edit it in its tab orders
			if modif and not utils:HasValue(tabData.orderedCatIDs, catID) then
				-- we add it ordered in the tab if it wasn't here already
				tinsert(tabData.orderedCatIDs, 1, catID) -- TODO later, IF i do cat fav it's not pos 1
			elseif not modif then
				tremove(tabData.orderedCatIDs, select(2, utils:HasValue(tabData.orderedCatIDs, catID)))
			end
		end
	end
end

local function updateItemShownTabID(itemID, itemData, tabID, tabData, shownTabID, modif)
	if itemData.originalTabID == shownTabID then -- important
		itemData.tabIDs[tabID] = modif
	end
end

function dataManager:UpdateTabsDisplay(shownTabID, modif, ID)
	-- // big important func to update what is shown in what tab

	-- both shownTabID and ID are the same global or profile state
	-- modif means adding/removing, modif = true --> adding, modif = false/nil --> removing
	-- ID is for only updating one specific ID (itemID.tabIDs or catID.tabIDs), instead of going through everything
	if modif == false then modif = nil end
	local enum, isGlobal, data, itemsList, categoriesList = dataManager:Find(ID or shownTabID)

	for tabID,tabData in dataManager:ForEach(enums.tab, shownTabID) do -- for every tab that is showing the originalTabID
		-- we go through every category and every item, and for each that have
		-- the original tab equal to shownTabID, we add/remove the current tab to their tabIDs

		if ID then -- if it concerns only one ID
			if enum == enums.category then -- single category
				updateCatShownTabID(ID, data, tabID, tabData, shownTabID, modif)
			elseif enum == enums.item then -- single item
				updateItemShownTabID(ID, data, tabID, tabData, shownTabID, modif)
			end
		else -- if it concerns everything
			-- categories
			for catID,catData in dataManager:ForEach(enums.category, isGlobal) do
				updateCatShownTabID(catID, catData, tabID, tabData, shownTabID, modif)
			end
			-- items
			for itemID,itemData in dataManager:ForEach(enums.item, isGlobal) do
				updateItemShownTabID(itemID, itemData, tabID, tabData, shownTabID, modif)
			end
		end
	end
end

function dataManager:CheckName(name, enum)
	if #name == 0 then -- empty
		print("Name is empty")
		-- TODO message
		return false
	elseif widgets:GetWidth(name) > maxNameWidth[enum] then -- width
		print("Name is too large")
		-- TODO redo this? if it has an hyperlink in it and it's too big, we allow it to be a little longer, considering hyperlinks take more place
		-- if l:GetWidth() > itemNameWidthMax and utils:HasHyperlink(newItemName) then
		-- 	l:SetFontObject("GameFontNormal")
		-- end
		-- TODO message
		return false
	end

	return true
end

function dataManager:Rename(ID, newName)
	local enum, _, dataTable = dataManager:Find(ID)

	if not dataManager:CheckName(newName, enum) then return end

	dataTable.name = newName

	-- refresh the mainFrame
	mainFrame:UpdateWidget(ID, enum)
	mainFrame:Refresh()

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

	-- TODO message "xxx is protected" ?
end

function dataManager:GetNextFavPos(catID)
	-- TODO sub-cat ?
	return dataManager:GetRemainingNumbers(nil, nil, catID).totalFav + 1
end

function dataManager:GetPos(ID)
	local enum, _, data, _, categoriesList, tabsList = dataManager:Find(ID)

	if enum == enums.item then
		local catID = next(data.catIDs)
		local catData = select(3, dataManager:Find(catID))
		return select(2, utils:HasValue(catData.orderedContentIDs, ID))
	elseif enum == enums.category then
		return select(2, utils:HasValue(dataManager:GetCategoryOrdersLoc(ID, database.ctab()), ID))
	end
end

-- items

function dataManager:ToggleChecked(itemID)
	local itemData = select(3, dataManager:Find(itemID))
	itemData.checked = not itemData.checked

	-- refresh the mainFrame
	if NysTDL.db.profile.instantRefresh then -- TODO redo?
		mainFrame:Refresh()
	else
		mainFrame:UpdateVisuals()
	end

	return itemData.checked
end

function dataManager:ToggleFavorite(itemID)
	local itemData = select(3, dataManager:Find(itemID))
	itemData.favorite = not itemData.favorite

	-- we change the sort order of the item
	if itemData.favorite then -- if we passed it from non-fav to fav
		for catID in pairs(itemData.catIDs) do
			local catData = select(3, dataManager:Find(catID))
			tremove(catData.orderedContentIDs, select(2, utils:HasValue(catData.orderedContentIDs, itemID)))
			tinsert(catData.orderedContentIDs, 1, itemID)
			-- dataManager:MoveItem(itemID, select(2, utils:HasValue(catData.orderedContentIDs, itemID)), 1) -- OPTIMIZE MoveItem & MoveCategory
		end
	else -- if we passed it from fav to non-fav
		for catID in pairs(itemData.catIDs) do
			local catData = select(3, dataManager:Find(catID))
			tremove(catData.orderedContentIDs, select(2, utils:HasValue(catData.orderedContentIDs, itemID)))
			tinsert(catData.orderedContentIDs, dataManager:GetNextFavPos(catID), itemID)
			-- dataManager:MoveItem(itemID, select(2, utils:HasValue(catData.orderedContentIDs, itemID)), dataManager:GetNextFavPos(catID)) -- OPTIMIZE MoveItem & MoveCategory
		end
	end

	-- refresh the mainFrame
	mainFrame:UpdateItemButtons(itemID)
	mainFrame:Refresh()

	return itemData.favorite
end

function dataManager:UpdateDescription(itemID, description)
	local itemData = select(3, dataManager:Find(itemID))
	if description == "" then description = false end
	itemData.description = description

	-- refresh the mainFrame
	mainFrame:UpdateItemButtons(itemID)

	return itemData.description
end

-- categories

function dataManager:GetCategoryOrdersLoc(catID, tabID)
	-- since categories are either located in an other category (as a sub-category) or in a tab,
	-- this is to easily get the good orders table where a category is in a certain tab
	local catData, _, categoriesList, tabsList = select(3, dataManager:Find(catID))
	local parentCatID = catData.parentsInTabIDs[tabID] -- nil or parentCatID
	return parentCatID and categoriesList[parentCatID].orderedContentIDs or tabsList[tabID].orderedCatIDs
end

function dataManager:GetNbCategory(tabID)
	return #select(3, dataManager:Find(tabID)).orderedCatIDs -- TODO redo with GetCategoryOrdersLoc
end

function dataManager:ToggleClosed(catID, tabID, state)
	-- state can be:
	-- 	nil -> toggle
	-- 	false -> close
	-- 	true -> open

	dataManager:Find(tabID) -- raises an error if the ID is not valid
	local catData = select(3, dataManager:Find(catID))
	if state == nil then
		catData.closedInTabIDs[tabID] = not catData.closedInTabIDs[tabID] or nil
	elseif state == false then
		catData.closedInTabIDs[tabID] = true
	elseif state == true then
		catData.closedInTabIDs[tabID] = nil
	end
end

-- tabs

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

	-- refresh the mainFrame
	mainFrame:Refresh()
end

function dataManager:UncheckTab(tabID)
	for itemID,itemData in dataManager:ForEach(enums.item, tabID) do
		itemData.checked = false
	end

	-- refresh the mainFrame
	mainFrame:UpdateVisuals()
end

function dataManager:CheckTab(tabID)
	for itemID,itemData in dataManager:ForEach(enums.item, tabID) do
		itemData.checked = true
	end

	-- refresh the mainFrame
	mainFrame:Refresh()
end

function dataManager:ClearTab(tabID)
	local removed = 0
	for catID,catData in dataManager:ForEach(enums.category, tabID) do
		if not dataManager:IsProtected(catID) then
			mainFrame:DontRefreshNextTime()
			if dataManager:DeleteCat(catID) then
				removed = removed + 1
			end
		end
	end
	dataManager:AddUndo(removed)

	-- refresh the mainFrame
	mainFrame:Refresh()
end

function dataManager:DoIfFoundTabMatch(maxTime, checkedType, callback, doAll)
	-- // loops over every tab, and calls one (doAll=false/nil) or for all matching tabs (doAll=true) time the callback,
	-- if the next requirements are met:
	-- - the tab has resets
	-- - one of its resets are scheduled before maxTime
	-- - it has more than one checkedType item inside of it

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

function dataManager:IsHidden(itemID, tabID)
	local itemData = select(3, dataManager:Find(itemID))
	local tabData = select(3, dataManager:Find(tabID))
	return tabData.hideCheckedItems and itemData.checked
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
	for itemID,itemData in dataManager:ForEach(enums.item, location) do -- for each item that is in the cat
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
