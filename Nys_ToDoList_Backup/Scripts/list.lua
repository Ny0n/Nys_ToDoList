-- Namespace
local _, addonTable = ...

local data = addonTable.data
local list = addonTable.list

--/*******************/ Functions /*************************/--

function NysTDLBackup:ToggleList()
	if not list.frame then
		print("Backup list not initialized")
		return
	end

	list.frame:SetShown(not list.frame:IsShown())
end

---List generation
---@param backupType backupType
---@return FontString
function list:BackupCategoryLabel(backupType)
	local name = nil
	if backupType == data.backupType.autoDaily then
		name = "Automatic (Daily)"
	elseif backupType == data.backupType.autoWeekly then
		name = "Automatic (Weekly)"
	elseif backupType == data.backupType.autoPreImport then
		name = "Automatic (Before Import)"
	elseif backupType == data.backupType.autoPreApplyBackup then
		name = "Before last backup"
	elseif backupType == data.backupType.manual then
		name = "Manual"
	end

	-- // UI & actions

	local listWidget = list.frame:CreateFontString(nil)
	listWidget:SetFontObject("GameFontNormalSmall")
	listWidget:SetText(name)
	listWidget:SetSize(list.frame:GetWidth()-12, 12)
	listWidget:SetWordWrap(false)

	return listWidget
end

function list:BackupButton(backupType)
	local listButtonWidget = CreateFrame("Button", nil, list.frame, "NysTDLBackup_ListButton")

	-- // data

	-- listButtonWidget.backup = data:GetBackup(backupID)
	-- TDSEC

	-- // UI & actions

	-- local backup = listButtonWidget.backup

	listButtonWidget:SetText(tostring(backupType))
	listButtonWidget:SetSize(list.frame:GetWidth()-12, 12)
	listButtonWidget:SetScript("OnClick", function()
		print(tostring(backupType))
	end)

	listButtonWidget:Show()

	return listButtonWidget
end

function list:CreateBackupFrame()
	list.frame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	local frame = list.frame

	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false, tileSize = 1, edgeSize = 14,
		insets = { left = 2, right = 2, top = 2, bottom = 2 }
	})
	frame:SetBackdropColor(0, 0, 0, 0.75)
	frame:SetBackdropBorderColor(140, 140, 140, 0.75)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetSize(150, 1) -- the height is updated dynamically
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)

	frame.content = CreateFrame("Frame", nil, frame)
	frame.content:SetPoint("TOPLEFT", frame, "TOPLEFT")
	frame.content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
	local content = frame.content

	content.title = content:CreateFontString(nil)
	content.title:SetPoint("TOP", content, "TOP", 0, -5)
	content.title:SetFontObject("GameFontHighlight")
	content.title:SetText("Backup list")

	-- creating the fixed spots
	local lastWidget = nil

	local ordered = tInvert(data.backupType) -- TDSEC
	for _, backupTypeName in ipairs(ordered) do
		local backupType = data.backupType[backupTypeName]

		local cat = list:BackupCategoryLabel(backupType)

		if not lastWidget then
			cat:SetPoint("TOP", content.title, "BOTTOM", 0, -5)
		else
			cat:SetPoint("TOP", lastWidget, "BOTTOM", 0, -2)
		end

		lastWidget = cat

		if (data.backupCount[backupType] or 0) > 0 then
			for i=1, data.backupCount[backupType] do
				local button = list:BackupButton(backupType)
				button:SetPoint("TOP", lastWidget, "BOTTOM", 0, -2)
				lastWidget = button
			end
		else
			local empty = content:CreateFontString(nil)
			empty:SetFontObject("GameFontHighlightSmall")
			empty:SetText("Empty")
			empty:SetPoint("TOP", lastWidget, "BOTTOM", 0, -2)
			lastWidget = empty
		end
	end

	local top, bottom = frame:GetTop(), lastWidget:GetBottom()-8
	frame:SetHeight(top-bottom)

	list:Refresh()
end

function list:Refresh()

end
