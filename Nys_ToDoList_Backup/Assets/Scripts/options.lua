-- Namespace
local _, addonTable = ...

local core = addonTable.core
local options = addonTable.options
local utils = addonTable.utils

local L = core.L

--/*******************/ Options Panel /*************************/--

function options:Initialize()
	-- // Chat Command

	options.chatCommand = "/tdlb"

	SLASH_NysTDLBackup1 = options.chatCommand

	SlashCmdList.NysTDLBackup = function()
		NysTDLBackup:OpenList()
	end

	-- // Options Panel

	options.panel = CreateFrame("Frame")
	local panel = options.panel

	panel.name = core.toc.title

	-- title
	panel.titleText = panel:CreateFontString()
	panel.titleText:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -15)
	panel.titleText:SetFontObject("GameFontNormalLarge")
	panel.titleText:SetText(core.toc.title.." ("..core.toc.version..core.toc.isDev..")")

	-- open list button
	panel.openListButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	panel.openListButton:SetPoint("TOPLEFT", panel.titleText, "TOPLEFT", 5, -35)
	panel.openListButton:SetText(L["Open backup list"])
	panel.openListButton:SetWidth(panel.openListButton:GetFontString():GetWidth()+40)
	panel.openListButton:SetHeight(panel.openListButton:GetFontString():GetHeight()+12)
	panel.openListButton:SetScript("OnClick", function()
		NysTDLBackup:OpenList()
	end)

	-- open list text
	panel.openListText = panel:CreateFontString()
	panel.openListText:SetPoint("TOPLEFT", panel.openListButton, "BOTTOMLEFT", 5, -15)
	panel.openListText:SetFontObject("GameFontNormal")
	panel.openListText:SetText(utils:SafeStringFormat(L["You can also use the %s chat command"], "\""..options.chatCommand.."\""))

	if Settings and Settings.RegisterCanvasLayoutCategory then
		local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
		category.ID = panel.name
		Settings.RegisterAddOnCategory(category)
	else
		InterfaceOptions_AddCategory(panel)
	end
end
