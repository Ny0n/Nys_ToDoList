-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local chat = addonTable.chat
local utils = addonTable.utils
local widgets = addonTable.widgets
local database = addonTable.database
local autoReset = addonTable.autoReset
local itemsFrame = addonTable.itemsFrame
local dataManager = addonTable.dataManager
local optionsManager = addonTable.optionsManager
local tutorialsManager = addonTable.tutorialsManager

-- Variables
local L = core.L

--/*******************/ DATA MANAGMENT /*************************/--

-- id func
function dataManager:newID()
	local newID = NysTDL.db.global.nextID
	NysTDL.db.global.nextID = NysTDL.db.global.nextID + 1
	return newID
end

-- misc functions

local wipe = wipe
local insert = table.insert
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
			insert(T_Find.tablesToReturn, NysTDL.db[loc][table])
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

-- adding functions

function dataManager:CreateItem(itemName, tabID, catID)
	-- creates the formatted item table with the given arguments,
	-- this table will then be sent to AddItem who will properly
	-- add the item and its dependencies to the saved variables

	local newItem = { -- itemData
    name = itemName,
    tabIDs = {
      [tabID] = true,
    },
    catIDs = { -- for convenience when deleting items, so that we can remove them from their respective categories easily
      [catID] = true,
    },
    -- item data
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
	if not exists then error("Tab does not exists?!") end -- TODO

	itemsList[itemID] = itemData -- adding action
	for catID in pairs(itemData.catIDs) do
		-- we add it ordered in its category
		local cIDs = categoriesList[catID].orderedContentIDs
		table.insert(cIDs, itemOrder[catID] > #cIDs and #cIDs + 1 or itemOrder[catID], itemID)
	end
end

-- remove functions

function dataManager:DeleteItem(itemID)
  local itemData = NysTDL.db.profile.itemsList[itemID]
  local catData = NysTDL.db.profile.categoriesList[itemData.catID]
  local tabData = NysTDL.db.profile.tabsList[itemData.tabID]

  -- we delete the item and all its related data
  catData.itemIDs[itemID] = nil
  tabData.itemIDs[itemID] = nil
  NysTDL.db.profile.itemsList[itemID] = nil
end -- TODO

function dataManager:CheckForCatDeletion(catID)
  local catData = NysTDL.db.profile.categoriesList[catID]

  if not next(catData.itemIDs) and not next(catData.childCatIDs) then
    -- we delete the category and all its related data
    if catData.parentCatID then
      local parentCatData = NysTDL.db.profile.categoriesList[catData.parentCatID]
      parentCatData.childCatIDs[catID] = nil
      dataManager:CheckForCatDeletion(catData.parentCatID)
    end
    NysTDL.db.profile.categoriesList[catID] = nil
  end
end -- TODO

function dataManager:DeleteTab(tabID)
  local tabData = NysTDL.db.profile.tabsList[tabID]
end -- TODO

-- undo feature

function dataManager:AddUndo(ID, isNumber)
	if isNumber then table.insert(NysTDL.db.profile.undoTable, ID) return end

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
	elseif tableName == "categoriesList" and tableData.parentCatID then -- sub-category
		newUndo.orders[tableData.parentCatID] = select(2, utils:HasValue(categoriesList[tableData.parentCatID].orderedContentIDs, ID))
	elseif tableName == "categoriesList" then -- category
		for tabID in pairs(tableData.tabIDs) do
			newUndo.orders[tabID] = select(2, utils:HasValue(tabsList[tabID].orderedCatIDs, ID))
		end
	elseif tableName == "tabsList" then -- tab
		newUndo.orders = select(2, utils:HasValue(tabsList.orderedTabIDs, ID))
	end

	table.insert(NysTDL.db.profile.undoTable, newUndo)
end

function dataManager:Undo()
	-- when undoing, there are 4 possible cases:
	-- undoing a clear, an item deletion, a category deletion, or a tab deletion

	if #NysTDL.db.profile.undoTable == 0 then
		-- TODO print "no undos"
		return
	end

	local toUndo = table.remove(NysTDL.db.profile.undoTable) -- remove last
	if type(toUndo) == "number" then -- clear
		for i=1, toUndo do dataManager:Undo() end
	elseif toUndo.tableName == "itemsList" then -- item
		dataManager:AddItem(toUndo.data, toUndo.ID, toUndo.orders)
	elseif toUndo.tableName == "categoriesList" then -- item

	elseif toUndo.tableName == "tabList" then -- item

	end
end
