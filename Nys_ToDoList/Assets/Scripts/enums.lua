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

-- pure data (see those as global variables accessible by any file, but not global)

enums.idtype = "string"
enums.tdlFrameDefaultWidth = 340
enums.tdlFrameDefaultHeight = 400

enums.ofsxContent = 12
enums.ofsyCatContent = 26
enums.ofsyCat = 26
enums.ofsyContentCat = 28
enums.ofsyContent = 24
