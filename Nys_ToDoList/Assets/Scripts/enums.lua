--/*******************/ IMPORTS /*************************/--

-- File init

local enums = NysTDL.enums
NysTDL.enums = enums

-- Primary aliases

local libs = NysTDL.libs
local core = NysTDL.core
local utils = NysTDL.utils

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
	frameopt = "ENUMS_MENUS_2", -- frameopt menu UNUSED
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

enums.ofsxItemIcons = 20

enums.ofsxContent = 17
enums.ofsyCatContent = 10
enums.ofsyCat = 5
enums.ofsyContentCat = 10
enums.ofsyContent = 6
enums.ofsyContentContent = 15

---@class enums.rlFrameType
enums.rlFrameType = { -- helper
	empty = 0,
	label = 1,
	item = 2,
	category = 3,
	addEditBox = 4,
}

enums.maxWordWrapLines = 3
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

enums.interfaceNumber = tonumber((select(4, GetBuildInfo())))

enums.artPath = "Interface\\AddOns\\"..core.addonName.."\\Assets\\Art\\"
enums.icons = {
	global = {
		info = function() return enums.artPath.."UIMicroMenu2x", 14.5, 15 end,
		texCoords = { 0.328, 0.436, 0.015, 0.074 },
	},
	profile = {
		info = function() return enums.artPath.."UIMicroMenu2x", 14.5, 16.5 end,
		texCoords = { 0.328, 0.444, 0.432, 0.502 },
	},
	divider = {
		info = function() return enums.artPath.."Options", 200, 2 end,
		texCoords = { 0.000976562, 0.616211, 0.749023, 0.75 },
	},
	add = {
		info = function() return enums.artPath.."UIMinimap", 17, 17 end,
		texCoords = { 0.00390625, 0.0703125, 0.548828, 0.582031 },
		texHyperlinkTuto = "|T"..enums.artPath.."UIMinimap:18:18:1:-4:256:512:0:18:280:298|t", -- |TtexturePath:width(px):Height(px):offsetX(px):offsetY(px):textureFileWidth(px):textureFileHeight(px):texCoordsStartX(px):texCoordsEndX(px):texCoordsStartY(px):texCoordsEndY(px)|t
		texHyperlinkChat = "|T"..enums.artPath.."UIMinimap:18:18:1:0:256:512:0:18:280:298|t",
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
	view = {
		info = function() return enums.artPath.."UIEditorIcons" end,
	},
}

-- addon common backdrop template
table.insert(core.Event_OnInitialize_Start, function() -- wait for oninitialize so that we have access to utils
	enums.backdropBorderColor = { 140, 140, 140 }
	enums.backdrop = {
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false, tileSize = 1, edgeSize = 14,
		insets = { left = 2, right = 2, top = 2, bottom = 2 }
	}

	if utils:IsDF() then
		enums.backdropColor = { 55, 53, 48 } -- more grey-ish
	else
		enums.backdropColor = { 0, 0, 0 }
	end
end)

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
	total = function()
		return enums.quantities[false][enums.item]
			+ enums.quantities[false][enums.category]
			+ enums.quantities[false][enums.tab]
			+ enums.quantities[true][enums.item]
			+ enums.quantities[true][enums.category]
			+ enums.quantities[true][enums.tab]
	end
}
