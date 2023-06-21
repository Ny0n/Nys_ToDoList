-- Namespace
local _, addonTable = ...

local core = addonTable.core
local data = addonTable.data
local list = addonTable.list

local L = core.L

--/*******************/ Variables /*************************/--

local listButtons = {}
local lastWidget = nil
local tooltipFrame = nil

--/*******************/ Functions /*************************/--

function NysTDLBackup:OpenList()
	if not list.frame then
		print("Backup list not initialized")
		return
	end

	list.frame:Show()
end

---@return FontString
function list:BackupCategoryLabel(backupType)
	local listWidget = list.frame:CreateFontString(nil)

	listWidget:SetFontObject("GameFontNormalSmall")
	listWidget:SetText(data.backupTypesDisplayNames[backupType])
	listWidget:SetWidth(list.frame:GetWidth()-40)
	listWidget:SetWordWrap(true)

	return listWidget
end

---@return Button
function list:BackupButton(backupType, backupSlot, isWriteable)
	if not backupType or not backupSlot then return end
	isWriteable = isWriteable or false

	local listButtonWidget = CreateFrame("Button", nil, list.frame)
	listButtonWidget:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	listButtonWidget:SetFontString(listButtonWidget:CreateFontString())
	listButtonWidget:SetNormalFontObject("GameFontNormalSmall")

	-- // UI & actions

	listButtonWidget.Refresh = function(self)
		local backupTable = data:GetValidBackup(data:GetCurrentProfile(), backupType, backupSlot)
		if backupTable then
			listButtonWidget:GetFontString():SetText(data:GetBackupDisplayName(backupTable))
			listButtonWidget:GetFontString():SetTextColor(1, 1, 1)
		else
			listButtonWidget:GetFontString():SetText(isWriteable and L["Create new"] or L["Empty"])
			listButtonWidget:GetFontString():SetTextColor(0.5, 0.5, 0.5)
		end

		listButtonWidget:SetHeight(listButtonWidget:GetFontString():GetHeight()+8)

		listButtonWidget:SetEnabled(not not backupTable or isWriteable)
		self:RefreshTooltip()
	end

	listButtonWidget:SetWidth(list.frame:GetWidth()-12)
	listButtonWidget:GetFontString():SetWidth(listButtonWidget:GetWidth()-20)
	listButtonWidget:GetFontString():SetWordWrap(true)
	listButtonWidget:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	listButtonWidget:SetScript("OnClick", function(self, button)
		if button == "LeftButton" then
			local hasBackup = not not data:GetValidBackup(data:GetCurrentProfile(), backupType, backupSlot)
			if isWriteable and (not hasBackup or IsShiftKeyDown()) then
				data:MakeBackup(data:GetCurrentProfile(), backupType, backupSlot)
			else
				data:ApplyBackup(data:GetCurrentProfile(), backupType, backupSlot)
			end
		elseif button == "RightButton" then
			if isWriteable then
				data:DeleteBackup(data:GetCurrentProfile(), backupType, backupSlot)
			end
		end
	end)

	listButtonWidget.RefreshTooltip = function(self)
		pcall(function()
			if tooltipFrame:GetOwner() == self then
				tooltipFrame:ClearLines()

				local backupTable = data:GetValidBackup(data:GetCurrentProfile(), backupType, backupSlot)

				if not backupTable and isWriteable then
					tooltipFrame:AddLine(L["Left-Click"].." - "..L["Create new"], 0.2, 1, 0.2)
				end

				if backupTable then
					tooltipFrame:AddLine(backupTable.addonName.." ("..backupTable.addonVersion..")", 1, 1, 1) -- TDLATER
					tooltipFrame:AddLine(data:GetBackupDisplayName(backupTable), 1, 1, 1)
					tooltipFrame:AddLine(" ")
					-- tooltipFrame:AddLine("Saved Vars:", 1, 1, 1) -- TDLATER
					-- for _, savedVar in ipairs(backupTable.savedVarsOrdered) do
					-- 	tooltipFrame:AddLine("    - "..savedVar, 1, 1, 1)
					-- end
					-- tooltipFrame:AddLine(" ")

					tooltipFrame:AddLine(L["Left-Click"].." - "..L["Apply"], 0.2, 1, 0.2)
					if isWriteable then
						tooltipFrame:AddLine(L["Shift-Click"].." - "..L["Overwrite"], 1, 1, 0.2)
						tooltipFrame:AddLine(L["Right-Click"].." - "..L["Delete"], 1, 0.2, 0.2)
					end
				end

				tooltipFrame:Show()
			end
		end)
	end

	listButtonWidget:HookScript("OnEnter", function(self)
		pcall(function()
			tooltipFrame:SetOwner(self, "ANCHOR_TOPLEFT")
			self:RefreshTooltip()
		end)
	end)
	listButtonWidget:HookScript("OnLeave", function(self)
		pcall(function()
			tooltipFrame:Hide()
		end)
	end)

	listButtonWidget:Refresh()

	return listButtonWidget
end

function list:Initialize()
	list.frame = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplate")
	local frame = list.frame

	-- frame properties
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetSize(220, 50) -- the height is updated dynamically
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:SetFrameStrata("TOOLTIP")
	frame:SetToplevel(true)

	-- visual
	frame.Bg:SetVertexColor(0, 0, 0, 1)

	-- title
	frame.TitleText:ClearAllPoints()
	frame.TitleText:SetPoint("TOP", frame, "TOP", 0, -5)
	frame.TitleText:SetPoint("LEFT", frame, "LEFT", 5, 0)
	frame.TitleText:SetPoint("RIGHT", frame.CloseButton, "LEFT", -5, 0)
	frame.TitleText:SetWordWrap(false)

	-- content
	frame.content = CreateFrame("Frame", nil, frame)
	frame.content:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -25)
	frame.content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
	local content = frame.content

	-- tooltip
	pcall(function()
		tooltipFrame = CreateFrame("GameTooltip", "NysTDLBackup_tooltipFrame", frame, "GameTooltipTemplate")
		tooltipFrame:SetFrameLevel(frame:GetFrameLevel()+1000)
		tooltipFrame:Hide()
	end)

	-- // creating the FIXED content (backups)

	local lastBackupType = nil
	for backupType, backupSlot in data:ForEachBackupSlot() do
		if lastBackupType ~= backupType then
			-- backupType label
			local cat = list:BackupCategoryLabel(backupType)
			if not lastWidget then
				cat:SetPoint("TOP", content, "TOP", 0, 0)
			else
				cat:SetPoint("TOP", lastWidget, "BOTTOM", 0, -2)
			end

			lastBackupType = backupType
			lastWidget = cat
		end

		-- backupSlot button
		local button = list:BackupButton(backupType, backupSlot, backupType == data.backupTypes.manual)
		button:SetPoint("TOP", lastWidget, "BOTTOM", 0, -2)
		table.insert(listButtons, button)
		lastWidget = button
	end

	frame:SetScript("OnShow", function()
		list:Refresh()
	end)

	frame:Hide()
end

function list:Refresh()
	for _,button in pairs(listButtons) do
		button:Refresh()
	end

	list.frame.TitleText:SetText(data:GetCurrentProfile(true).name.." "..L["Backups"])

	local top, bottom = list.frame:GetTop(), lastWidget:GetBottom()-8
	list.frame:SetHeight(top-bottom)
end
