--/*******************/ IMPORTS /*************************/--

-- File init

local databroker = NysTDL.databroker
NysTDL.databroker = databroker

-- Primary aliases

local libs = NysTDL.libs
local core = NysTDL.core
local utils = NysTDL.utils
local enums = NysTDL.enums
local database = NysTDL.database
local mainFrame = NysTDL.mainFrame
local optionsManager = NysTDL.optionsManager

-- Secondary aliases

local L = libs.L
local LDB = libs.LDB
local LDBIcon = libs.LDBIcon
local AceTimer = libs.AceTimer
local addonName = core.addonName

--/*******************************************************/--

local private = {}

local ldbObject -- initialized in databroker:CreateDatabrokerObject
local tooltipFrame -- initialized in databroker:CreateTooltipFrame

--/***************/ TOOLTIPS /*****************/--

-- // SIMPLE

function private:DrawSimpleTooltip(tooltip)
	if not NysTDL.acedb.profile.minimap.tooltip then
		tooltip:Hide()
		return
	end

	if tooltip and tooltip.AddLine then
		-- we get the color theme
		local hex = utils:RGBToHex(database.themes.theme)

		-- then we create each line
		tooltip:ClearLines()
		tooltip:AddDoubleLine(core.toc.title, core.toc.version)
		tooltip:AddLine(string.format("|cff%s%s|r", hex, L["Click"]).." - "..string.format("|cff%s%s|r", "FFFFFF", L["Toggle the list"]))
		tooltip:AddLine(string.format("|cff%s%s|r", hex, L["Shift-Click"]).." - "..string.format("|cff%s%s|r", "FFFFFF", L["Open addon options"]))
		tooltip:AddLine(string.format("|cff%s%s|r", hex, L["Ctrl-Click"]).." - "..string.format("|cff%s%s|r", "FFFFFF", NysTDL.acedb.profile.minimap.lock and L["Unlock minimap button"] or L["Lock minimap button"]))
		tooltip:Show()
	end
end

function private:SetSimpleMode()
	local o = ldbObject
	--table.wipe(o)

	local tooltipObject -- we get the tooltip frame on the first private:DrawSimpleTooltip call from OnTooltipShow
	o.type = "launcher"
	o.label = core.toc.title
	o.icon = "Interface\\AddOns\\"..addonName.."\\Assets\\Art\\minimap_icon"
	function o.OnClick()
		if IsControlKeyDown() then
			-- lock minimap button
			if not NysTDL.acedb.profile.minimap.lock then
				LDBIcon:Lock(addonName)
			else
				LDBIcon:Unlock(addonName)
			end
			private:DrawSimpleTooltip(tooltipObject) -- we redraw the tooltip to display the lock change
		elseif IsShiftKeyDown() then
			-- toggle addon options
			optionsManager:ToggleOptions()
		else
			-- toggle the list
			mainFrame:Toggle()
		end
	end
	function o.OnTooltipShow(tooltip)
		tooltipObject = tooltip
		private:DrawSimpleTooltip(tooltip)
	end
end

-- // ADVANCED

function private:DrawAdvancedTooltip(tooltip)
	if not NysTDL.acedb.profile.minimap.tooltip then -- TDLATER remove duplicates
		tooltip:Hide()
		return
	end

	if tooltip and tooltip.AddLine then
		-- we get the color theme
		local hex = utils:RGBToHex(database.themes.theme)

		-- then we create each line
		tooltip:ClearLines()
		tooltip:AddDoubleLine(core.toc.title, core.toc.version)
		tooltip:AddLine("ADVANCED TOOLTIP")
		tooltip:Show()
	end
end

function private:SetAdvancedMode()
	local o = ldbObject
	table.wipe(o)

	local tooltipObject -- we get the tooltip frame on the first private:DrawSimpleTooltip call from OnTooltipShow
	o.type = "launcher"
	o.label = core.toc.title.." ADVANCED"
	o.icon = "Interface\\AddOns\\"..addonName.."\\Assets\\Art\\minimap_icon"
	function o.OnClick()
		if IsControlKeyDown() then
			-- lock minimap button
			if not NysTDL.acedb.profile.minimap.lock then
				LDBIcon:Lock(addonName)
			else
				LDBIcon:Unlock(addonName)
			end
			private:DrawAdvancedTooltip(tooltipObject) -- we redraw the tooltip to display the lock change
		elseif IsShiftKeyDown() then
			-- toggle addon options
			optionsManager:ToggleOptions()
		else
			-- toggle the list
			mainFrame:Toggle()
		end
	end
	function o.OnTooltipShow(tooltip)
		tooltipObject = tooltip
		private:DrawAdvancedTooltip(tooltip)
	end
end

-- // FRAME

function databroker:CreateTooltipFrame()
	tooltipFrame = CreateFrame("Frame")
	tooltipFrame:Hide()
end

function private:SetFrameMode()
	local o = ldbObject
	table.wipe(o)

	o.type = "launcher"
	o.label = core.toc.title.." TDLATER"
	o.icon = "Interface\\AddOns\\"..addonName.."\\Assets\\Art\\minimap_icon"
end

--/***************/ DATAOBJECT /*****************/--

---Changes the current databroker mode.
---@param mode enums.databrokerModes
function databroker:SetMode(mode)
	if mode == enums.databrokerModes.simple then
		private:SetSimpleMode()
	elseif mode == enums.databrokerModes.advanced then
		private:SetAdvancedMode()
	elseif mode == enums.databrokerModes.frame then
		private:SetFrameMode()
	end
	NysTDL.acedb.profile.databrokerMode = mode
end

function databroker:CreateDatabrokerObject()
	ldbObject = LDB:NewDataObject(addonName)
	databroker:SetMode(NysTDL.acedb.profile.databrokerMode)
end

-- minimap button

function databroker:CreateMinimapButton()
	-- Registering the data broker and creating the button
	LDBIcon:Register(addonName, ldbObject, NysTDL.acedb.profile.minimap)

	-- this is the secret to correctly update the button position, (since we can't update it in the init code)
	-- so that the first time that we click on it, it doesn't go somewhere else like so many do,
	-- we just delay its update :D (enough number of times to be sure, considering some ppl take longer times to load the UI)
	local iconTimerCount = 0
	local iconTimerCountMax = 7
	local delay = 1.2 -- in seconds

	-- so here, we are, each delay for max iconTimerCountMax seconds calling this function
	local iconTimer
	iconTimer = AceTimer:ScheduleRepeatingTimer(function()
		-- we really do this to call this function
		databroker:RefreshMinimapButton()

		-- and here we check and stop the timer when we're done
		iconTimerCount = iconTimerCount + 1
		if iconTimerCount == iconTimerCountMax then
			AceTimer:CancelTimer(iconTimer)
		end
	end, delay)
end

function databroker:RefreshMinimapButton()
	LDBIcon:Refresh(addonName, NysTDL.acedb.profile.minimap)
end
