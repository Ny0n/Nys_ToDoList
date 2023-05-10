-- Namespace
local _, addonTable = ...

local list = addonTable.list

--/*******************/ Functions /*************************/--

function NysTDLBackup:ToggleList()
	if not list.frame then
		print("Backup list not initialized")
		return
	end

	list.frame:SetShown(not list.frame:IsShown())
end

function list:CreateBackupFrame()
	list.frame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	list.frame:Hide()
end
