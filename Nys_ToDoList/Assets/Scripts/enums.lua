-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local enums = addonTable.enums

-- unique enums (the value NEVER changes, but i can change the left name if i want to)

enums.item = "ENUMS_ITEM" -- item type enum
enums.category = "ENUMS_CATEGORY" -- category type enum
enums.tab = "ENUMS_TAB" -- tab type enum

enums.menus = {
  addcat = "ENUMS_MENUS_1", -- addcat menu
  frameopt = "ENUMS_MENUS_2", -- frameopt menu
  tabact = "ENUMS_MENUS_3", -- tabactions menu
}

enums.databrokerModes = {
  simple = "ENUMS_DATABROKERMODES_1", -- simple databroker mode
  advanced = "ENUMS_DATABROKERMODES_2", -- advanced databroker mode
  frame = "ENUMS_DATABROKERMODES_3", -- frame databroker mode
}

-- pure data (see those as global variables accessible by any file, but not global) -- LOCALE for string vars

enums.idtype = "string"
enums.tdlFrameDefaultWidth = 340
enums.tdlFrameDefaultHeight = 400
enums.rightPointDistance = 297

enums.loadOriginOffset = { -34, -28 }
enums.ofsxContent = 30
enums.ofsyCatContent = 26
enums.ofsyCat = 26
enums.ofsyContentCat = 26
enums.ofsyContent = 22
enums.ofsxItemIcons = -18

enums.hyperlinkNameBonus = 100
enums.maxNameWidth = {
	[enums.item] = 240,
	[enums.category] = 220,
	[enums.tab] = 150,
}

enums.maxQuantities = {
	[enums.item] = 1000,
	[enums.category] = 1000,
	[enums.tab] = 20,
}

enums.defaultResetTimeName = "Reset 1"

enums.days = {
  [2] = "Monday",
  [3] = "Tuesday",
  [4] = "Wednesday",
  [5] = "Thursday",
  [6] = "Friday",
  [7] = "Saturday",
  [1] = "Sunday",
}

-- dynamic values (accessible by all files)

enums.quantities = {
	[enums.item] = 0,
	[enums.category] = 0,
	[enums.tab] = 0,
}
