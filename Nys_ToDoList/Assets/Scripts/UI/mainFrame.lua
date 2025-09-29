--/*******************/ IMPORTS /*************************/--

-- File init

local mainFrame = NysTDL.mainFrame
NysTDL.mainFrame = mainFrame

-- Primary aliases

local libs = NysTDL.libs
local core = NysTDL.core
local enums = NysTDL.enums
local utils = NysTDL.utils
local widgets = NysTDL.widgets
local database = NysTDL.database
local dragndrop = NysTDL.dragndrop
local tabsFrame = NysTDL.tabsFrame
local dataManager = NysTDL.dataManager
local optionsManager = NysTDL.optionsManager
local tutorialsManager = NysTDL.tutorialsManager

-- Secondary aliases

local L = libs.L
-- local LDD = libs.LDD

--/*******************************************************/--

-- // Variables

local private = {}

-- THE frame
local tdlFrame
local function createFrame()
	mainFrame.tdlFrame = CreateFrame("Frame", "NysTDL_tdlFrame", UIParent, utils:IsDF() and "NysTDL_MainFrameRetail" or "NysTDL_MainFrameClassic")
	tdlFrame = mainFrame.tdlFrame
end
table.insert(core.Event_OnInitialize_Start, createFrame)

mainFrame.editMode = false

-- profile-dependant variables (those are reset in mainFrame:Init())

local dontRefreshPls = 0
local contentWidgets = {}

--[[

-- // contentWidgets examples:

contentWidgets = {
	[catID] = { -- widgets:CategoryWidget(catID)
		-- data
		enum = enums.category,
		catID = catID,
		catData = catData,

		-- frames
		interactiveLabel,
		favsRemainingLabel,
		addEditBox,
	},
	...

	[itemID] = { -- widgets:ItemWidget(itemID)
		-- data
		enum = enums.item,
		itemID = itemID,
		itemData = itemData,

		-- frames
		checkBtn,
		interactiveLabel,
		removeBtn,
		favoriteBtn,
		descBtn,
	},
	...
}

]]

-- these are for code comfort

local cursorX, cursorY, cursorDist = 0, 0, 0 -- for my special drag
local loadOriginSpec, loadOriginSpecClassic = { x = 0, y = 0 }, { x = -4, y = 0 } -- TODO CLASSIC?
local sWidth, sWidthClassic = 34, 38

local loadOriginOffset, loadOriginOffsetClassic = { 14 + loadOriginSpec.x, -9 + loadOriginSpec.y }, { 14 + loadOriginSpecClassic.x, -12 + loadOriginSpecClassic.y }
local lineBottom, lineBottomClassic = { x = 12 + loadOriginSpec.x, y = -45 + loadOriginSpec.y }, { x = 12 + loadOriginSpecClassic.x, y = -45 + loadOriginSpecClassic.y }
local menuOrigin, menuOriginClassic = { 27 + loadOriginSpec.x, -22 + loadOriginSpec.y }, { 25 + loadOriginSpecClassic.x, -22 + loadOriginSpecClassic.y }

-- // WoW & Lua APIs

local GetCursorPosition = GetCursorPosition

--/*******************/ GENERAL /*************************/--

-- // Local functions

function private:MenuClick(menuEnum)
	-- controls what should be done when we click on menu buttons
	local content = tdlFrame.content
	local menu = tdlFrame.menu
	local menuFrames = menu.menuFrames

	-- // we update the selected menu (toggle mode)
	if menuFrames.selected == menuEnum then
		menuFrames.selected = nil
	else
		menuFrames.selected = menuEnum
	end

	-- so first we hide each of them
	for submenuEnum, submenuFrame in pairs(menuFrames) do
		if submenuEnum ~= "selected" then submenuFrame:Hide() end
	end

	-- and then we show the good one, if there is one to show
	local bottom = 0
	if menuFrames.selected then
		local submenu = menuFrames[menuFrames.selected]
		submenu:Show()

		bottom = lineBottom.y - submenu:GetHeight() + 13 + 32
	else
		bottom = lineBottom.y
	end
	menu.lineBottom:SetPoint("TOPLEFT", menu, "TOPLEFT", lineBottom.x, bottom)

	-- // we do specific things afterwards
	local selected = menuFrames.selected

	-- like updating the color to white-out the selected menu button, so first we reset them all
	menu.categoryButton.Icon:SetDesaturated(nil) menu.categoryButton.Icon:SetVertexColor(0.85, 0.85, 0.0)
	menu.tabActionsButton.Icon:SetDesaturated(nil)

	-- and other things
	if selected == enums.menus.addcat then -- add a category menu
		menu.categoryButton.Icon:SetDesaturated(1) menu.categoryButton.Icon:SetVertexColor(1, 1, 1)
		widgets:SetFocusEditBox(menuFrames[enums.menus.addcat].categoryEditBox)
		tutorialsManager:Validate("introduction", "addNewCat") -- tutorial
	elseif selected == enums.menus.tabact then -- tab actions menu
		menu.tabActionsButton.Icon:SetDesaturated(1)
	end
end

function private:SubMenuNameFormat(name)
	return "/ " .. (name or "") .. " \\"
end

-- // General functions

function mainFrame:GetFrame()
	return tdlFrame
end

function mainFrame:GetContentWidgets()
	return contentWidgets
end

function mainFrame:Toggle()
	-- toggles the visibility of the ToDoList frame
	tdlFrame:SetShown(not tdlFrame:IsShown())
end

function mainFrame:ChangeTab(newTabID)
	wipe(widgets.aebShown) -- hide all add edit boxes
	database.ctab(newTabID)
	mainFrame:Refresh()
end

function mainFrame:IsVisible(frame, margin)
	-- UNUSED FUNC (not really optimized)

	-- returns true if the frame is visible in the tdlFrame
	-- (not :IsVisible(), I'm talking about wether it's currently visible in the scroll frame, or hidden because of SetClipsChildren)
	margin = margin or 0

	local listScale = tdlFrame:GetEffectiveScale()
	local frameScale = frame:GetEffectiveScale()
	local newScale = listScale/frameScale

	local s = frame:GetScale()
	frame:SetScale(newScale) -- by doing this we sync both of the effective scales so that both frames are in the same CS (Coordinate Space)
	local frameX, frameY = frame:GetCenter()
	frame:SetScale(s)

	local tdlFrameMinY = tdlFrame:GetBottom()
	local tdlFrameMaxY = tdlFrame:GetTop()
	local tdlFrameMinX = tdlFrame:GetLeft()
	local tdlFrameMaxX = tdlFrame:GetRight()

	if frameX - margin > tdlFrameMinX
	and frameX + margin < tdlFrameMaxX
	and frameY - margin > tdlFrameMinY
	and frameY + margin < tdlFrameMaxY then
		return true
	end
end

function mainFrame:GetFirstShownItemWidget()
	-- returns the title or nil if not found
	local tabData = select(3, dataManager:Find(database.ctab()))
	local firstCat = select(2, next(tabData.orderedCatIDs))
	if firstCat then
		local catData = select(3, dataManager:Find(firstCat))
		for _,contentID in pairs(catData.orderedContentIDs) do
			local widget = contentWidgets[contentID]
			if widget.enum == enums.item then
				return widget
			end
		end
	end
end

-- // frame color/visual update functions

function mainFrame:UpdateCheckedStates()
	for _,contentWidget in pairs(contentWidgets) do
		if contentWidget.enum == enums.item then -- for every item checkboxes
			contentWidget.checkBtn:SetChecked(contentWidget.itemData.checked)
		end
	end
end

function mainFrame:UpdateRemainingNumberLabels()
	local tabID = database.ctab()

	-- we update the numbers of remaining things to do in total for the current tab
	local menu = tdlFrame.menu

	local numbers = dataManager:GetRemainingNumbers(nil, tabID)
	local checkedNonFav = numbers.totalChecked-numbers.checkedFav
	if (numbers.totalUnchecked-numbers.uncheckedFav > 0) then checkedNonFav = "|cffffffff"..checkedNonFav.."|r" end
	menu.remainingNumber:SetText(checkedNonFav.."/"..(numbers.total-numbers.totalFav))
	local checkedFav = numbers.checkedFav
	if (numbers.uncheckedFav > 0) then checkedFav = "|cffffffff"..checkedFav.."|r" end
	menu.remainingFavsNumber:SetText((numbers.totalFav > 0) and checkedFav.."/"..numbers.totalFav or "")

	-- we update the remaining numbers of every category in the tab
	for catID,catData in dataManager:ForEach(enums.category, tabID) do
		local nbFav = dataManager:GetRemainingNumbers(nil, tabID, catID).uncheckedFav
		local text = nbFav > 0 and "("..nbFav..")" or ""

		local catWidget = contentWidgets[catID]
		catWidget.favsRemainingLabel:SetText(text)
		catWidget.originalTabLabel:ClearAllPoints()
		catWidget.originalTabLabel:SetPoint("RIGHT", catWidget.interactiveLabel, "RIGHT", 0, 0)
		if not catData.closedInTabIDs[tabID] or text == "" then -- if the category is opened or the fav label shows nothing
			catWidget.favsRemainingLabel:Hide()
			catWidget.originalTabLabel:SetPoint("LEFT", catWidget.labelsStartPosFrame, "RIGHT", -1, 0)
		else -- if the category is closed and the fav label shows something
			catWidget.favsRemainingLabel:Show()
			catWidget.originalTabLabel:SetPoint("LEFT", catWidget.labelsStartPosFrame, "RIGHT", catWidget.favsRemainingLabel:GetStringWidth()+6, 0)
		end
	end
end

function mainFrame:UpdateFavsRemainingNumbersColor()
	-- this updates the favorite color for every favorites remaining number label
	local menu = tdlFrame.menu

	menu.remainingFavsNumber:SetTextColor(unpack(NysTDL.acedb.profile.favoritesColor))
	for _, contentWidget in pairs(contentWidgets) do
		if contentWidget.enum == enums.category then -- for every category widgets
			contentWidget.favsRemainingLabel:SetTextColor(unpack(NysTDL.acedb.profile.favoritesColor))
		end
	end
end

function mainFrame:UpdateItemNamesColor()
	for _, contentWidget in pairs(contentWidgets) do
		if contentWidget.enum == enums.item then -- for every item widget
			-- we color in accordance to their checked state
			if contentWidget.itemData.checked then
				contentWidget.interactiveLabel.Text:SetTextColor(0, 1, 0) -- green
			else
				if contentWidget.itemData.favorite then
					contentWidget.interactiveLabel.Text:SetTextColor(unpack(NysTDL.acedb.profile.favoritesColor)) -- colored
				else
					contentWidget.interactiveLabel.Text:SetTextColor(unpack(utils:ThemeDownTo01(database.themes.theme_yellow))) -- yellow
					-- contentWidget.interactiveLabel.Text:SetTextColor(1, 1, 1) -- white
				end
			end
		end
	end
end

function mainFrame:UpdateCategoryNamesColor()
	for _, contentWidget in pairs(contentWidgets) do
		if contentWidget.enum == enums.category then -- for every category widget
			-- we color in accordance to their content checked state
			if dataManager:IsCategoryCompleted(contentWidget.catID) then
				contentWidget.color = { 0, 1, 0, 1 } -- green -- TDLATER table ref for memory usage optimization
			else
				contentWidget.color = { 1, 1, 1, 1 } -- white
			end

			contentWidget.interactiveLabel.Text:SetTextColor(unpack(contentWidget.color))
		end
	end
end

function mainFrame:ApplyNewRainbowColor()
	-- // when called, takes the current favs color, goes to the next one 'i' times, then updates the visual
	-- it is called by the OnUpdate event of the frame / of one of the description frames

	local i = NysTDL.acedb.profile.rainbowSpeed

	local r, g, b = unpack(NysTDL.acedb.profile.favoritesColor)
	local Cmax = math.max(r, g, b)
	local Cmin = math.min(r, g, b)
	local delta = Cmax - Cmin

	local Hue
	if delta == 0 then
		Hue = 0
	elseif Cmax == r then
		Hue = 60 * (((g-b)/delta)%6)
	elseif Cmax == g then
		Hue = 60 * (((b-r)/delta)+2)
	elseif Cmax == b then
		Hue = 60 * (((r-g)/delta)+4)
	end

	if Hue >= 359 then
		Hue = 0
	else
		Hue = Hue + i
		if Hue >= 359 then
			Hue = Hue - 359
		end
	end

	local X = 1-math.abs((Hue/60)%2-1)

	if Hue < 60 then
		r, g, b = 1, X, 0
	elseif Hue < 120 then
		r, g, b = X, 1, 0
	elseif Hue < 180 then
		r, g, b = 0, 1, X
	elseif Hue < 240 then
		r, g, b = 0, X, 1
	elseif Hue < 300 then
		r, g, b = X, 0, 1
	elseif Hue < 360 then
		r, g, b = 1, 0, X
	end

	-- we apply the new color where it needs to be
	NysTDL.acedb.profile.favoritesColor = { r, g, b }
	mainFrame:UpdateFavsRemainingNumbersColor()
	mainFrame:UpdateItemNamesColor()
	widgets:UpdateDescFramesTitle()
end

function mainFrame:UpdateItemButtons(itemID)
	-- // shows the right button at the left of the given item
	local itemWidget = contentWidgets[itemID] -- we take the item widget
	if not itemWidget then return end -- just in case

	-- visual update for each button
	itemWidget.removeBtn:GetScript("OnShow")(itemWidget.removeBtn)
	itemWidget.favoriteBtn:GetScript("OnShow")(itemWidget.favoriteBtn)
	itemWidget.descBtn:GetScript("OnShow")(itemWidget.descBtn)

	if mainFrame.editMode then
		itemWidget.removeBtn:Show()
		itemWidget.favoriteBtn:Show()
		itemWidget.descBtn:Show()
		return
	end

	-- first we hide each button to show the good one afterwards
	itemWidget.removeBtn:Hide()
	itemWidget.descBtn:Hide()
	itemWidget.favoriteBtn:Hide()

	local itemData = itemWidget.itemData
	if itemData.description then -- the paper (description) icon takes the lead
		itemWidget.descBtn:Show()
	elseif itemData.favorite then -- then the star (favorite) icon
		itemWidget.favoriteBtn:Show()
	end
end

function mainFrame:ToggleEditMode(state, forceUpdate)
	local orig = mainFrame.editMode
	if type(state) == "boolean" then
		mainFrame.editMode = state
	else
		mainFrame.editMode = not mainFrame.editMode
	end
	if not forceUpdate and orig == mainFrame.editMode then return end

	-- // start

	local menu = tdlFrame.menu

	-- edit mode button
	menu.editModeButton:GetNormalTexture():SetDesaturated(mainFrame.editMode and 1 or nil)
	menu.editModeButton:GetPushedTexture():SetDesaturated(mainFrame.editMode and 1 or nil)
	menu.editModeButton.Glow:SetShown(mainFrame.editMode)

	-- content widgets buttons
	for _,contentWidget in pairs(contentWidgets) do
		contentWidget:SetEditMode(mainFrame.editMode)
	end

	-- we switch the category and frame options buttons for the undo and frame action ones and vice versa
	menu.tabActionsButton:SetShown(mainFrame.editMode)
	menu.undoButton:SetShown(mainFrame.editMode)

	menu.remaining:SetPoint("LEFT", menu.editModeButton, "CENTER", mainFrame.editMode and 140 or 80, 1)

	-- resize button
	tdlFrame.moveButton:SetShown(mainFrame.editMode)
	tdlFrame.resizeButton:SetShown(mainFrame.editMode)

	-- scroll bar
	local emOffset = utils:IsDF() and 32 or 12 -- TODO
	local offsetY = mainFrame.editMode and emOffset or 0
	offsetY = offsetY + (utils:IsDF() and 12 or 17)
	tdlFrame.ScrollFrame.ScrollBar:SetPoint("BOTTOMRIGHT", tdlFrame, "BOTTOMRIGHT", -38, offsetY) -- TODO CLASSIC?

	-- // refresh
	if dragndrop.dragging and not mainFrame.editMode then dragndrop:CancelDragging() end
	private:MenuClick() -- to close any opened sub-menu
	mainFrame:Refresh()
end

local onChangeView = function()
	local miniView = NysTDL.acedb.profile.isInMiniView
	local clearView = NysTDL.acedb.profile.isInClearView

	if clearView then
		tdlFrame.cvMenu.lineBottom:SetShown(miniView)
	end

	tdlFrame.ScrollFrame:ClearPoint("TOPLEFT")

	tdlFrame.content.loadOrigin:SetPoint("TOPLEFT", tdlFrame.content, "TOPLEFT", loadOriginOffset[1], loadOriginOffset[2])

	if miniView then
		if clearView then
			tdlFrame.ScrollFrame:SetPoint("TOP", tdlFrame.cvMenu.lineBottom, "BOTTOM", 0, -1)
			tdlFrame.ScrollFrame:SetPoint("LEFT", tdlFrame, "LEFT", 4, 0)
		else
			tdlFrame.content.loadOrigin:SetPoint("TOPLEFT", tdlFrame.content, "TOPLEFT", loadOriginOffset[1], loadOriginOffset[2] - 3)
			tdlFrame.ScrollFrame:SetPoint("TOPLEFT", tdlFrame, "TOPLEFT", 4, -22)
		end
	else
		tdlFrame.ScrollFrame:SetPoint("TOP", tdlFrame.menu.lineBottom, "BOTTOM", 0, -1)
		tdlFrame.ScrollFrame:SetPoint("LEFT", tdlFrame, "LEFT", 4, 0)
	end
end

function mainFrame:ToggleMinimalistView(state, forceUpdate)
	local orig = NysTDL.acedb.profile.isInMiniView
	if type(state) == "boolean" then
		NysTDL.acedb.profile.isInMiniView = state
	else
		NysTDL.acedb.profile.isInMiniView = not orig
	end
	if not forceUpdate and orig == NysTDL.acedb.profile.isInMiniView then return end

	-- // start

	local miniView = NysTDL.acedb.profile.isInMiniView

	onChangeView()

	-- view button
	-- tdlFrame.viewButton.Icon:SetDesaturated(not miniView and 1 or nil)
	-- tdlFrame.cvViewButton.Icon:SetDesaturated(not miniView and 1 or nil)

	-- menu
	local menu = tdlFrame.menu
	menu:SetShown(not miniView)

	-- // refresh
	private:MenuClick()
end

function mainFrame:ToggleClearView(state, forceUpdate)
	local orig = NysTDL.acedb.profile.isInClearView
	if type(state) == "boolean" then
		NysTDL.acedb.profile.isInClearView = state
	else
		NysTDL.acedb.profile.isInClearView = not orig
	end
	if not forceUpdate and orig == NysTDL.acedb.profile.isInClearView then return end

	-- // start

	local clearView = NysTDL.acedb.profile.isInClearView

	onChangeView()

	tdlFrame:EnableMouse(not clearView)

	tdlFrame.Bg:SetShown(not clearView)
	tdlFrame.NineSlice:SetShown(not clearView)
	tdlFrame.CloseButton:SetShown(not clearView)
	tabsFrame.tabsParentFrame:SetShown(not clearView)
	tdlFrame.ScrollFrame.ScrollBar:SetShown(not clearView)
	tdlFrame.viewButton:SetShown(not clearView)

	tdlFrame.cvMenu:SetShown(clearView)

	if clearView then
		local margin = 12
		tdlFrame:SetClampRectInsets(19-margin, -5+margin, -6+margin, 4-margin) -- better fine tuning for the clear view
		tdlFrame:RePoint()
		tdlFrame.menu:SetPoint("TOPLEFT", tdlFrame, 4, -24)
		tutorialsManager:SetPoint("introduction", "miniView", "RIGHT", tdlFrame.cvViewButton, "LEFT", -18, 0, "RIGHT")
		tutorialsManager:SetPoint("tabSwitchState", "explainSwitchButton", "BOTTOM", tdlFrame.cvTabsSwitchState, "TOP", 0, 22, "DOWN")
	else
		tdlFrame:SetClampRectInsets(4, 0, -1, 1) -- perfectly in sync with the visual
		tdlFrame:RePoint()
		tdlFrame.menu:SetPoint("TOPLEFT", tdlFrame.dummyScaleMenu, -5, 0)
		tutorialsManager:SetPoint("introduction", "miniView", "LEFT", tdlFrame.viewButton, "RIGHT", 18, 0, "LEFT")
		tutorialsManager:SetPoint("tabSwitchState", "explainSwitchButton", "LEFT", tabsFrame.switchStateButtonFrame, "RIGHT", 22, 0, "LEFT")
	end
end

function mainFrame:RefreshScale()
	-- // content font size (scale)

	local contentScale = NysTDL.acedb.profile.frameScale
	local menuScale = NysTDL.acedb.profile.menuSize

	tdlFrame.cvMenu:SetScale(menuScale)
	tdlFrame.menu:SetScale(menuScale)
	-- tdlFrame.content.dummyScaleOrigin:SetScale(menuScale)
	tdlFrame.content:SetScale(contentScale)
	dragndrop:SetScale(contentScale*tdlFrame:GetScale())

	-- tutorialsManager:SetFramesScale(scale)
end

--/*******************/ EVENTS /*************************/--

function mainFrame:Event_ScrollFrame_OnMouseWheel(delta)
	-- defines how fast we can scroll through the frame (here: 30)
	delta = delta * 30

	local newValue = tdlFrame.ScrollFrame:GetVerticalScroll() - delta

	if newValue < 0 then
		newValue = 0
	elseif newValue > tdlFrame.ScrollFrame:GetVerticalScrollRange() then
		newValue = tdlFrame.ScrollFrame:GetVerticalScrollRange()
	end

	tdlFrame.ScrollFrame:SetVerticalScroll(newValue)
end

function mainFrame:Event_FrameAlphaSlider_OnValueChanged(value)
	-- itemsList frame part
	NysTDL.acedb.profile.frameAlpha = value
	tdlFrame.Bg:SetAlpha(value/100)

	-- description frames part
	widgets:SetDescFramesAlpha(value)

	-- tab frames part
	tabsFrame:SetAlpha(value/100)
end

function mainFrame:Event_FrameContentAlphaSlider_OnValueChanged(value)
	-- itemsList frame part
	NysTDL.acedb.profile.frameContentAlpha = value
	tdlFrame.ScrollFrame:SetAlpha(value/100)
	tdlFrame.ScrollFrame.ScrollBar:SetAlpha(value/100)
	tdlFrame.moveButton:SetAlpha(value/100)
	tdlFrame.resizeButton:SetAlpha(value/100)
	tdlFrame.viewButton:SetAlpha(value/100)
	tdlFrame.CloseButton:SetAlpha(value/100)
	tdlFrame.cvMenu:SetAlpha(value/100)
	tdlFrame.menu:SetAlpha(value/100)

	-- and that's why the min opacity is 0.6!
	if utils:IsDF() then
		tdlFrame.NineSlice:SetAlpha(value/100)
	else
		tdlFrame.TitleBg:SetAlpha(value/100)
		tdlFrame.TitleText:SetAlpha(value/100)
	end

	-- description frames part
	widgets:SetDescFramesContentAlpha(value)

	-- tab frames part
	tabsFrame:SetContentAlpha(value/100)
end

function mainFrame:Event_TDLFrame_OnVisibilityUpdate()
	-- things to do when we hide/show the list
	wipe(widgets.aebShown) -- hide all add edit boxes
	private:MenuClick() -- to close any opened menu
	mainFrame:Refresh()
	NysTDL.acedb.profile.lastListVisibility = tdlFrame:IsShown()
	if dragndrop.dragging then dragndrop:CancelDragging() end
	mainFrame:ToggleEditMode(false)
	tabsFrame:HideOverflowList()
end

function mainFrame:Event_TDLFrame_OnSizeChanged(width, height)
	-- saved variables
	NysTDL.acedb.profile.frameSize.width = width
	NysTDL.acedb.profile.frameSize.height = height

	-- tell the content to resize (not using points because it's the scroll child of the scroll frame)
	tdlFrame.scrollChild:SetWidth(width-8-sWidth)

	-- and tell the tabs to resize as well
	local scale = width/enums.tdlFrameDefaultWidth
	tabsFrame:SetScale(scale)
end

function mainFrame:Event_TDLFrame_OnUpdate()
	-- tdlFrame.ScrollFrame.ScrollBar:SetShown(tdlFrame:IsMouseOver())

	-- // dragging
	if tdlFrame.isMouseDown and not tdlFrame.hasMoved then
		local x, y = GetCursorPosition()
		if (x > cursorX + cursorDist) or (x < cursorX - cursorDist) or (y > cursorY + cursorDist) or (y < cursorY - cursorDist) then  -- we start dragging the frame
			tdlFrame:StartMoving()
			tdlFrame.hasMoved = true
		end
	end
end

--/*******************/ LIST LOADING /*************************/--

function mainFrame:UpdateWidget(ID, enum)
	-- I take the enum here instead of using Find for optimization

	if contentWidgets[ID] then
		contentWidgets[ID]:ClearAllPoints()
		contentWidgets[ID]:Hide()
	end

	if enum == enums.item then
		contentWidgets[ID] = widgets:ItemWidget(ID, tdlFrame.content)
		mainFrame:UpdateItemButtons(ID)
	elseif enum == enums.category then
		contentWidgets[ID] = widgets:CategoryWidget(ID, tdlFrame.content)
		widgets.aebShown[ID] = 0 -- hide the category's add edit boxes
	end
end

function mainFrame:DeleteWidget(ID)
	if contentWidgets[ID] then
		contentWidgets[ID]:ClearAllPoints()
		contentWidgets[ID]:Hide()
		if contentWidgets[ID].enum == enums.category then
			widgets:RemoveHyperlinkEditBox(contentWidgets[ID].addEditBox)
		end
		contentWidgets[ID] = nil
	end
end

function private:LoadWidgets()
	-- // creating every category and item widget for the list
	-- called at load time / when changing profiles to crunch every creation at the same time

	-- category widgets
	for catID in dataManager:ForEach(enums.category) do
		mainFrame:UpdateWidget(catID, enums.category)
	end

	-- item widgets
	for itemID in dataManager:ForEach(enums.item) do
		mainFrame:UpdateWidget(itemID, enums.item)
	end
end

-- // Content loading

local rlHelper = {
	deep = 0,

	last = {},
	new = {},

	---@param frameType enums.rlFrameType
	ShowFrame = function(self, frame, frameType)
		self.new.relativeFrame = frame.heightFrame
		self.new.frameType = frameType
		self.new.deep = self.deep

		local offsetX, offsetY = private:DetermineOffset(self.last, self.new)

		frame:SetPoint("TOPLEFT", self.last.relativeFrame, "BOTTOMLEFT", offsetX, offsetY)
		frame:Show()

		self.last.relativeFrame = self.new.relativeFrame
		self.last.frameType = self.new.frameType
		self.last.deep = self.new.deep
	end,

	RefreshTabulationHeight = function(self, catWidget)
		repeat
			catWidget.tabulation:SetPoint("BOTTOM", self.last.relativeFrame, "BOTTOM", 0, 1)
			catWidget = contentWidgets[catWidget.catData.parentCatID]
		until not catWidget
	end,
}

function private:DetermineOffset(last, new)
	-- determine offsetX and offsetY by computing the last frame and new frame details

	if last.frameType == enums.rlFrameType.empty then
		return 0, 0
	end

	local offsetX, offsetY = 0, 0

	local isSameDeep, isNewDeeper = last.deep == new.deep, new.deep > last.deep

	offsetX = enums.ofsxContent * (new.deep - last.deep) + enums.ofsxItemIcons * (math.max(new.deep - 1, 0) - math.max(last.deep - 1, 0))

	offsetY = -enums.ofsyContent

	if not isSameDeep then
		if isNewDeeper then
			offsetY = -enums.ofsyCatContent
		else
			offsetY = -enums.ofsyContentCat
		end
	end

	if last.frameType == enums.rlFrameType.addEditBox then
		offsetY = offsetY + -3
	end

	if last.frameType == enums.rlFrameType.category and new.frameType ~= enums.rlFrameType.category and isSameDeep then
		offsetY = offsetY + -3
	end

	if new.frameType == enums.rlFrameType.empty then
		offsetY = -15
	end

	return offsetX, offsetY
end

function private:LoadContent()
	-- // reloading of elements that need updates

	local tabID = database.ctab()
	local tabData = (select(3, dataManager:Find(tabID)))

	-- // nothingLabel
	tdlFrame.content.nothingLabel:SetShown(not next(tabData.orderedCatIDs)) -- we show it if the tab has no categories

	-- // hiddenLabel
	tdlFrame.content.hiddenLabel:Hide() -- we hide it by default
	if not tdlFrame.content.nothingLabel:IsShown() then
		if not mainFrame.editMode then
			if tabData.hideCompletedCategories or tabData.hideEmptyCategories then -- only do the check if there is a point in doing it
				if dataManager:IsTabContentHidden(tabID) then
					tdlFrame.content.hiddenLabel:Show()
				end
			end
		end
	end
end

function private:RecursiveLoad(tabID, tabData, catWidget)
	local catData = catWidget.catData
	catWidget.addEditBox:Hide()
	catWidget.emptyLabel:Hide()
	catWidget.hiddenLabel:Hide()
	catWidget.tabulation:Hide()

	if catWidget.catData.originalTabID == tabID then
		catWidget.originalTabLabel:Hide()
	else -- if the tab is showing a cat that was not created here, we show the label specifying the cat's original tab
		catWidget.originalTabLabel:SetText("("..dataManager:GetName(catWidget.catData.originalTabID)..")")
		catWidget.originalTabLabel:Show()
	end

	-- if the cat is closed, ignore it
	if catData.closedInTabIDs[tabID] then
		return
	end

	rlHelper.deep = rlHelper.deep + 1
	local deep = rlHelper.deep

	local isSubCat = deep > 1

	catWidget.tabulation:SetPoint("TOP", catWidget.heightFrame, "BOTTOM", 6 + (isSubCat and enums.ofsxItemIcons or 0), -9)
	catWidget.tabulation:SetShown(isSubCat)

	-- add edit boxes : check for the flags and show them accordingly
	local isAddBoxShown = widgets.aebShown[catWidget.catID] and bit.band(widgets.aebShown[catWidget.catID], widgets.aebShownFlags.item) ~= 0
	if isAddBoxShown then -- item add edit box
		rlHelper:ShowFrame(catWidget.addEditBox, enums.rlFrameType.addEditBox)
		rlHelper:RefreshTabulationHeight(catWidget)
	end

	-- emptyLabel : we show it if there's nothing in the category
	if not next(catData.orderedContentIDs) then
		rlHelper:ShowFrame(catWidget.emptyLabel, enums.rlFrameType.label)
		rlHelper:RefreshTabulationHeight(catWidget)
		return
	end

	-- hiddenLabel : we show it if the category is completed
	if not mainFrame.editMode then
		if (tabData.hideCheckedItems and dataManager:IsCategoryCompleted(catWidget.catID))
		or (tabData.hideEmptyCategories and dataManager:IsCategoryContentHidden(catWidget.catID, tabID)) then
			rlHelper:ShowFrame(catWidget.hiddenLabel, enums.rlFrameType.label)
			rlHelper:RefreshTabulationHeight(catWidget)
			return
		end
	end

	-- then we show everything there is to show in the category
	for contentOrder,contentID in ipairs(catData.orderedContentIDs) do -- for everything in a category
		local contentWidget = contentWidgets[contentID]
		if not dataManager:IsHidden(contentID, tabID) then -- if it's not hidden, we show the corresponding widget
			rlHelper.deep = deep
			rlHelper:ShowFrame(contentWidget, contentWidget.enum == enums.item and enums.rlFrameType.item or enums.rlFrameType.category)
			rlHelper:RefreshTabulationHeight(catWidget)

			if contentWidget.enum == enums.category then -- sub-category
				private:RecursiveLoad(tabID, tabData, contentWidget)
			end
		end
	end
end

function private:LoadList()
	-- // generating all of the content (items, checkboxes, editboxes, category labels...)
	-- it's the big big important generation loop (oof)
	-- NOTE: Max 800 things to show in one tab or wow may crash due to an overflow error in the frame parent system!

	-- first things first, we hide EVERY widget, so that we only show the good ones after
	for _,contentWidget in pairs(contentWidgets) do
		contentWidget:ClearAllPoints()
		contentWidget:Hide()
	end

	-- let's go!
	local tabID = database.ctab()
	local tabData = select(3, dataManager:Find(tabID))

	rlHelper.last.relativeFrame = tdlFrame.content.loadOrigin
	rlHelper.last.frameType = enums.rlFrameType.empty
	rlHelper.last.deep = 0

	-- base category widgets loop
	for catOrder,catID in ipairs(tabData.orderedCatIDs) do
		local catWidget = contentWidgets[catID]

		if not dataManager:IsHidden(catID, tabID) then
			rlHelper.deep = 0
			rlHelper:ShowFrame(catWidget, enums.rlFrameType.category)

			if catOrder == 1 then -- if it's the first loaded cat widget
				tutorialsManager:SetPoint("introduction", "addItem", "RIGHT", catWidget, "LEFT", -23, 0) -- we put the corresponding tuto on it
			end

			private:RecursiveLoad(tabID, tabData, catWidget)
		end
	end

	rlHelper:ShowFrame(tdlFrame.content.dummyBottomFrame, enums.rlFrameType.empty) -- add a bit of space at the bottom

	-- drag&drop
	if dragndrop.dragging then
		dragndrop:UpdateDropFrames()
	end
end

-- // frame refresh

function mainFrame:UpdateVisuals()
	-- updates everything visual about the frame without actually fully refreshing it,
	-- this func can be called on its own, it's a less-intensive version than calling Refresh
	mainFrame:UpdateCheckedStates()
	mainFrame:UpdateRemainingNumberLabels()
	mainFrame:UpdateFavsRemainingNumbersColor()
	mainFrame:UpdateItemNamesColor()
	-- mainFrame:UpdateCategoryNamesColor()
	widgets:UpdateDescFramesTitle()
	widgets:UpdateTDLButtonColor()
	mainFrame.tdlFrame.cvCurrentTabText:SetText(dataManager:GetName(database.ctab()))
end

function mainFrame:DontRefreshNextTime(nb)
	-- // this func's sole purpose is optimization:
	-- ex: I sometimes only need to refresh the list one time after 10 operations instead of 10 times
	if type(nb) ~= "number" then
		nb = 1
	end

	dontRefreshPls = dontRefreshPls + nb
end

function mainFrame:Refresh()
	-- // THE refresh function, reloads the entire list's content in accordance to the current database

	-- anti-refresh for optimization
	if dontRefreshPls > 0 then
		dontRefreshPls = dontRefreshPls - 1
		return
	end

	-- // ************************************************************* // --

	local tabID = database.ctab()
	local tabData = select(3, dataManager:Find(tabID))

	-- TAB OPTION: delete checked items
	if tabData.deleteCheckedItems then
		dataManager:DeleteCheckedItems(tabID)
	end

	-- // ************************************************************* // --

	private:LoadContent() -- content reloading (menus, buttons, ...)
	private:LoadList() -- list reloading (categories, items, ...)
	mainFrame:UpdateVisuals() -- coloring...

	tutorialsManager:Refresh()
end

--/*******************/ FRAME CREATION /*************************/--

-- // Content generation

function private:GenerateMenuAddACategory()
	local menuframe = tdlFrame.menu.menuFrames[enums.menus.addcat]

	local function addCat() -- DRY
		if dataManager:CreateCategory(menuframe.categoryEditBox:GetText(), database.ctab()) then
			menuframe.categoryEditBox:SetText("") -- we clear the box if the adding was a success
			mainFrame:GetFrame().ScrollFrame:SetVerticalScroll(0)
			tutorialsManager:Validate("introduction", "addCat") -- tutorial
		end
		widgets:SetFocusEditBox(menuframe.categoryEditBox)
	end

	--/************************************************/--

	menuframe.categoryEditBox = widgets:NoPointsCatEditBox(menuframe, L["Press enter to add"])
	menuframe.categoryEditBox:SetPoint("TOPLEFT", tdlFrame.menu, "BOTTOMLEFT", lineBottom.x+3+5, lineBottom.y)
	menuframe.categoryEditBox:SetWidth(200)
	menuframe.categoryEditBox:SetScript("OnEnterPressed", addCat)
	widgets:AddHyperlinkEditBox(menuframe.categoryEditBox)
	tutorialsManager:SetPoint("introduction", "addCat", "TOP", menuframe.categoryEditBox, "BOTTOM", 0, -22)
end

function private:GenerateMenuTabActions()
	local menuframe = tdlFrame.menu.menuFrames[enums.menus.tabact]

	--/************************************************/--

	local spacingY = -6

	menuframe.btnCheck = widgets:Button(nil, menuframe, L["Check"], "Interface\\BUTTONS\\UI-CheckBox-Check")
	menuframe.btnCheck:SetPoint("TOPLEFT", tdlFrame.menu, "BOTTOMLEFT", lineBottom.x+3+3, lineBottom.y)
	menuframe.btnCheck:SetScript("OnClick", function() dataManager:ToggleTabChecked(database.ctab(), true) end)

	menuframe.btnUncheck = widgets:Button(nil, menuframe, L["Uncheck"], "Interface\\BUTTONS\\UI-CheckBox-Check-Disabled")
	menuframe.btnUncheck:SetPoint("TOPLEFT", menuframe.btnCheck, "BOTTOMLEFT", 0, spacingY)
	menuframe.btnUncheck:SetScript("OnClick", function() dataManager:ToggleTabChecked(database.ctab(), false) end)

	menuframe.btnCloseCat = widgets:Button(nil, menuframe, L["Close All"], "Interface\\BUTTONS\\Arrow-Up-Disabled")
	menuframe.btnCloseCat:SetPoint("TOPLEFT", menuframe.btnUncheck, "BOTTOMLEFT", 0, spacingY)
	menuframe.btnCloseCat:SetScript("OnClick", function() dataManager:ToggleTabClosed(database.ctab(), false) end)

	menuframe.btnOpenCat = widgets:Button(nil, menuframe, L["Open All"], "Interface\\BUTTONS\\Arrow-Down-Up")
	menuframe.btnOpenCat:SetPoint("TOPLEFT", menuframe.btnCloseCat, "BOTTOMLEFT", 0, spacingY)
	menuframe.btnOpenCat:SetScript("OnClick", function() dataManager:ToggleTabClosed(database.ctab(), true) end)

	menuframe.btnClear = widgets:Button(nil, menuframe, L["Clear"], "Interface\\GLUES\\LOGIN\\Glues-CheckBox-Check")
	menuframe.btnClear:SetPoint("TOPLEFT", menuframe.btnOpenCat, "BOTTOMLEFT", 0, spacingY)
	menuframe.btnClear:SetScript("OnClick", function() dataManager:ClearTab(database.ctab()) end)
end

function private:GenerateFrameContent()
	-- // generating the content (top to bottom)

	-- creating the scroll child, whose width will be manually controlled for word wrap purposes
	tdlFrame.scrollChild = CreateFrame("Frame", "NysTDL_tdlFrame.scrollChild", tdlFrame.ScrollFrame)
	tdlFrame.scrollChild:SetHeight(1) -- y is determined by the elements inside of it, this is just to make the frame visible. Also, x is set on resize so no need to set it here
	tdlFrame.ScrollFrame:SetScrollChild(tdlFrame.scrollChild)

	-- creating content, child of scrollChild which is scroll child of ScrollFrame (everything will be inside of content)
	tdlFrame.content = CreateFrame("Frame", "NysTDL_tdlFrame.content", tdlFrame.scrollChild)
	tdlFrame.content:SetAllPoints(tdlFrame.scrollChild)
	local content = tdlFrame.content

	local spacing = 30

	-- CLEAR VIEW menu
	tdlFrame.cvMenu = CreateFrame("Frame", "NysTDL_tdlFrame.cvMenu", tdlFrame.clipFrame)
	tdlFrame.cvMenu:SetSize(1, 1)
	tdlFrame.cvMenu:SetPoint("TOPLEFT", tdlFrame, 2, 0)

	-- CLEAR VIEW view button
	tdlFrame.cvViewButton = widgets:IconTooltipButton(tdlFrame.cvMenu, "NysTDL_ViewButton", tdlFrame.viewButtonTooltip)
	tdlFrame.cvViewButton:SetPoint("TOPLEFT", tdlFrame.cvMenu, 13, -1)
	tdlFrame.cvViewButton:SetSize(32, 32)
	tdlFrame.cvViewButton.Icon:SetSize(16, 20)
	tdlFrame.cvViewButton.Icon:SetTexture((enums.icons.view.info()))
	tdlFrame.cvViewButton.Icon:SetVertexColor(0.85, 0.85, 0.85)
	tdlFrame.cvViewButton:SetScript("OnClick", tdlFrame.viewButtonOnClick)
	tdlFrame.cvViewButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	-- CLEAR VIEW tabs switch state button
	tdlFrame.cvTabsSwitchState = widgets:IconTooltipButton(tdlFrame.cvMenu, "NysTDL_CategoryButton", "...")
	tdlFrame.cvTabsSwitchState:SetPoint("CENTER", tdlFrame.cvViewButton, "CENTER", spacing, 0)
	tdlFrame.cvTabsSwitchState:SetScript("OnClick", function()
		tabsFrame:SwitchState(nil) -- toggle
	end)
	tdlFrame.cvTabsSwitchState.Icon:SetScale(0.9)
	tdlFrame.cvTabsSwitchState.Icon:SetTexture(enums.icons.global.info())
	tdlFrame.cvTabsSwitchState.Icon:SetVertexColor(0.95, 0.95, 0.5)
	tdlFrame.cvTabsSwitchState.name = "cvSwitchButton"

	-- CLEAR VIEW tabs dropdown button
	tdlFrame.cvTabsDropdown = widgets:IconTooltipButton(tdlFrame.cvMenu, "NysTDL_CategoryButton", L["Other Tabs"])
	tdlFrame.cvTabsDropdown:SetPoint("CENTER", tdlFrame.cvTabsSwitchState, "CENTER", spacing, 0)
	tdlFrame.cvTabsDropdown:SetScript("OnClick", tabsFrame.TryShowOverflowList)

	-- CLEAR VIEW current tab text
	tdlFrame.cvCurrentTabText = widgets:NoPointsLabel(tdlFrame.cvMenu, nil, "...")
	tdlFrame.cvCurrentTabText:SetPoint("LEFT", tdlFrame.cvTabsDropdown, "CENTER", 20, 0)
	tdlFrame.cvCurrentTabText:SetFontObject("GameFontNormalLarge")

	tdlFrame.cvMenu.lineBottom = widgets:HorizontalDivider(tdlFrame.cvMenu)
	tdlFrame.cvMenu.lineBottom:SetPoint("TOPLEFT", tdlFrame.cvMenu, "TOPLEFT", lineBottom.x, -40)

	tdlFrame.dummyScaleMenu = widgets:Dummy(tdlFrame, tdlFrame, 9, -24)
	tdlFrame.menu = CreateFrame("Frame", "NysTDL_tdlFrame.menu", tdlFrame.clipFrame)
	tdlFrame.menu:SetSize(1, 1)
	local menu = tdlFrame.menu

	-- edit mode button
	menu.editModeButton = widgets:IconTooltipButton(menu, "NysTDL_EditModeButton", L["Toggle edit mode"])
	menu.editModeButton:SetPoint("CENTER", menu, "TOPLEFT", unpack(menuOrigin))
	menu.editModeButton:SetScript("OnClick", function()
		tutorialsManager:Validate("introduction", "editmode") -- I need to place this here to be sure it was a user action
		mainFrame:ToggleEditMode()
	end)
	tutorialsManager:SetPoint("introduction", "editmode", "RIGHT", menu.editModeButton, "LEFT", -18, 0)

	-- category menu button
	menu.categoryButton = widgets:IconTooltipButton(menu, "NysTDL_CategoryButton", L["Add a category"])
	menu.categoryButton.Icon:SetTexture((enums.icons.add.info()))
	menu.categoryButton.Icon:SetSize(select(2, enums.icons.add.info()))
	menu.categoryButton.Icon:SetTexCoord(unpack(enums.icons.add.texCoords))
	menu.categoryButton:SetPoint("CENTER", menu.editModeButton, "CENTER", spacing, 0)
	menu.categoryButton:SetScript("OnClick", function()
		private:MenuClick(enums.menus.addcat)
	end)
	tutorialsManager:SetPoint("introduction", "addNewCat", "TOP", menu.categoryButton, "BOTTOM", 0, -18)

	-- addon options button
	menu.frameOptionsButton = widgets:IconTooltipButton(menu, "NysTDL_FrameOptionsButton", {string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), L["Left-Click"])..utils:GetMinusStr()..L["Open addon options"], string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), L["Right-Click"])..utils:GetMinusStr()..L["Open backup list"]})
	menu.frameOptionsButton:SetPoint("CENTER", menu.categoryButton, "CENTER", spacing, 0)
	menu.frameOptionsButton:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			NysTDLBackup:OpenList()
			tutorialsManager:Validate("backup", "optionsButton") -- tutorial
		else
			optionsManager:ToggleOptions(true)
			-- tdlFrame:Hide()
		end
	end)
	menu.frameOptionsButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	menu.frameOptionsButton.Icon:SetVertexColor(0.85, 0.85, 0.85)
	tutorialsManager:SetPoint("backup", "optionsButton", "LEFT", tdlFrame.menu.frameOptionsButton, "RIGHT", 18, 0)

	-- tab actions menu button
	menu.tabActionsButton = widgets:IconTooltipButton(menu, "NysTDL_TabActionsButton", L["Tab actions"])
	menu.tabActionsButton:SetPoint("CENTER", menu.frameOptionsButton, "CENTER", 30, 0)
	menu.tabActionsButton:SetScript("OnClick", function()
		private:MenuClick(enums.menus.tabact)
	end)
	menu.tabActionsButton:Hide()

	-- undo button
	menu.undoButton = widgets:IconTooltipButton(menu, "NysTDL_UndoButton", {L["Undo last remove"], "("..L["Item"]:lower().."/"..L["Category"]:lower().."/"..L["Tab"]:lower()..")"})
	menu.undoButton:SetPoint("CENTER", menu.tabActionsButton, "CENTER", spacing, 0)
	menu.undoButton:SetScript("OnClick", function() dataManager:Undo() end)
	menu.undoButton:Hide()
	-- tutorialsManager:SetPoint("editmode", "buttons", "BOTTOM", menu.undoButton, "TOP", -15, 18)
	-- tutorialsManager:SetPoint("editmode", "undo", "BOTTOM", menu.undoButton, "TOP", 0, 18)

	-- remaining numbers labels
	menu.remaining = widgets:Dummy(menu.editModeButton)
	menu.remaining:ClearAllPoints() -- points set on edit mode toggle
	menu.remainingNumber = widgets:NoPointsLabel(menu, nil, "...")
	menu.remainingNumber:SetPoint("LEFT", menu.remaining, "RIGHT", 0, 0)
	menu.remainingNumber:SetFontObject("GameFontNormalLarge")
	menu.remainingFavsNumber = widgets:NoPointsLabel(menu, nil, "...")
	menu.remainingFavsNumber:SetPoint("LEFT", menu.remainingNumber, "RIGHT", 7, 0)
	menu.remainingFavsNumber:SetFontObject("GameFontNormalLarge")

	-- // menus
	local menuWidth, menuEnum = menu:GetWidth()
	menu.menuFrames = {
		-- these will be replaced in the code,
		-- but I'm putting them here just so I can remember how this table works
		-- --> selected = enums.menus.xxx,
		-- --> [enums.menus.xxx] = frame,
		-- --> [enums.menus.xxx] = frame,
		-- --> [enums.menus.xxx] = frame,
	}

	-- / add a category sub-menu

	menuEnum = enums.menus.addcat
	menu.menuFrames[menuEnum] = CreateFrame("Frame", nil, menu)
	menu.menuFrames[menuEnum]:SetPoint("TOPLEFT", menu, "TOPLEFT", 0, lineBottom.y)
	menu.menuFrames[menuEnum]:SetSize(menuWidth, 75) -- CVAL (coded value, non automatic)
	private:GenerateMenuAddACategory()

	-- / tab actions sub-menu

	menuEnum = enums.menus.tabact
	menu.menuFrames[menuEnum] = CreateFrame("Frame", nil, menu)
	menu.menuFrames[menuEnum]:SetPoint("TOPLEFT", menu, "TOPLEFT", 0, lineBottom.y)
	menu.menuFrames[menuEnum]:SetSize(menuWidth, 242) -- CVAL
	private:GenerateMenuTabActions()

	menu.lineBottom = widgets:HorizontalDivider(menu)

	-- // the content, below the menu

	content.loadOrigin = widgets:Dummy(content, content, 0, 0)

	content.nothingLabel = widgets:HintLabel(content, nil, L["Empty tab"].."\n"..L["Start by adding a new category!"])
	content.nothingLabel:SetPoint("TOPLEFT", content.loadOrigin, "TOPLEFT", 0, 0)
	content.nothingLabel:SetPoint("RIGHT", content, "RIGHT", 0, 0)
	content.nothingLabel:SetJustifyH("LEFT")
	content.nothingLabel:SetJustifyV("TOP")
	content.nothingLabel:SetSpacing(4)

	content.hiddenLabel = widgets:HintLabel(content, nil, L["Completed tab"])
	content.hiddenLabel:SetPoint("TOPLEFT", content.loadOrigin, "TOPLEFT", 0, 0)
	content.hiddenLabel:SetPoint("RIGHT", content, "RIGHT", 0, 0)
	content.hiddenLabel:SetJustifyH("LEFT")
	content.hiddenLabel:SetJustifyV("TOP")

	content.dummyBottomFrame = widgets:Dummy(content, content, 0, 0) -- this one if for putting a margin at the bottom of the content (mainly to leave space for the dropping of cat)
end

-- // Creating the main frame

function mainFrame:CreateTDLFrame()
	-- // we create the list

	-- properties
	tdlFrame:SetFrameStrata(NysTDL.acedb.profile.frameStrata)
	tdlFrame:SetMovable(true)
	tdlFrame:SetClampedToScreen(true)
	tdlFrame:SetResizable(true)
	if tdlFrame.SetResizeBounds then
		tdlFrame:SetResizeBounds(90, 180, enums.tdlFrameMaxWidth, enums.tdlFrameMaxHeight)
	else
		tdlFrame:SetMinResize(90, 180)
		tdlFrame:SetMaxResize(enums.tdlFrameMaxWidth, enums.tdlFrameMaxHeight)
	end
	tdlFrame:SetToplevel(true)

	tdlFrame:HookScript("OnUpdate", mainFrame.Event_TDLFrame_OnUpdate)
	tdlFrame:HookScript("OnShow", mainFrame.Event_TDLFrame_OnVisibilityUpdate)
	tdlFrame:HookScript("OnHide", mainFrame.Event_TDLFrame_OnVisibilityUpdate)
	tdlFrame:HookScript("OnSizeChanged", mainFrame.Event_TDLFrame_OnSizeChanged)
	tdlFrame:HookScript("OnMouseWheel", mainFrame.Event_ScrollFrame_OnMouseWheel)
	tdlFrame:HookScript("OnMouseUp", function(self, button) -- toggle edit mode
		if button == "RightButton" then
			tutorialsManager:Validate("introduction", "editmode")
			mainFrame:ToggleEditMode()
		end
	end)

	tutorialsManager:SetPoint("introduction", "getMoreInfo", "BOTTOM", tdlFrame, "TOP", 0, 18)

	-- helper
	tdlFrame.RePoint = function(self)
		local points = NysTDL.acedb.profile.framePos
		tdlFrame:ClearAllPoints()
		tdlFrame:SetPoint(points.point, nil, points.relativePoint, points.xOffset, points.yOffset) -- relativeFrame = nil -> entire screen
	end

	-- i can't clip with tdlframe or LOTS of things will get hidden, so i create a sub clip frame for only what i need
	tdlFrame.clipFrame = CreateFrame("Frame", nil, tdlFrame)
	tdlFrame.clipFrame:SetPoint("TOPLEFT", tdlFrame, 0, 0)
	tdlFrame.clipFrame:SetPoint("BOTTOMRIGHT", tdlFrame, -4 -sWidth, 4) -- * same as scrollframe
	tdlFrame.clipFrame:SetClipsChildren(true)

	-- title
	if utils:IsDF() then
		tdlFrame.TitleText = tdlFrame.NineSlice.TitleText
	end

	tdlFrame.TitleText:ClearAllPoints()
	tdlFrame.TitleText:SetPoint("TOP", tdlFrame, "TOP", 0, -5)
	tdlFrame.TitleText:SetPoint("LEFT", tdlFrame, "LEFT", 10, 0)
	tdlFrame.TitleText:SetPoint("RIGHT", tdlFrame.CloseButton, "LEFT")
	tdlFrame.TitleText:SetWordWrap(false)
	tdlFrame.TitleText:SetText(string.gsub(core.toc.title, "Ny's ", ""))

	if not utils:IsDF() then
		-- background
		tdlFrame.Bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble")
		-- tdlFrame.Bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
		-- tdlFrame.Bg:SetVertexColor(0, 0, 0)
		tdlFrame.Bg:SetVertexColor(0.5, 0.5, 0.5)
		tdlFrame.Bg:SetHorizTile(false)
		tdlFrame.Bg:SetVertTile(false)

		-- offset
		loadOriginOffset = loadOriginOffsetClassic
		lineBottom = lineBottomClassic
		menuOrigin = menuOriginClassic

		-- only for classic, we scale down the frame a bit (it looks better this way)
		tdlFrame:SetScale(0.95)
	end

	tutorialsManager:SetPoint("introduction", "editmodeChat", "RIGHT", tdlFrame, "LEFT", -18, 0)

	-- to move the frame AND NOT HAVE THE PRB WITH THE RESIZE so it's custom moving
	tdlFrame.isMouseDown = false
	tdlFrame.hasMoved = false
	local function StopMoving(self)
		tdlFrame.isMouseDown = false
		if tdlFrame.hasMoved == true then
			tdlFrame.hasMoved = false

			tdlFrame:StopMovingOrSizing()
			local points, _ = NysTDL.acedb.profile.framePos, nil
			points.point, _, points.relativePoint, points.xOffset, points.yOffset = tdlFrame:GetPoint()
		end
	end
	tdlFrame:HookScript("OnMouseDown", function(self, button)
		if not NysTDL.acedb.profile.lockList then
			if button == "LeftButton" then
				tdlFrame.isMouseDown = true
				cursorDist = 10
				cursorX, cursorY = GetCursorPosition()
			end
		end
	end)
	tdlFrame:HookScript("OnMouseUp", StopMoving)
	tdlFrame:HookScript("OnHide", StopMoving)

	-- // CREATING THE CONTENT OF THE FRAME // --

	-- // scroll frame (almost everything will be inside of it using a scroll child frame, see private:GenerateFrameContent())

	sWidth = utils:IsDF() and sWidth or sWidthClassic

	tdlFrame.ScrollFrame = CreateFrame("ScrollFrame", "NysTDL_tdlFrame.ScrollFrame", tdlFrame.clipFrame, utils:IsDF() and "ScrollFrameTemplate" or "UIPanelScrollFrameTemplate")
	tdlFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", tdlFrame, "BOTTOMRIGHT", -4 -sWidth, 4) -- * same as clipframe
	tdlFrame.ScrollFrame:SetScript("OnMouseWheel", mainFrame.Event_ScrollFrame_OnMouseWheel)
	tdlFrame.ScrollFrame:SetClipsChildren(true)

	-- scrollbar
	tdlFrame.ScrollFrame.ScrollBar:ClearAllPoints()
	tdlFrame.ScrollFrame.ScrollBar:SetParent(tdlFrame) -- so that it's not clipped
	tdlFrame.ScrollFrame.ScrollBar.GetParent = function() -- go along now, you didn't see anything
		return tdlFrame.ScrollFrame
	end
	if utils:IsDF() then -- TODO CLASSIC
		tdlFrame.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", tdlFrame, "TOPRIGHT", 0, -30-24)
	else
		tdlFrame.ScrollFrame.ScrollBar:SetScale(1.05)
		tdlFrame.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", tdlFrame.ScrollFrame, "TOPRIGHT", 51, -37)
	end

	-- view button
	tdlFrame.viewButtonTooltip = {string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), L["Left-Click"])..utils:GetMinusStr()..L["Toggle menu"], string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), L["Right-Click"])..utils:GetMinusStr()..L["Toggle clear view"]}
	tdlFrame.viewButtonOnClick = function(self, button)
		if button == "LeftButton" then
			mainFrame:ToggleMinimalistView()
		elseif button == "RightButton" then
			mainFrame:ToggleClearView()
			tutorialsManager:Validate("introduction", "miniView")
		end
	end

	tdlFrame.viewButton = widgets:IconTooltipButton(tdlFrame, "NysTDL_ViewButton", tdlFrame.viewButtonTooltip)
	if utils:IsDF() then
		tdlFrame.viewButton:SetPoint("TOPRIGHT", tdlFrame, "TOPRIGHT", -6, -26)
	else
		tdlFrame.viewButton:SetPoint("TOPRIGHT", tdlFrame, "TOPRIGHT", -2.5, -21)
	end
	tdlFrame.viewButton.Icon:SetTexture((enums.icons.view.info()))
	tdlFrame.viewButton.Icon:SetVertexColor(0.85, 0.85, 0.85)
	tdlFrame.viewButton:SetScript("OnClick", tdlFrame.viewButtonOnClick)
	tdlFrame.viewButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	-- tuto frame points set in clear view function

	-- -- // outside the scroll frame

	-- resize button
	tdlFrame.resizeButton = widgets:IconTooltipButton(tdlFrame, "NysTDL_TooltipResizeButton", {string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), L["Left-Click"])..utils:GetMinusStr()..L["Resize"], string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), L["Right-Click"])..utils:GetMinusStr()..L["Reset"]})
	tdlFrame.resizeButton:SetPoint("BOTTOMRIGHT", -3, 3)
	tdlFrame.resizeButton:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			tdlFrame:StartSizing("BOTTOMRIGHT")
			self:GetHighlightTexture():Hide() -- more noticeable
			if self.tooltip and self.tooltip.Hide then self.tooltip:Hide() end
		end
	end)
	tdlFrame.resizeButton:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" then
			tdlFrame:StopMovingOrSizing()
			local points, _ = NysTDL.acedb.profile.framePos, nil
			points.point, _, points.relativePoint, points.xOffset, points.yOffset = tdlFrame:GetPoint()

			self:GetHighlightTexture():Show()
			if self.tooltip and self.tooltip.Show then self.tooltip:Show() end
		end
	end)
	tdlFrame.resizeButton:SetScript("OnHide", function(self)  -- same as on mouse up, just security
		self:GetScript("OnMouseUp")(self, "LeftButton")
	end)
	tdlFrame.resizeButton:RegisterForClicks("RightButtonUp")
	tdlFrame.resizeButton:HookScript("OnClick", function(self) -- reset size
		self:GetScript("OnMouseUp")(self, "LeftButton")

		-- we resize and scale the frame
		tdlFrame:SetSize(enums.tdlFrameDefaultWidth, enums.tdlFrameDefaultHeight)

		-- we reposition the frame, because SetSize can actually move it in some cases
		tdlFrame:RePoint()
	end)

	-- move button, mainly for the clear view
	tdlFrame.moveButton = widgets:IconTooltipButton(tdlFrame, "NysTDL_MoveButton", L["Move"], 0, 0)
	tdlFrame.moveButton:SetAlpha(0.8)
	tdlFrame.moveButton:HookScript("OnEnter", function(self) self:SetAlpha(1) end)
	tdlFrame.moveButton:HookScript("OnLeave", function(self) self:SetAlpha(0.8) end)
	tdlFrame.moveButton:HookScript("OnShow", function(self) self:SetAlpha(0.8) end)
	tdlFrame.moveButton:SetPoint("BOTTOMRIGHT", -4, 20)
	tdlFrame.moveButton:HookScript("OnMouseDown", function(self)
		tdlFrame.isMouseDown = true
		cursorDist = 0
		cursorX, cursorY = GetCursorPosition()
		if self.tooltip and self.tooltip.Hide then self.tooltip:Hide() end
	end)
	tdlFrame.moveButton:HookScript("OnMouseUp", function(self)
		StopMoving()
		if self.tooltip and self.tooltip.Show then self.tooltip:Show() end
	end)

	-- // inside the scroll frame

	private:GenerateFrameContent()
end

-- // Profile init & change

function mainFrame:Init()
	-- // this func reloads the entire frame with the current database

	-- / first we reset everything that is loadable

	-- we delete and hide each widget
	for ID in pairs(contentWidgets) do
		mainFrame:DeleteWidget(ID)
	end

	-- then reset every content variable to their default value
	dontRefreshPls = 0
	wipe(contentWidgets)

	-- / now for the frame, we start by setting everything to the saved variables

	-- we resize and scale the frame
	tdlFrame:SetSize(NysTDL.acedb.profile.frameSize.width, NysTDL.acedb.profile.frameSize.height)
	mainFrame:RefreshScale()

	-- we reposition the frame
	tdlFrame:RePoint()

	-- and update its elements opacity
	mainFrame:Event_FrameAlphaSlider_OnValueChanged(NysTDL.acedb.profile.frameAlpha)
	mainFrame:Event_FrameContentAlphaSlider_OnValueChanged(NysTDL.acedb.profile.frameContentAlpha)

	-- we generate the widgets once
	private:LoadWidgets()

	-- we reset the edit mode & view state
	mainFrame:ToggleEditMode(false, true)
	mainFrame:ToggleMinimalistView(NysTDL.acedb.profile.isInMiniView, true)
	mainFrame:ToggleClearView(NysTDL.acedb.profile.isInClearView, true)

	--widgets:SetEditBoxesHyperlinksEnabled(true) -- see func details for why I'm not using it

	-- // and finally, we update the list's visibility

	local lastListVisibility = NysTDL.acedb.profile.lastListVisibility

	tdlFrame:Hide() -- WoW 10.0 now requires a frame visibility update? /shrug

	local openBehavior = NysTDL.acedb.profile.openBehavior
	if openBehavior ~= 1 then
		if openBehavior == 2 then
			tdlFrame:SetShown(lastListVisibility)
		elseif openBehavior == 4 then
			tdlFrame:Show()
		elseif openBehavior == 5 then
			local maxTime = time() + 86400 -- in the next 24 hours
			dataManager:DoIfFoundTabMatch(maxTime, "totalUnchecked", function()
				tdlFrame:Show()
			end)
		elseif openBehavior == 6 then
			local maxTime = time() + (86400*7) -- in the next week
			dataManager:DoIfFoundTabMatch(maxTime, "totalUnchecked", function()
				tdlFrame:Show()
			end)
		elseif openBehavior == 7 then
			if dataManager:GetRemainingNumbers(nil).totalUnchecked > 0 then -- anything
				tdlFrame:Show()
			end
		end
	end
end
