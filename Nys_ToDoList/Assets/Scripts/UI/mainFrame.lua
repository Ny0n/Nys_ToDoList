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
mainFrame.tdlFrame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
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

local tdlFrame = mainFrame.tdlFrame

local centerXOffset = 165
local lineOffset = 120
local cursorX, cursorY, cursorDist = 0, 0, 10 -- for my special drag
local lineBottomY = -80

-- // WoW & Lua APIs

local GetCursorPosition = GetCursorPosition

--/*******************/ GENERAL /*************************/--

-- // Local functions

function private:MenuClick(menuEnum)
	-- controls what should be done when we click on menu buttons
	local menuFrames = tdlFrame.content.menuFrames

	-- // we update the selected menu (toggle mode)
	if menuFrames.selected == menuEnum then
		menuFrames.selected = nil
	else
		menuFrames.selected = menuEnum
	end

	mainFrame:Refresh() -- we reload the frame to display the changes

	-- // we do specific things afterwards
	local selected = menuFrames.selected

	-- like updating the color to white-out the selected menu button, so first we reset them all
	tdlFrame.content.categoryButton.Icon:SetDesaturated(nil) tdlFrame.content.categoryButton.Icon:SetVertexColor(0.85, 1, 1) -- here we change the vertex color because the original icon is a bit reddish
	tdlFrame.content.frameOptionsButton.Icon:SetDesaturated(nil)
	tdlFrame.content.tabActionsButton.Icon:SetDesaturated(nil)

	-- and other things
	if selected == enums.menus.addcat then -- add a category menu
		tdlFrame.content.categoryButton.Icon:SetDesaturated(1) tdlFrame.content.categoryButton.Icon:SetVertexColor(1, 1, 1)
		widgets:SetFocusEditBox(menuFrames[enums.menus.addcat].categoryEditBox)
		tutorialsManager:Validate("TM_introduction_addNewCat") -- tutorial
	elseif selected == enums.menus.frameopt then -- frame options menu
		tdlFrame.content.frameOptionsButton.Icon:SetDesaturated(1)
		tutorialsManager:Validate("TM_introduction_accessOptions") -- tutorial
	elseif selected == enums.menus.tabact then -- tab actions menu
		tdlFrame.content.tabActionsButton.Icon:SetDesaturated(1)
	end
end

function private:SetDoubleLinePoints(lineLeft, lineRight, l, y)
	local lineMinWidth = 5
	local semiLength = l/2 + 10

	if semiLength + lineMinWidth >= lineOffset then
		lineLeft:Hide()
		lineRight:Hide()
		return
	end

	lineLeft:SetStartPoint("TOPLEFT", centerXOffset-lineOffset, y)
	lineLeft:SetEndPoint("TOPLEFT", centerXOffset-l/2 - 10, y)
	lineRight:SetStartPoint("TOPLEFT", centerXOffset+l/2 + 10, y)
	lineRight:SetEndPoint("TOPLEFT", centerXOffset+lineOffset, y)
	lineLeft:Show()
	lineRight:Show()
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
	local numbers = dataManager:GetRemainingNumbers(nil, tabID)
	local remainingNumberText = (numbers.totalUnchecked > 0 and "|cffffffff" or "|cff00ff00")..numbers.totalUnchecked.."|r"
	tdlFrame.content.remainingNumber:SetText(remainingNumberText)
	local remainingFavsNumber = numbers.uncheckedFav > 0 and "("..numbers.uncheckedFav..")" or ""
	tdlFrame.content.remainingFavsNumber:SetText(remainingFavsNumber)

	-- now we check the length of the whole "Remaining: x (x)" text,
	-- and we scale it down if it's too long, to maxWidth.
	-- (this is mainly to adapt for locales that are bigger than english)
	local maxWidth = 150

	local full = tdlFrame.content.remaining:GetText() .. " " .. remainingNumberText .. (#remainingFavsNumber > 0 and " "..remainingFavsNumber or "")
	local width = widgets:GetWidth(full, "GameFontNormalLarge")

	local scale = 1
	if width > maxWidth then
		scale = maxWidth/width
	end

	tdlFrame.content.remaining:SetTextScale(scale)
	tdlFrame.content.remainingNumber:SetTextScale(scale)
	tdlFrame.content.remainingFavsNumber:SetTextScale(scale)

	-- we update the remaining numbers of every category in the tab
	for catID,catData in dataManager:ForEach(enums.category, tabID) do
		local nbFav = dataManager:GetRemainingNumbers(nil, tabID, catID).uncheckedFav
		local text = nbFav > 0 and "("..nbFav..")" or ""

		local catWidget = contentWidgets[catID]
		catWidget.favsRemainingLabel:SetText(text)
		if not catData.closedInTabIDs[tabID] or text == "" then -- if the category is opened or the label shows nothing
			catWidget.favsRemainingLabel:Hide()
			catWidget.originalTabLabel:ClearAllPoints()
			catWidget.originalTabLabel:SetPoint("LEFT", catWidget.interactiveLabel, "RIGHT", 6, 0)
		else -- if the category is closed and the label shows something
			catWidget.favsRemainingLabel:Show()
			catWidget.originalTabLabel:ClearAllPoints()
			catWidget.originalTabLabel:SetPoint("LEFT", catWidget.favsRemainingLabel, "RIGHT", 6, 0)
		end
	end
end

function mainFrame:UpdateFavsRemainingNumbersColor()
	-- this updates the favorite color for every favorites remaining number label
	tdlFrame.content.remainingFavsNumber:SetTextColor(unpack(NysTDL.acedb.profile.favoritesColor))
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
	if not forceUpdate and orig == mainFrame.editMode then return end -- if we didn't change the edit mode

	if mainFrame.editMode then
		tutorialsManager:SetPoint("TM_introduction_editmodeChat", "RIGHT", tdlFrame, "LEFT", -18, 0)
	else
		tutorialsManager:SetPoint("TM_introduction_editmodeChat", "CENTER", nil, "CENTER", 0, 0)
	end

	-- // start

	-- edit mode button
	tdlFrame.content.editModeButton:GetNormalTexture():SetDesaturated(mainFrame.editMode and 1 or nil)
	tdlFrame.content.editModeButton:GetPushedTexture():SetDesaturated(mainFrame.editMode and 1 or nil)
	tdlFrame.content.editModeButton.Glow:SetShown(mainFrame.editMode)

	-- content widgets buttons
	for _,contentWidget in pairs(contentWidgets) do
		contentWidget:SetEditMode(mainFrame.editMode)
	end

	-- we switch the category and frame options buttons for the undo and frame action ones and vice versa
	tdlFrame.content.categoryButton:SetShown(not mainFrame.editMode)
	tdlFrame.content.frameOptionsButton:SetShown(not mainFrame.editMode)
	tdlFrame.content.tabActionsButton:SetShown(mainFrame.editMode)
	tdlFrame.content.undoButton:SetShown(mainFrame.editMode)

	-- resize button
	tdlFrame.resizeButton:SetShown(mainFrame.editMode)

	-- scroll bar
	if mainFrame.editMode then
		tdlFrame.ScrollFrame.ScrollBar:SetPoint("BOTTOMRIGHT", tdlFrame.ScrollFrame, "BOTTOMRIGHT", - 7, 32)
	else
		tdlFrame.ScrollFrame.ScrollBar:SetPoint("BOTTOMRIGHT", tdlFrame.ScrollFrame, "BOTTOMRIGHT", - 7, 17)
	end

	-- // refresh
	private:MenuClick() -- to close any opened menu and refresh the list
end

--/*******************/ EVENTS /*************************/--

function mainFrame:Event_ScrollFrame_OnMouseWheel(delta)
	-- defines how fast we can scroll throught the frame (here: 30)
	local newValue = tdlFrame.ScrollFrame:GetVerticalScroll() - (delta * 30)

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
	tdlFrame.content.menuFrames[enums.menus.frameopt].frameAlphaSliderValue:SetText(value)
	tdlFrame:SetBackdropColor(0, 0, 0, value/100)
	tdlFrame:SetBackdropBorderColor(1, 1, 1, value/100)

	-- description frames part
	widgets:SetDescFramesAlpha(value)

	-- tab frames part
	tabsFrame:SetAlpha(value/100)
end

function mainFrame:Event_FrameContentAlphaSlider_OnValueChanged(value)
	-- itemsList frame part
	NysTDL.acedb.profile.frameContentAlpha = value
	tdlFrame.content.menuFrames[enums.menus.frameopt].frameContentAlphaSliderValue:SetText(value)
	tdlFrame.content:SetAlpha(value/100) -- content
	tdlFrame.ScrollFrame.ScrollBar:SetAlpha(value/100)
	tdlFrame.closeButton:SetAlpha(value/100)
	tdlFrame.resizeButton:SetAlpha(value/100)

	-- description frames part
	widgets:SetDescFramesContentAlpha(value)

	-- tab frames part
	tabsFrame:SetContentAlpha(value/100)
end

function mainFrame:Event_TDLFrame_OnVisibilityUpdate()
	-- things to do when we hide/show the list
	private:MenuClick() -- to close any opened menu and refresh the list
	NysTDL.acedb.profile.lastListVisibility = tdlFrame:IsShown()
	if dragndrop.dragging then dragndrop:CancelDragging() end
	mainFrame:ToggleEditMode(false)
end

function mainFrame:Event_TDLFrame_OnSizeChanged(width, height)
	-- saved variables
	NysTDL.acedb.profile.frameSize.width = width
	NysTDL.acedb.profile.frameSize.height = height

	-- scaling
	local scale = width/enums.tdlFrameDefaultWidth
	self.content:SetScale(scale) -- content
	self.ScrollFrame.ScrollBar:SetScale(scale)
	self.closeButton:SetScale(scale)
	self.resizeButton:SetScale(scale)
	dragndrop:SetScale(scale)
	tabsFrame:SetScale(scale)
	tutorialsManager:SetFramesScale(scale)
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

function private:LoadContent()
	-- // reloading of elements that need updates

	-- // we show the good sub-menu (add a category, frame options, tab actions, ...)
	local menuFrames = tdlFrame.content.menuFrames
	-- so first we hide each of them
	for menuEnum, menuFrame in pairs(menuFrames) do
		if menuEnum ~= "selected" then menuFrame:Hide() end
	end

	-- and then we show the good one, if there is one to show
	if menuFrames.selected then
		local menu = menuFrames[menuFrames.selected]
		menu:Show()
		tdlFrame.content.lineBottom:SetStartPoint("TOPLEFT", centerXOffset-lineOffset, lineBottomY - menu:GetHeight())
		tdlFrame.content.lineBottom:SetEndPoint("TOPLEFT", centerXOffset+lineOffset, lineBottomY - menu:GetHeight())
	else
		tdlFrame.content.lineBottom:SetStartPoint("TOPLEFT", centerXOffset-lineOffset, lineBottomY)
		tdlFrame.content.lineBottom:SetEndPoint("TOPLEFT", centerXOffset+lineOffset, lineBottomY)
	end

	local tabID = database.ctab()
	local tabData = (select(3, dataManager:Find(tabID)))

	-- // nothingLabel
	tdlFrame.content.nothingLabel:Hide() -- we hide it by default
	if not next(tabData.orderedCatIDs) then -- we show it if the tab has no categories
		tdlFrame.content.nothingLabel:Show()
	end

	-- // hiddenLabel
	tdlFrame.content.hiddenLabel:Hide() -- we hide it by default
	if not tdlFrame.content.nothingLabel:IsShown() then
		if not mainFrame.editMode then
			if tabData.hideCompletedCategories then
				if dataManager:IsTabCompleted(tabID) then
					tdlFrame.content.hiddenLabel:Show()
				end
			end
		end
	end
end

function private:RecursiveLoad(tabID, tabData, catWidget, p)
	local catData = catWidget.catData
	catWidget.addEditBox:Hide() -- we always hide every addEditBox on list Refresh
	catWidget.emptyLabel:Hide()
	catWidget.hiddenLabel:Hide()

	-- if the cat is closed, ignore it
	if catData.closedInTabIDs[tabID] then
		p.newY = p.newY - enums.ofsyCat
		return
	end

	p.newY = p.newY - enums.ofsyCatContent

	-- emptyLabel : we show it if there's nothing in the category
	if not next(catData.orderedContentIDs) then
		catWidget.emptyLabel:Show()
		p.newY = p.newY - enums.ofsyContentCat
		return
	end

	-- hiddenLabel : we show it if the category is completed
	if not mainFrame.editMode then
		if tabData.hideCheckedItems then
			if not dataManager:IsParent(catWidget.catID) then
				if dataManager:IsCategoryCompleted(catWidget.catID) then
					catWidget.hiddenLabel:Show()
					p.newY = p.newY - enums.ofsyContentCat
					return
				end
			end
		end
	end

	-- then we show everything there is to show in the category
	p.newX = p.newX + enums.ofsxContent
	for contentOrder,contentID in ipairs(catData.orderedContentIDs) do -- for everything in a category
		local contentWidget = contentWidgets[contentID]
		if not dataManager:IsHidden(contentID, tabID) then -- if it's not hidden, we show the corresponding widget
			contentWidget:SetPoint("TOPLEFT", tdlFrame.content.loadOrigin, "TOPLEFT", p.newX, p.newY)
			contentWidget:Show()

			if contentWidget.enum == enums.category then -- sub-category
				private:RecursiveLoad(tabID, tabData, contentWidget, p)
			elseif contentWidget.enum == enums.item then -- item
				p.newY = p.newY - enums.ofsyContent
			end
		end
	end
	p.newX = p.newX - enums.ofsxContent

	p.newY = p.newY + enums.ofsyContent -- TDLATER take last used offset for sub-cats? (not sure of this comment tho)
	p.newY = p.newY - enums.ofsyContentCat
end

function private:LoadList()
	-- // generating all of the content (items, checkboxes, editboxes, category labels...)
	-- it's the big big important generation loop (oof)

	-- first things first, we hide EVERY widget, so that we only show the good ones after
	for _,contentWidget in pairs(contentWidgets) do
		contentWidget:ClearAllPoints()
		contentWidget:Hide()
	end

	-- let's go!
	local tabID = database.ctab()
	local tabData = select(3, dataManager:Find(tabID))
	local p = { -- pos table
		newX = 0,
		newY = 0,
	}

	-- base category widgets loop
	for catOrder,catID in ipairs(tabData.orderedCatIDs) do
		local catWidget = contentWidgets[catID]

		if not dataManager:IsHidden(catID, tabID) then
			catWidget:SetPoint("TOPLEFT", tdlFrame.content.loadOrigin, "TOPLEFT", p.newX, p.newY)
			catWidget:Show()

			if catOrder == 1 then -- if it's the first loaded cat widget
				tutorialsManager:SetPoint("TM_introduction_addItem", "RIGHT", catWidget, "LEFT", -23, 0) -- we put the corresponding tuto on it
				-- local firstItemWidget = mainFrame:GetFirstShownItemWidget()
				-- tutorialsManager:SetPoint("TM_editmode_delete", "RIGHT", firstItemWidget, "LEFT", 0, 0)
				-- tutorialsManager:SetPoint("TM_editmode_favdesc", "RIGHT", firstItemWidget, "LEFT", math.abs(enums.ofsxItemIcons), 0)
				-- tutorialsManager:SetPoint("TM_editmode_rename", "TOP", firstItemWidget.interactiveLabel, "BOTTOM", 0, 0)
				-- tutorialsManager:SetPoint("TM_editmode_sort", "BOTTOM", firstItemWidget.interactiveLabel, "TOP", 0, 0)
			end

			if catWidget.catData.originalTabID == tabID then
				catWidget.originalTabLabel:Hide()
			else -- if the tab is showing a cat that was not created here, we show the label specifying the cat's original tab
				catWidget.originalTabLabel:SetText("("..dataManager:GetName(catWidget.catData.originalTabID)..")")
				catWidget.originalTabLabel:Show()
			end

			private:RecursiveLoad(tabID, tabData, catWidget, p)
		end
	end

	tdlFrame.content.dummyBottomFrame:SetPoint("TOPLEFT", tdlFrame.content.loadOrigin, "TOPLEFT", p.newX, p.newY)

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
end

--/*******************/ FRAME CREATION /*************************/--

-- // Content generation

function private:GenerateMenuAddACategory()
	local menuframe = tdlFrame.content.menuFrames[enums.menus.addcat]

	local function addCat() -- DRY
		if dataManager:CreateCategory(menuframe.categoryEditBox:GetText(), database.ctab()) then
			menuframe.categoryEditBox:SetText("") -- we clear the box if the adding was a success
			tutorialsManager:Validate("TM_introduction_addCat") -- tutorial
		end
		widgets:SetFocusEditBox(menuframe.categoryEditBox)
	end

	--/************************************************/--

	-- title
	menuframe.menuTitle = widgets:NoPointsLabel(menuframe, nil, string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), private:SubMenuNameFormat(L["Add a category"])))
	menuframe.menuTitle:SetPoint("CENTER", menuframe, "TOPLEFT", centerXOffset, 0)
	-- left/right lines
	menuframe.menuTitleLL = widgets:ThemeLine(menuframe, database.themes.theme, 0.7)
	menuframe.menuTitleLR = widgets:ThemeLine(menuframe, database.themes.theme, 0.7)
	private:SetDoubleLinePoints(menuframe.menuTitleLL, menuframe.menuTitleLR, menuframe.menuTitle:GetWidth(), 0)

	--/************************************************/--

	menuframe.labelCategoryName = widgets:NoPointsLabel(menuframe, nil, L["Name"]..":")
	menuframe.labelCategoryName:SetPoint("TOPLEFT", menuframe.menuTitle, "TOP", -140, -32)

	menuframe.categoryEditBox = CreateFrame("EditBox", nil, menuframe, "InputBoxTemplate") -- edit box to put the new category name
	menuframe.categoryEditBox:SetPoint("RIGHT", menuframe, "RIGHT", -3, 0)
	menuframe.categoryEditBox:SetPoint("LEFT", menuframe.labelCategoryName, "RIGHT", 10, 0)
	menuframe.categoryEditBox:SetHeight(30)
	menuframe.categoryEditBox:SetAutoFocus(false)
	menuframe.categoryEditBox:SetScript("OnEnterPressed", addCat) -- if we press enter, it's like we clicked on the add button
	menuframe.categoryEditBox:HookScript("OnEditFocusGained", function(self)
		-- since this edit box stays there, even when we lose the focus,
		-- I have to reapply the highlight depending on the SV
		-- when clicking on it
		if NysTDL.acedb.profile.highlightOnFocus then
			self:HighlightText()
		else
			self:HighlightText(self:GetCursorPosition(), self:GetCursorPosition())
		end
	end)

	menuframe.addBtn = widgets:Button("NysTDL_category_addButton", menuframe, L["Add"], nil, nil, 40)
	menuframe.addBtn:SetPoint("TOP", menuframe.menuTitle, "TOP", 0, -65)
	menuframe.addBtn:SetScript("OnClick", addCat)

	tutorialsManager:SetPoint("TM_introduction_addCat", "TOP", menuframe.addBtn, "BOTTOM", 0, -22)
end

function private:GenerateMenuFrameOptions()
	local menuframe = tdlFrame.content.menuFrames[enums.menus.frameopt]

	--/************************************************/--

	-- title
	menuframe.menuTitle = widgets:NoPointsLabel(menuframe, nil, string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), private:SubMenuNameFormat(L["Frame options"])))
	menuframe.menuTitle:SetPoint("CENTER", menuframe, "TOPLEFT", centerXOffset, 0)
	-- left/right lines
	menuframe.menuTitleLL = widgets:ThemeLine(menuframe, database.themes.theme, 0.7)
	menuframe.menuTitleLR = widgets:ThemeLine(menuframe, database.themes.theme, 0.7)
	private:SetDoubleLinePoints(menuframe.menuTitleLL, menuframe.menuTitleLR, menuframe.menuTitle:GetWidth(), 0)

	--/************************************************/--

	menuframe.frameAlphaSlider = CreateFrame("Slider", "NysTDL_mainFrame_frameAlphaSlider", menuframe, "OptionsSliderTemplate") -- NAME IS MANDATORY
	menuframe.frameAlphaSlider:SetPoint("TOP", menuframe.menuTitle, "TOP", 0, -45)
	menuframe.frameAlphaSlider:SetWidth(200)
	-- menuframe.frameAlphaSlider:SetHeight(17)
	-- menuframe.frameAlphaSlider:SetOrientation('HORIZONTAL')

	menuframe.frameAlphaSlider:SetMinMaxValues(0, 100)
	menuframe.frameAlphaSlider:SetValue(NysTDL.acedb.profile.frameAlpha)
	menuframe.frameAlphaSlider:SetValueStep(1)
	menuframe.frameAlphaSlider:SetObeyStepOnDrag(true)

	menuframe.frameAlphaSlider.tooltipText = L["Change the background opacity"] -- creates a tooltip on mouseover
	_G[menuframe.frameAlphaSlider:GetName() .. 'Low']:SetText((select(1,menuframe.frameAlphaSlider:GetMinMaxValues()))..'%') -- sets the left-side slider text (default is "Low")
	_G[menuframe.frameAlphaSlider:GetName() .. 'High']:SetText((select(2,menuframe.frameAlphaSlider:GetMinMaxValues()))..'%') -- sets the right-side slider text (default is "High")
	_G[menuframe.frameAlphaSlider:GetName() .. 'Text']:SetText(L["Frame opacity"]) -- sets the "title" text (top-center of slider)
	menuframe.frameAlphaSlider:SetScript("OnValueChanged", mainFrame.Event_FrameAlphaSlider_OnValueChanged)

	menuframe.frameAlphaSliderValue = menuframe.frameAlphaSlider:CreateFontString("NysTDL_mainFrame_frameAlphaSliderValue") -- the font string to see the current value -- NAME IS MANDATORY
	menuframe.frameAlphaSliderValue:SetPoint("TOP", menuframe.frameAlphaSlider, "BOTTOM", 0, 0)
	menuframe.frameAlphaSliderValue:SetFontObject("GameFontNormalSmall")
	menuframe.frameAlphaSliderValue:SetText(menuframe.frameAlphaSlider:GetValue())

	--/************************************************/--

	menuframe.frameContentAlphaSlider = CreateFrame("Slider", "NysTDL_mainFrame_frameContentAlphaSlider", menuframe, "OptionsSliderTemplate") -- NAME IS MANDATORY
	menuframe.frameContentAlphaSlider:SetPoint("TOP", menuframe.frameAlphaSlider, "TOP", 0, -50)
	menuframe.frameContentAlphaSlider:SetWidth(200)
	-- menuframe.frameContentAlphaSlider:SetHeight(17)
	-- menuframe.frameContentAlphaSlider:SetOrientation('HORIZONTAL')

	menuframe.frameContentAlphaSlider:SetMinMaxValues(60, 100)
	menuframe.frameContentAlphaSlider:SetValue(NysTDL.acedb.profile.frameContentAlpha)
	menuframe.frameContentAlphaSlider:SetValueStep(1)
	menuframe.frameContentAlphaSlider:SetObeyStepOnDrag(true)

	menuframe.frameContentAlphaSlider.tooltipText = L["Change the opacity for texts, buttons and other elements"] --Creates a tooltip on mouseover.
	_G[menuframe.frameContentAlphaSlider:GetName() .. 'Low']:SetText((select(1,menuframe.frameContentAlphaSlider:GetMinMaxValues()))..'%') --Sets the left-side slider text (default is "Low").
	_G[menuframe.frameContentAlphaSlider:GetName() .. 'High']:SetText((select(2,menuframe.frameContentAlphaSlider:GetMinMaxValues()))..'%') --Sets the right-side slider text (default is "High").
	_G[menuframe.frameContentAlphaSlider:GetName() .. 'Text']:SetText(L["Frame content opacity"]) --Sets the "title" text (top-centre of slider).
	menuframe.frameContentAlphaSlider:SetScript("OnValueChanged", mainFrame.Event_FrameContentAlphaSlider_OnValueChanged)

	menuframe.frameContentAlphaSliderValue = menuframe.frameContentAlphaSlider:CreateFontString("NysTDL_mainFrame_frameContentAlphaSliderValue") -- the font string to see the current value -- NAME IS MANDATORY
	menuframe.frameContentAlphaSliderValue:SetPoint("TOP", menuframe.frameContentAlphaSlider, "BOTTOM", 0, 0)
	menuframe.frameContentAlphaSliderValue:SetFontObject("GameFontNormalSmall")
	menuframe.frameContentAlphaSliderValue:SetText(menuframe.frameContentAlphaSlider:GetValue())

	--/************************************************/--

	menuframe.affectDesc = CreateFrame("CheckButton", nil, menuframe, "ChatConfigCheckButtonTemplate")
	menuframe.affectDesc.tooltip = L["Share the opacity options of the list to the description frames"].." ("..L["Only when checked"]..")"
	menuframe.affectDesc:SetPoint("TOP", menuframe.frameContentAlphaSlider, "TOP", 0, -40)
	menuframe.affectDesc.Text:SetText(L["Apply to description frames"])
	menuframe.affectDesc.Text:SetFontObject("GameFontHighlight")
	menuframe.affectDesc.Text:ClearAllPoints()
	menuframe.affectDesc.Text:SetPoint("TOP", menuframe.affectDesc, "BOTTOM")
	menuframe.affectDesc:SetHitRectInsets(0, 0, 0, 0)
	menuframe.affectDesc:SetScript("OnClick", function(self)
		NysTDL.acedb.profile.affectDesc = not NysTDL.acedb.profile.affectDesc
		self:SetChecked(NysTDL.acedb.profile.affectDesc)
		mainFrame:Event_FrameAlphaSlider_OnValueChanged(NysTDL.acedb.profile.frameAlpha)
		mainFrame:Event_FrameContentAlphaSlider_OnValueChanged(NysTDL.acedb.profile.frameContentAlpha)
	end)
	menuframe.affectDesc:SetChecked(NysTDL.acedb.profile.affectDesc)

	--/************************************************/--

	menuframe.btnAddonOptions = widgets:Button("addonOptionsButton", menuframe, L["Open addon options"], "Interface\\Buttons\\UI-OptionsButton")
	menuframe.btnAddonOptions:SetPoint("TOP", menuframe.affectDesc, "TOP", 0, -55)
	menuframe.btnAddonOptions:SetScript("OnClick", function() if not optionsManager:ToggleOptions(true) then tdlFrame:Hide() end end)
end

function private:GenerateMenuTabActions()
	local menuframe = tdlFrame.content.menuFrames[enums.menus.tabact]

	--/************************************************/--

	-- title
	menuframe.menuTitle = widgets:NoPointsLabel(menuframe, nil, string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), private:SubMenuNameFormat(L["Tab actions"])))
	menuframe.menuTitle:SetPoint("CENTER", menuframe, "TOPLEFT", centerXOffset, 0)
	-- left/right lines
	menuframe.menuTitleLL = widgets:ThemeLine(menuframe, database.themes.theme, 0.7)
	menuframe.menuTitleLR = widgets:ThemeLine(menuframe, database.themes.theme, 0.7)
	private:SetDoubleLinePoints(menuframe.menuTitleLL, menuframe.menuTitleLR, menuframe.menuTitle:GetWidth(), 0)

	--/************************************************/--

	menuframe.btnCheck = widgets:Button("NysTDL_menuframe_btnCheck", menuframe, L["Check"], "Interface\\BUTTONS\\UI-CheckBox-Check")
	menuframe.btnCheck:SetPoint("TOP", menuframe.menuTitle, "TOP", 0, -35)
	menuframe.btnCheck:SetScript("OnClick", function() dataManager:ToggleTabChecked(database.ctab(), true) end)

	menuframe.btnUncheck = widgets:Button("NysTDL_menuframe_btnUncheck", menuframe, L["Uncheck"], "Interface\\BUTTONS\\UI-CheckBox-Check-Disabled")
	menuframe.btnUncheck:SetPoint("TOP", menuframe.btnCheck, "TOP", 0, -40)
	menuframe.btnUncheck:SetScript("OnClick", function() dataManager:ToggleTabChecked(database.ctab(), false) end)

	menuframe.btnCloseCat = widgets:Button("NysTDL_menuframe_btnCloseCat", menuframe, L["Close All"], "Interface\\BUTTONS\\Arrow-Up-Disabled")
	menuframe.btnCloseCat:SetPoint("TOP", menuframe.btnUncheck, "TOP", 0, -40)
	menuframe.btnCloseCat:SetScript("OnClick", function() dataManager:ToggleTabClosed(database.ctab(), false) end)

	menuframe.btnOpenCat = widgets:Button("NysTDL_menuframe_btnOpenCat", menuframe, L["Open All"], "Interface\\BUTTONS\\Arrow-Down-Up")
	menuframe.btnOpenCat:SetPoint("TOP", menuframe.btnCloseCat, "TOP", 0, -40)
	menuframe.btnOpenCat:SetScript("OnClick", function() dataManager:ToggleTabClosed(database.ctab(), true) end)

	menuframe.btnClear = widgets:Button("NysTDL_menuframe_btnClear", menuframe, L["Clear"], "Interface\\GLUES\\LOGIN\\Glues-CheckBox-Check")
	menuframe.btnClear:SetPoint("TOP", menuframe.btnOpenCat, "TOP", 0, -40)
	menuframe.btnClear:SetScript("OnClick", function() dataManager:ClearTab(database.ctab()) end)
end

function private:GenerateFrameContent()
	-- // generating the content (top to bottom)

	-- creating content, scroll child of ScrollFrame (everything will be inside of it)
	tdlFrame.content = CreateFrame("Frame", nil, tdlFrame.ScrollFrame)
	tdlFrame.content:SetSize(enums.tdlFrameDefaultWidth-30, 1) -- y is determined by the elements inside of it
	tdlFrame.ScrollFrame:SetScrollChild(tdlFrame.content)
	local content = tdlFrame.content

	-- title
	content.title = widgets:NoPointsLabel(content, nil, string.gsub(core.toc.title, "Ny's ", ""))
	content.title:SetPoint("CENTER", content, "TOPLEFT", centerXOffset, -18)
	content.title:SetFontObject("GameFontNormalLarge")
	-- left/right lines
	content.titleLL = widgets:ThemeLine(content, database.themes.theme_yellow, 0.8)
	content.titleLR = widgets:ThemeLine(content, database.themes.theme_yellow, 0.8)
	private:SetDoubleLinePoints(content.titleLL, content.titleLR, content.title:GetWidth(), -20)

	-- remaining numbers labels
	content.remaining = widgets:NoPointsLabel(content, nil, L["Remaining"]..":")
	content.remaining:SetPoint("LEFT", content.title, "TOP", -140, -40)
	content.remaining:SetFontObject("GameFontNormalLarge")
	content.remainingNumber = widgets:NoPointsLabel(content, nil, "...")
	content.remainingNumber:SetPoint("LEFT", content.remaining, "RIGHT", 3, 0)
	content.remainingNumber:SetFontObject("GameFontNormalLarge")
	content.remainingFavsNumber = widgets:NoPointsLabel(content, nil, "...")
	content.remainingFavsNumber:SetPoint("LEFT", content.remainingNumber, "RIGHT", 3, 0)
	content.remainingFavsNumber:SetFontObject("GameFontNormalLarge")

	-- help button
	content.helpButton = widgets:HelpButton(content)
	content.helpButton:SetPoint("RIGHT", content.title, "TOP", 140, -40)
	content.helpButton:SetScript("OnClick", function()
		SlashCmdList.NysTDL(L["info"])
		tutorialsManager:Validate("TM_introduction_getMoreInfo")
	end)
	tutorialsManager:SetPoint("TM_introduction_getMoreInfo", "LEFT", content.helpButton, "RIGHT", 18, 0)

	-- edit mode button
	content.editModeButton = widgets:IconTooltipButton(content, "NysTDL_EditModeButton", L["Toggle edit mode"])
	content.editModeButton:SetPoint("RIGHT", content.helpButton, "LEFT", 2, 0)
	content.editModeButton:SetScript("OnClick", function()
		tutorialsManager:Validate("TM_introduction_editmode") -- I need to place this here to be sure it was a user action
		mainFrame:ToggleEditMode()
	end)
	tutorialsManager:SetPoint("TM_introduction_editmode", "BOTTOM", content.editModeButton, "TOP", 0, 18)
	-- tutorialsManager:SetPoint("TM_editmode_editmodeBtn", "BOTTOM", content.editModeButton, "TOP", 0, 18) -- TDLATER

	-- frame options menu button
	content.frameOptionsButton = widgets:IconTooltipButton(content, "NysTDL_FrameOptionsButton", L["Frame options"])
	content.frameOptionsButton:SetPoint("RIGHT", content.editModeButton, "LEFT", 2, 0)
	content.frameOptionsButton:SetScript("OnClick", function()
		private:MenuClick(enums.menus.frameopt)
	end)
	tutorialsManager:SetPoint("TM_introduction_accessOptions", "BOTTOM", content.frameOptionsButton, "TOP", 0, 18)

	-- category menu button
	content.categoryButton = widgets:IconTooltipButton(content, "NysTDL_CategoryButton", L["Add a category"])
	content.categoryButton:SetPoint("RIGHT", content.frameOptionsButton, "LEFT", 2, 0)
	content.categoryButton:SetScript("OnClick", function()
		private:MenuClick(enums.menus.addcat)
	end)
	tutorialsManager:SetPoint("TM_introduction_addNewCat", "TOP", content.categoryButton, "BOTTOM", 0, -18)

	-- tab actions menu button
	content.tabActionsButton = widgets:IconTooltipButton(content, "NysTDL_TabActionsButton", L["Tab actions"])
	content.tabActionsButton:SetPoint("RIGHT", content.editModeButton, "LEFT", 2, 0)
	content.tabActionsButton:SetScript("OnClick", function()
		private:MenuClick(enums.menus.tabact)
	end)
	content.tabActionsButton:Hide()

	-- undo button
	content.undoButton = widgets:IconTooltipButton(content, "NysTDL_UndoButton", L["Undo last remove"].."\n".."("..L["Item"]:lower().."/"..L["Category"]:lower().."/"..L["Tab"]:lower()..")")
	content.undoButton:SetPoint("RIGHT", content.tabActionsButton, "LEFT", 2, 0)
	content.undoButton:SetScript("OnClick", function() dataManager:Undo() end)
	content.undoButton:Hide()
	tutorialsManager:SetPoint("TM_editmode_buttons", "BOTTOM", content.undoButton, "TOP", -15, 18)
	tutorialsManager:SetPoint("TM_editmode_undo", "BOTTOM", content.undoButton, "TOP", 0, 18)

	-- // menus
	local contentWidth, menuEnum = content:GetWidth()
	content.menuFrames = {
		-- these will be replaced in the code,
		-- but I'm putting them here just so I can remember how this table works
		-- --> selected = enums.menus.xxx,
		-- --> [enums.menus.xxx] = frame,
		-- --> [enums.menus.xxx] = frame,
		-- --> [enums.menus.xxx] = frame,
	}

	-- / add a category sub-menu

	menuEnum = enums.menus.addcat
	content.menuFrames[menuEnum] = CreateFrame("Frame", nil, tdlFrame.content)
	content.menuFrames[menuEnum]:SetPoint("TOPLEFT", tdlFrame.content, "TOPLEFT", 0, lineBottomY)
	content.menuFrames[menuEnum]:SetSize(contentWidth, 110) -- CVAL (coded value, non automatic)
	private:GenerateMenuAddACategory()

	-- / frame options sub-menu

	menuEnum = enums.menus.frameopt
	content.menuFrames[menuEnum] = CreateFrame("Frame", nil, tdlFrame.content)
	content.menuFrames[menuEnum]:SetPoint("TOPLEFT", tdlFrame.content, "TOPLEFT", 0, lineBottomY)
	content.menuFrames[menuEnum]:SetSize(contentWidth, 235) -- CVAL
	private:GenerateMenuFrameOptions()

	-- / tab actions sub-menu

	menuEnum = enums.menus.tabact
	content.menuFrames[menuEnum] = CreateFrame("Frame", nil, tdlFrame.content)
	content.menuFrames[menuEnum]:SetPoint("TOPLEFT", tdlFrame.content, "TOPLEFT", 0, lineBottomY)
	content.menuFrames[menuEnum]:SetSize(contentWidth, 240) -- CVAL
	private:GenerateMenuTabActions()

	-- below the menus
	content.lineBottom = widgets:ThemeLine(content, database.themes.theme, 0.7)

	content.nothingLabel = widgets:HintLabel(content, nil, L["Empty tab"].."\n\n"..L["Start by adding a new category!"])
	content.nothingLabel:SetPoint("TOP", content.lineBottom, "TOP", 0, -20)
	content.nothingLabel:SetWidth(220)

	content.hiddenLabel = widgets:HintLabel(content, nil, L["Completed tab"])
	content.hiddenLabel:SetPoint("TOP", content.lineBottom, "TOP", 0, -20)
	content.hiddenLabel:SetWidth(220)

	content.loadOrigin = widgets:Dummy(content, content.lineBottom, 0, 0)
	content.loadOrigin:SetPoint("TOPLEFT", content.lineBottom, "TOPLEFT", unpack(enums.loadOriginOffset))

	content.dummyBottomFrame = widgets:Dummy(content, content, 0, 0) -- this one if for putting a margin at the bottom of the content (mainly to leave space for the dropping of cat)
end

-- // Creating the main frame

function mainFrame:CreateTDLFrame()
	-- // we create the list

	-- background
	tdlFrame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false, tileSize = 1, edgeSize = 12,
		insets = { left = 2, right = 2, top = 2, bottom = 2 }
	})

	-- properties
	tdlFrame:EnableMouse(true)
	tdlFrame:SetMovable(true)
	tdlFrame:SetClampedToScreen(true)
	tdlFrame:SetResizable(true)
	tdlFrame:SetMinResize(90, 180)
	tdlFrame:SetMaxResize(600, 1000)
	tdlFrame:SetToplevel(true)

	tdlFrame:HookScript("OnUpdate", mainFrame.Event_TDLFrame_OnUpdate)
	tdlFrame:HookScript("OnShow", mainFrame.Event_TDLFrame_OnVisibilityUpdate)
	tdlFrame:HookScript("OnHide", mainFrame.Event_TDLFrame_OnVisibilityUpdate)
	tdlFrame:HookScript("OnSizeChanged", mainFrame.Event_TDLFrame_OnSizeChanged)
	tdlFrame:HookScript("OnMouseUp", function(self, button) -- toggle edit mode
		if button == "RightButton" then
			tutorialsManager:Validate("TM_introduction_editmode")
			mainFrame:ToggleEditMode()
		end
	end)

	-- to move the frame AND NOT HAVE THE PRB WITH THE RESIZE so it's custom moving
	tdlFrame.isMouseDown = false
	tdlFrame.hasMoved = false
	local function StopMoving(self)
		self.isMouseDown = false
		if self.hasMoved == true then
			self:StopMovingOrSizing()
			self.hasMoved = false
			local points, _ = NysTDL.acedb.profile.framePos, nil
			points.point, _, points.relativePoint, points.xOffset, points.yOffset = self:GetPoint()
		end
	end
	tdlFrame:HookScript("OnMouseDown", function(self, button)
		if not NysTDL.acedb.profile.lockList then
			if button == "LeftButton" then
				self.isMouseDown = true
				cursorX, cursorY = GetCursorPosition()
			end
		end
	end)
	tdlFrame:HookScript("OnMouseUp", StopMoving)
	tdlFrame:HookScript("OnHide", StopMoving)

	-- // CREATING THE CONTENT OF THE FRAME // --

	-- // scroll frame (almost everything will be inside of it using a scroll child frame, see private:GenerateFrameContent())

	tdlFrame.ScrollFrame = CreateFrame("ScrollFrame", nil, tdlFrame, "UIPanelScrollFrameTemplate")
	tdlFrame.ScrollFrame:SetPoint("TOPLEFT", tdlFrame, "TOPLEFT", 4, - 4)
	tdlFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", tdlFrame, "BOTTOMRIGHT", - 4, 4)
	tdlFrame.ScrollFrame:SetScript("OnMouseWheel", mainFrame.Event_ScrollFrame_OnMouseWheel)
	tdlFrame.ScrollFrame:SetClipsChildren(true)

	-- // outside the scroll frame

	-- scroll bar
	tdlFrame.ScrollFrame.ScrollBar:ClearAllPoints()
	tdlFrame.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", tdlFrame.ScrollFrame, "TOPRIGHT", - 12, - 38) -- the bottomright is updated in the OnUpdate (to manage the resize button)

	-- close button
	tdlFrame.closeButton = CreateFrame("Button", nil, tdlFrame, "NysTDL_CloseButton")
	tdlFrame.closeButton:SetPoint("TOPRIGHT", tdlFrame, "TOPRIGHT", -1, -1)
	tdlFrame.closeButton:SetScript("onClick", function(self) self:GetParent():Hide() end)

	-- resize button
	tdlFrame.resizeButton = CreateFrame("Button", nil, tdlFrame, "NysTDL_TooltipResizeButton")
	tdlFrame.resizeButton.tooltip = L["Left-Click"].." - "..L["Resize the list"].."\n"..L["Right-Click"].." - "..L["Reset"]
	tdlFrame.resizeButton:SetPoint("BOTTOMRIGHT", -3, 3)
	tdlFrame.resizeButton:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			tdlFrame:StartSizing("BOTTOMRIGHT")
			self:GetHighlightTexture():Hide() -- more noticeable
			self.Tooltip:Hide()
		end
	end)
	tdlFrame.resizeButton:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" then
			tdlFrame:StopMovingOrSizing()
			self:GetHighlightTexture():Show()
			self.Tooltip:Show()
		end
	end)
	tdlFrame.resizeButton:SetScript("OnHide", function(self)  -- same as on mouse up, just security
		tdlFrame:StopMovingOrSizing()
		self:GetHighlightTexture():Show()
	end)
	tdlFrame.resizeButton:RegisterForClicks("RightButtonUp")
	tdlFrame.resizeButton:HookScript("OnClick", function() -- reset size
		tdlFrame:SetSize(enums.tdlFrameDefaultWidth, enums.tdlFrameDefaultHeight)
	end)
	tutorialsManager:SetPoint("TM_editmode_resize", "LEFT", tdlFrame.resizeButton, "RIGHT", 0, 0)

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

	-- we reposition the frame
	local points = NysTDL.acedb.profile.framePos
	tdlFrame:ClearAllPoints()
	tdlFrame:SetPoint(points.point, nil, points.relativePoint, points.xOffset, points.yOffset) -- relativeFrame = nil -> entire screen

	-- and update its elements opacity
	mainFrame:Event_FrameAlphaSlider_OnValueChanged(NysTDL.acedb.profile.frameAlpha)
	mainFrame:Event_FrameContentAlphaSlider_OnValueChanged(NysTDL.acedb.profile.frameContentAlpha)
	-- as well as updating the elements needing an update
	local frameopt = tdlFrame.content.menuFrames[enums.menus.frameopt]
	frameopt.frameAlphaSlider:SetValue(NysTDL.acedb.profile.frameAlpha)
	frameopt.frameContentAlphaSlider:SetValue(NysTDL.acedb.profile.frameContentAlpha)
	frameopt.affectDesc:SetChecked(NysTDL.acedb.profile.affectDesc)

	-- we generate the widgets once
	private:LoadWidgets()

	-- we reset the edit mode state
	mainFrame:ToggleEditMode(false, true)

	--widgets:SetEditBoxesHyperlinksEnabled(true) -- see func details for why I'm not using it

	-- // and finally, we update the list's visibility

	local oldShownState = tdlFrame:IsShown()

	if NysTDL.acedb.profile.openByDefault then
		tdlFrame:Show()
	elseif NysTDL.acedb.profile.keepOpen then
		tdlFrame:SetShown(NysTDL.acedb.profile.lastListVisibility)
	else
		tdlFrame:Hide()
	end

	if oldShownState == tdlFrame:IsShown() then -- if we didn't change the list's shown state, we manually call Event_TDLFrame_OnVisibilityUpdate to refresh everything
		mainFrame:Event_TDLFrame_OnVisibilityUpdate()
	end
end
