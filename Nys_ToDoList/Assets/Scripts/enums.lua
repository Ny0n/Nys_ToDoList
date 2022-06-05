-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local enums = addonTable.enums
local L = addonTable.core.L

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

enums.mainTabs = {
  all = "All",
  daily = "Daily",
  weekly = "Weekly",
}

-- pure data (see those as global variables accessible by any file, but not global)

enums.idtype = "string"
enums.tdlFrameDefaultWidth = 340
enums.tdlFrameDefaultHeight = 400
enums.rightPointDistance = 297
enums.tutoFramesRightSpace = 28

enums.loadOriginOffset = { -34, -28 }
enums.ofsxContent = 30
enums.ofsyCatContent = 26
enums.ofsyCat = 26
enums.ofsyContentCat = 26
enums.ofsyContent = 22
enums.ofsxItemIcons = -18

enums.hyperlinkNameBonus = 65
enums.maxNameWidth = {
	[enums.item] = 240,
	[enums.category] = 220,
	[enums.tab] = 150,
}

enums.maxDescriptionCharCount = 10000
enums.maxQuantities = {
	[enums.item] = 1000,
	[enums.category] = 1000,
	[enums.tab] = 20,
}

enums.translationErrMsg = "Translation error"

enums.defaultResetTimeName = L["Reset"].." 1"

enums.days = {
  [2] = L["Monday"],
  [3] = L["Tuesday"],
  [4] = L["Wednesday"],
  [5] = L["Thursday"],
  [6] = L["Friday"],
  [7] = L["Saturday"],
  [1] = L["Sunday"],
}

-- dynamic values (still, accessible by all files)

enums.quantities = {
	[enums.item] = 0,
	[enums.category] = 0,
	[enums.tab] = 0,
}
