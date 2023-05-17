-- Namespace
local _, addonTable = ...

local core = addonTable.core
local options = addonTable.options

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
	panel.titleText:SetText(core.toc.title.." ("..core.toc.version..")")

	-- open list button
	panel.openListButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	panel.openListButton:SetPoint("TOPLEFT", panel.titleText, "TOPLEFT", 5, -35)
	panel.openListButton:SetText("Open backup list")
	panel.openListButton:SetWidth(panel.openListButton:GetFontString():GetWidth()+40)
	panel.openListButton:SetHeight(panel.openListButton:GetFontString():GetHeight()+12)
	panel.openListButton:SetScript("OnClick", function()
		NysTDLBackup:OpenList()
	end)

	-- open list text
	panel.openListText = panel:CreateFontString()
	panel.openListText:SetPoint("TOPLEFT", panel.openListButton, "BOTTOMLEFT", 5, -15)
	panel.openListText:SetFontObject("GameFontNormal")
	panel.openListText:SetText("You can also use the \""..options.chatCommand.."\" chat command")

	InterfaceOptions_AddCategory(panel)
end
