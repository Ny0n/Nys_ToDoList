-- Namespace
local _, addonTable = ...

local data = addonTable.data
local list = addonTable.list

--/*******************/ Functions /*************************/--

local listButtons = {}
local lastWidget = nil
local tooltipFrame = nil

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

function list:BackupButton(backupType, backupSlot, isWriteable)
	if not backupType or not backupSlot then return end
	isWriteable = isWriteable or false

	local listButtonWidget = CreateFrame("Button", nil, list.frame, "NysTDLBackup_ListButton")
	listButtonWidget.ArrowLEFT:Hide()
	listButtonWidget.ArrowRIGHT:Hide()

	-- // UI & actions

	listButtonWidget.Refresh = function(self)
		local backup = data:ReadBackupFromSlot(backupType, backupSlot)
		if backup then
			listButtonWidget:GetFontString():SetText(backup.name)
			listButtonWidget:GetFontString():SetTextColor(1, 1, 1)
		else
			listButtonWidget:GetFontString():SetText(isWriteable and "Create new" or "Empty")
			listButtonWidget:GetFontString():SetTextColor(0.5, 0.5, 0.5)
		end

		listButtonWidget:SetHeight(listButtonWidget:GetFontString():GetHeight()+8)

		listButtonWidget:SetEnabled(not not backup or isWriteable)
		self:RefreshTooltip()
	end

	listButtonWidget:SetWidth(list.frame:GetWidth()-12)
	listButtonWidget:GetFontString():SetWidth(listButtonWidget:GetWidth()-5)
	listButtonWidget:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	listButtonWidget:SetScript("OnClick", function(self, button)
		if button == "LeftButton" then
			local hasBackup = not not data:ReadBackupFromSlot(backupType, backupSlot)
			if isWriteable and (not hasBackup or IsShiftKeyDown()) then
				data:WriteBackupToSlot(backupType, backupSlot)
			else
				data:ApplyBackupFromSlot(backupType, backupSlot)
			end
		elseif button == "RightButton" then
			if isWriteable then
				data:DeleteBackupFromSlot(backupType, backupSlot)
			end
		end
	end)

	listButtonWidget.RefreshTooltip = function(self)
		-- pcall(function()
			if tooltipFrame:GetOwner() == self then
				tooltipFrame:ClearLines()

				local hasBackup = not not data:ReadBackupFromSlot(backupType, backupSlot)

				if not hasBackup and isWriteable then
					tooltipFrame:AddLine("Left-Click - Create new", 1, 1, 1)
				end

				if hasBackup then
					tooltipFrame:AddLine("Left-Click - Apply", 1, 1, 1)
					if isWriteable then
						tooltipFrame:AddLine("Shift-Click - Overwrite", 1, 1, 1)
						tooltipFrame:AddLine("Right-Click - Delete", 1, 1, 1)
					end
				end

				tooltipFrame:Show()
			end
		-- end)
	end

	listButtonWidget:HookScript("OnEnter", function(self)
		-- pcall(function() -- TDSEC
			tooltipFrame:SetOwner(self, "ANCHOR_TOPLEFT")
			self:RefreshTooltip()
		-- end)
	end)
	listButtonWidget:HookScript("OnLeave", function(self)
		-- pcall(function()
			tooltipFrame:Hide()
		-- end)
	end)

	listButtonWidget:Refresh()

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
	frame:SetSize(200, 1) -- the height is updated dynamically
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

	-- tooltip
	-- pcall(function()
		tooltipFrame = CreateFrame("GameTooltip", "NysTDLBackup_tooltipFrame", UIParent, "GameTooltipTemplate")
		tooltipFrame:Hide()
		tooltipFrame.TextLeft1:SetFontObject("GameTooltipText") -- header
		tooltipFrame.TextRight1:SetFontObject("GameTooltipText") -- header
	-- end)

	-- creating the fixed spots

	-- display order
	local ordered = {
		data.backupType.autoDaily,
		data.backupType.autoWeekly,
		data.backupType.autoPreImport,
		data.backupType.autoPreApplyBackup,
		data.backupType.manual
	}

	for _, backupType in ipairs(ordered) do
		local cat = list:BackupCategoryLabel(backupType)

		if not lastWidget then
			cat:SetPoint("TOP", content.title, "BOTTOM", 0, -5)
		else
			cat:SetPoint("TOP", lastWidget, "BOTTOM", 0, -2)
		end

		lastWidget = cat

		if (data.backupCount[backupType] or 0) > 0 then
			for i=1, data.backupCount[backupType] do
				local button = list:BackupButton(backupType, i, backupType == data.backupType.manual)
				button:SetPoint("TOP", lastWidget, "BOTTOM", 0, -2)
				table.insert(listButtons, button)
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

	list:Refresh()
end

function list:Refresh()
	for _,button in pairs(listButtons) do
		button:Refresh()
	end

	local top, bottom = list.frame:GetTop(), lastWidget:GetBottom()-8
	list.frame:SetHeight(top-bottom)
end
