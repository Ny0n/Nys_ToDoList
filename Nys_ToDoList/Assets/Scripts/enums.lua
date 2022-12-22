--/*******************/ IMPORTS /*************************/--

-- File init

local enums = NysTDL.enums
NysTDL.enums = enums

-- Primary aliases

local libs = NysTDL.libs
local core = NysTDL.core

-- Secondary aliases

local L = libs.L

--/*******************************************************/--

-- unique enums (the value NEVER changes, but I can change the left name if I want to)

---@alias enumObject enums.item | enums.category | enums.tab

---@class enums.item
enums.item = "ENUMS_ITEM"

---@class enums.category
enums.category = "ENUMS_CATEGORY"

---@class enums.tab
enums.tab = "ENUMS_TAB"

---@class enums.menus
enums.menus = {
	addcat = "ENUMS_MENUS_1", -- addcat menu
	frameopt = "ENUMS_MENUS_2", -- frameopt menu
	tabact = "ENUMS_MENUS_3", -- tabactions menu
}

---@class enums.databrokerModes
enums.databrokerModes = {
	simple = "ENUMS_DATABROKERMODES_1", -- simple databroker mode
	advanced = "ENUMS_DATABROKERMODES_2", -- advanced databroker mode
	frame = "ENUMS_DATABROKERMODES_3", -- frame databroker mode
}

---@class enums.mainTabs
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

enums.loadOriginOffset = { -32, -28 }
enums.ofsxContent = 30
enums.ofsyCatContent = 27
enums.ofsyCat = 26
enums.ofsyContentCat = 27
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
	[false] = { -- profile
		[enums.item] = 1000,
		[enums.category] = 1000,
		[enums.tab] = 20,
	},
	[true] = { -- global
		[enums.item] = 1000,
		[enums.category] = 1000,
		[enums.tab] = 20,
	},
}

enums.translationErrMsg = "|cffffff00".."Translation error".."|r".." ".."|cffffcc00".."("..libs.Locale..")".."|r"

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

enums.interfaceNumber = tonumber(select(4, GetBuildInfo()))

enums.artPath = "Interface\\AddOns\\"..core.addonName.."\\Assets\\Art\\"
enums.icons = {
	global = {
		info = function() return enums.artPath.."UIMicroMenu2x", 14.5, 15 end,
		texCoords = { 0.328, 0.436, 0.015, 0.074 },
	},
	profile = {
		info = function() return enums.artPath.."UIMicroMenu2x", 14, 18 end,
		texCoords = { 0.328, 0.438, 0.43, 0.502 },
	},
	minimap = {
		info = function() return enums.artPath.."70_professions_scroll_03" end,
	},
	dropLine = {
		info = function() return enums.artPath.."CovenantChoiceCelebration" end,
	},
	dropArrow = {
		info = function() return enums.artPath.."Azerite" end,
	},
}

-- dynamic values (still, accessible by all files)

enums.quantities = {
	[false] = { -- profile
		[enums.item] = 0,
		[enums.category] = 0,
		[enums.tab] = 0,
	},
	[true] = { -- global
		[enums.item] = 0,
		[enums.category] = 0,
		[enums.tab] = 0,
	},
}
