--/*******************/ IMPORTS /*************************/--

-- File init

local dragndrop = NysTDL.dragndrop
NysTDL.dragndrop = dragndrop

-- Primary aliases

local libs = NysTDL.libs
local enums = NysTDL.enums
local utils = NysTDL.utils
local widgets = NysTDL.widgets
local database = NysTDL.database
local mainFrame = NysTDL.mainFrame
local dataManager = NysTDL.dataManager

-- Secondary aliases
local L = libs.L
local LibQTip = libs.LibQTip

--/*******************************************************/--

-- // Variables

local private = {}

dragndrop.dragging = false -- ez access
dragndrop.cancelling = false

-- DRY

local normalAlpha = 1
local selectedDimAlpha = 0 -- TDLATER glow
local forbiddenDimAlpha = 0.3

local overHeightFrame = { 4, enums.ofsyContent/2+4 }
local underHeightFrame = { 4, -enums.ofsyContent/2+4 }
local overTabEmptyLabel = { -2, 2 } -- TDLATER TAB SWITCH

-- drag&drop data

local draggingWidget
local targetDropFrame, newPos
local startingTab, currentTab

local dragUpdate = CreateFrame("Frame", nil, UIParent)
local dropLine
local tooltip
local minDistY, minDistX = 10000, 10000

local clickX, clickY -- for a clean drag&grop
local listScale
local effectiveScale

local dropFrameNb = 0
local dropFramesBank = { -- IMPORTANT drop frames are basically drop points
	-- [1] = CreateDropFrame() (existing frame or new one),
	-- [2] = CreateDropFrame() (existing frame or new one),
	-- ...
}

local categoryDropFrames = {}
local favsDropFrames = {}
local itemsDropFrames = {}

-- private:dragUpdateFunc vars

local dropFrames
local lastCursorPosX, lastCursorPosY
local tdlFrame

-- // WoW & Lua APIs

local GetCursorPosition = GetCursorPosition
local pairs, next = pairs, next
local tinsert, tremove, unpack, wipe = table.insert, table.remove, unpack, wipe
local UIParent = UIParent
-- local CreateFrame = CreateFrame

--/***************/ MISC /*****************/--

function private:GetCursorScaledPosition()
	local scale, x, y = UIParent:GetScale(), GetCursorPosition()
	return x/scale, y/scale
end

function private:CreateDuplicate(enum, ID)
	-- first in each drag, since we are stealing the widget we are dragging from the frame,
	-- we create a new one to replace it

	local contentWidgets = mainFrame:GetContentWidgets()
	contentWidgets[ID] = nil
	mainFrame:UpdateWidget(ID, enum)

	-- dynamic content
	if enum == enums.category then
		contentWidgets[ID].addMode = draggingWidget.addMode
	end

	mainFrame:Refresh() -- IMPORTANT this refresh also acts as the call to UpdateDropFrames!

	-- after this, now that we are dragging a duplicate widget, and the list looks like nothing changed,
	-- we start the real dragging work
end

function private:DragUpdateFunc()
	-- // THE OnUpdate func that determines the drop point depending on the cursor's Y position

	if not tdlFrame:IsMouseOver() then
		dropLine:Hide()
		return
	end

	-- cursor current pos (Y)
	local scale, cursorX, cursorY = UIParent:GetScale()*listScale, GetCursorPosition()
	cursorX, cursorY = cursorX/scale, cursorY/scale -- LIST CS

	if lastCursorPosX == cursorX and lastCursorPosY == cursorY then return end -- no need for an update if we didn't move the cursor
	lastCursorPosX = cursorX
	lastCursorPosY = cursorY

	targetDropFrame = nil

	-- // let's go!

	-- we search the drop frame that is the closest to the cursor
	-- * the search takes priority depending on the Y component
	-- * if there are multiple drop frames that have the same Y component, we do another search through them based on the X component

	minDistY = 10000
	for _,dropFrame in pairs(dropFrames) do
		if dropFrame:IsVisible() then -- we only care about a drop point if we can see it
			local _,dropFrameY = dropFrame:GetCenter() -- LIST CS
			local targetDropFrameDist = math.abs(cursorY-dropFrameY) -- dist

			if targetDropFrameDist < minDistY then -- new minimum?
				minDistY = targetDropFrameDist
			end
		end
	end

	local found = {}
	for _,dropFrame in pairs(dropFrames) do
		if dropFrame:IsVisible() then -- we only care about a drop point if we can see it
			local _,dropFrameY = dropFrame:GetCenter() -- LIST CS
			local targetDropFrameDist = math.abs(cursorY-dropFrameY) -- dist

			if math.abs(targetDropFrameDist - minDistY) <= 1 then
				tinsert(found, dropFrame)
			end
		end
	end

	targetDropFrame = found[1]

	if #found > 1 then
		minDistX = 10000
		for _,dropFrame in pairs(found) do
			if dropFrame:IsVisible() then -- we only care about a drop point if we can see it
				local dropFrameX,_ = dropFrame:GetCenter() -- LIST CS
				local targetDropFrameDist = math.abs(cursorX-dropFrameX) -- dist

				if targetDropFrameDist < minDistX then -- new minimum?
					minDistX = targetDropFrameDist
					targetDropFrame = dropFrame
				end
			end
		end
	end

	if not targetDropFrame then return end -- just in case we didn't find anything

	-- now that we have the closest widget, we update the positions, so that we are ready for the drop
	dropLine:ClearAllPoints()
	dropLine:SetPoint("LEFT", targetDropFrame, "CENTER")
	dropLine:Show()
	newPos = targetDropFrame.dropData.pos
end

function private:IsCatDropValid(targetCatID)
	if not draggingWidget or not targetCatID or draggingWidget.enum ~= enums.category then return false end

	-- if the targetCatID is or is a child of the category we're currently dragging
	if utils:HasValue(dataManager:GetParents(targetCatID), draggingWidget.catID) then
		return false
	end

	return true
end

---To update the scale the dragndrop file.
function dragndrop:SetScale(scale)
	listScale = scale
end

--/***************/ DROP FRAMES /*****************/--

local rlHelperDeep = {
	-- [deep] = lastWidget,
	-- [deep] = lastWidget,
	-- [deep] = lastWidget,
}

local rlHelper = {
	deep = 0,
	lastWidget = nil, -- lastWidget from any deep

	SetDeep = function(self, deep)
		-- -- nil all lastWidget that are deeper than us when we are going up
		-- for d = #rlHelperDeep, 1, -1 do
		-- 	if d > deep then
		-- 		tremove(rlHelperDeep, d)
		-- 		d = d - 1
		-- 	end
		-- end

		-- nil all lastWidget that are as deep or deeper than us when we are going down
		if deep > self.deep then
			for d = #rlHelperDeep, 1, -1 do
				if d >= deep then
					tremove(rlHelperDeep, d)
					d = d - 1
				end
			end
		end

		self.deep = deep
	end,

	GetLastWidget = function(self)
		return rlHelperDeep[self.deep]
	end,

	GetLastWidgetFromDeep = function(self, deep)
		return rlHelperDeep[deep]
	end,

	GetLastWidgetDeepest = function(self)
		return rlHelperDeep[#rlHelperDeep]
	end,

	SetLastWidget = function(self, widget)
		rlHelperDeep[self.deep] = widget
		self.lastWidget = widget
	end,
}

function private:RecursiveUpdate(catWidget)
	local catID, catData = catWidget.catID, catWidget.catData
	local contentWidgets = mainFrame:GetContentWidgets()

	if catData.closedInTabIDs[currentTab] then -- if the cat is not closed
		return
	end

	rlHelper:SetDeep(rlHelper.deep + 1)
	local deep = rlHelper.deep

	-- content widgets loop
	for contentOrder,contentID in ipairs(catData.orderedContentIDs) do -- for everything in a base category
		if not dataManager:IsHidden(contentID, currentTab) then -- since we are in edit mode when drag & dropping, this line doesn't really matter
			local contentWidget = contentWidgets[contentID]

			rlHelper:SetDeep(deep)
			rlHelper:SetLastWidget(contentWidget)

			-- drop frame over the widget
			dragndrop:CreateDropFrame(0, currentTab, catID, contentOrder)

			if contentWidget.enum == enums.category then -- sub-category
				private:RecursiveUpdate(contentWidget)
			end
		end
	end

	rlHelper:SetDeep(deep)

	if not rlHelper:GetLastWidget() then
		-- if there was nothing in the category, we add one drop frame over the empty label
		rlHelper:SetLastWidget(catWidget.emptyLabel)
		dragndrop:CreateDropFrame(0, currentTab, catID, 1)
	else
		-- drop frame after the last widget, in last position
		dragndrop:CreateDropFrame(1, currentTab, catID, #catData.orderedContentIDs+1)
	end
end

function dragndrop:UpdateDropFrames()
	-- this is done once, each time we start a new drag&drop
	-- OR we are dragging&dropping and there is a frame refresh

	-- getting the data
	local tabID, tabData = database.ctab(), select(3, dataManager:Find(database.ctab()))

	if startingTab == nil then
		startingTab = tabID
	end
	currentTab = tabID

	-- resetting the drop frames, before updating them
	wipe(categoryDropFrames)
	wipe(favsDropFrames)
	wipe(itemsDropFrames)

	dropFrameNb = 0
	local contentWidgets = mainFrame:GetContentWidgets()

	rlHelper.deep = 0
	wipe(rlHelperDeep)

	-- // this is basically the same loop as the one in mainFrame,
	-- but instead of adding drag&drop code in that file,
	-- I prefer to put everything here

	-- I am looping on every widget in order,
	-- while figuring out every drop point, their data (pos), and UI positioning

	for catOrder,catID in ipairs(tabData.orderedCatIDs) do -- for every base category
		if not dataManager:IsHidden(catID, currentTab) then
			local catWidget = contentWidgets[catID]

			rlHelper:SetDeep(0)
			rlHelper:SetLastWidget(catWidget)

			-- drop frame over the widget
			dragndrop:CreateDropFrame(0, currentTab, nil, catOrder)

			-- // content
			private:RecursiveUpdate(catWidget)
		end
	end

	rlHelper:SetDeep(0)

	if not rlHelper:GetLastWidget() then
		-- if there was nothing in the tab, we add one drop frame over the empty label
		dragndrop:CreateDropFrame(2, currentTab, nil, 1)
	else
		-- drop frame after the last widget, in last position
		dragndrop:CreateDropFrame(1, currentTab, nil, #tabData.orderedCatIDs+1)
	end
end

---@param mode number ; 0 = over lastWidget's height frame, 1 = under lastWidget's height frame (or if opened category, under it), 2 = over empty label (of tab)
function dragndrop:CreateDropFrame(mode, tabID, catID, pos)
	mode = type(mode) == "number" and mode or 2

	-- here we get a drop frame (basically a drop point), or create one if it doesn't exist
	dropFrameNb = dropFrameNb + 1

	-- create new or get next one
	local dropFrame
	if dropFramesBank[dropFrameNb] then
		dropFrame = dropFramesBank[dropFrameNb]
	else
		dropFrame = CreateFrame("Frame", nil, tdlFrame.content, "NysTDL_DropFrame")
		dropFrame:SetSize(1, 1)
		dropFrame:Hide()
		dropFrame.dropData = {}

		tinsert(dropFramesBank, dropFrame)
	end

	dropFrame:ClearAllPoints()

	local parent = rlHelper:GetLastWidget()

	if mode == 0 then
		-- / over the last widget's height frame
		dropFrame:SetPoint("CENTER", parent.heightFrame, "TOPLEFT", unpack(overHeightFrame)) -- LIST CS
	elseif mode == 1 then
		if parent.enum == enums.category and not parent.catData.closedInTabIDs[currentTab] then
			-- / under the last widget, which is an opened category
			dropFrame:SetPoint("LEFT", parent.heightFrame, "LEFT", underHeightFrame[1], 0) -- LIST CS
			local lastWidget = (rlHelper.lastWidget and rlHelper.lastWidget.heightFrame) and rlHelper.lastWidget.heightFrame or rlHelper.lastWidget
			dropFrame:SetPoint("TOP", lastWidget, "BOTTOM", 0, underHeightFrame[2]) -- LIST CS
		else
			-- / under the last widget's height frame
			dropFrame:SetPoint("CENTER", parent.heightFrame, "BOTTOMLEFT", unpack(underHeightFrame)) -- LIST CS
		end
	elseif mode == 2 then
		-- / over the tab empty label
		dropFrame:SetPoint("CENTER", tdlFrame.content.nothingLabel, "TOPLEFT", unpack(overTabEmptyLabel)) -- LIST CS
	else
		print("Error: dragndrop:CreateDropFrame #1 - invalid mode")
		return
	end

	dragndrop:SetDropFrameData(dropFrame, tabID, catID, pos)

	if catID then -- if we are inside a category
		if dataManager:GetNextFavPos(catID) <= pos then
			tinsert(itemsDropFrames, dropFrame)

			if private:IsCatDropValid(catID) then
				tinsert(categoryDropFrames, dropFrame)
			end
		end
		if dataManager:GetNextFavPos(catID) >= pos then
			tinsert(favsDropFrames, dropFrame)
		end
	else -- if we are at the root
		tinsert(categoryDropFrames, dropFrame)
	end

	return dropFrame
end

function dragndrop:SetDropFrameData(frame, tabID, catID, pos)
	-- each drop frame has all the data necessary to understand where it is,
	-- so that I don't have to find out the drop pos again at drop time
	if not frame or not frame.dropData then return end

	frame.dropData.tabID = tabID
	frame.dropData.catID = catID
	frame.dropData.pos = pos
end

--/***************/ DRAGGING /*****************/--

function private:InitCategoryDrag()
	if not dragndrop.dragging then return end

	-- creating the duplicate, and getting the dragging's widget current position
	private:CreateDuplicate(enums.category, draggingWidget.catID)

	-- hiding the unnecessary things
	draggingWidget.interactiveLabel.Text:SetTextColor(unpack(draggingWidget.color)) -- back to the default color
	draggingWidget.interactiveLabel.Button:SetHighlightShown(false)
	draggingWidget.emptyLabel:Hide()
	draggingWidget.hiddenLabel:Hide()
	draggingWidget.hoverFrame:Hide()
	draggingWidget.favsRemainingLabel:Hide()
	draggingWidget.originalTabLabel:Hide()
	draggingWidget.addEditBox:Hide()
	draggingWidget.editModeFrame:Hide()
	draggingWidget.tabulation:Hide()

	-- when we are dragging a category, we dim every place we can't drag it to (for a visual feedback)
	local contentWidgets = mainFrame:GetContentWidgets()
	do
		-- keep some things bound to the widget visible even though the widget will be hidden
		local widget = contentWidgets[draggingWidget.catID]
		local widgetParent = widget:GetParent()
		widget.tabulation:SetParent(widgetParent)
		widget.addEditBox:SetParent(widgetParent)
		widget.emptyLabel:SetParent(widgetParent)
	end
	for _,widget in pairs(contentWidgets) do
		if widget.enum == enums.item then
			if widget.itemData.favorite then
				widget:SetAlpha(forbiddenDimAlpha)
			end
		elseif widget.enum == enums.category then
			if not private:IsCatDropValid(widget.catID) then
				widget:SetAlpha(forbiddenDimAlpha)
				if widget.catID == draggingWidget.catID then
					widget.tabulation:SetAlpha(forbiddenDimAlpha)
					widget.emptyLabel:SetAlpha(forbiddenDimAlpha)
					widget.addEditBox:SetAlpha(forbiddenDimAlpha)
				end
				for _,contentID in pairs(widget.catData.orderedContentIDs) do
					local cwidget = contentWidgets[contentID]
					cwidget:SetAlpha(forbiddenDimAlpha)
				end
			elseif dataManager:GetNextFavPos(widget.catID) ~= 1 then
				widget.addEditBox:SetAlpha(forbiddenDimAlpha)
			end
		end
	end
	contentWidgets[draggingWidget.catID]:SetAlpha(selectedDimAlpha)

	-- selecting the right drop frames to check
	dropFrames = categoryDropFrames
end

function private:InitItemDrag()
	if not dragndrop.dragging then return end

	-- creating the duplicate, and getting the dragging's widget current position
	private:CreateDuplicate(enums.item, draggingWidget.itemID)

	-- hiding the unnecessary things
	draggingWidget.interactiveLabel.Button:SetHighlightShown(false)
	draggingWidget.editModeFrame:Hide()

	-- when we are dragging an item, we dim every place we can't drag it to (for a visual feedback)
	local contentWidgets = mainFrame:GetContentWidgets()
	contentWidgets[draggingWidget.itemID]:SetAlpha(selectedDimAlpha)
	for _,widget in pairs(contentWidgets) do
		if widget.enum == enums.category then
			-- widget:SetAlpha(forbiddenDimAlpha)
		elseif widget.enum == enums.item then
			if draggingWidget.itemData.favorite then
				if not widget.itemData.favorite then
					widget:SetAlpha(forbiddenDimAlpha)
				end
			else
				if widget.itemData.favorite then
					widget:SetAlpha(forbiddenDimAlpha)
				end
			end
		end
	end

	-- selecting the right drop frames to check
	if draggingWidget.itemData.favorite then
		dropFrames = favsDropFrames
	else
		dropFrames = itemsDropFrames
	end
end

--/***************/ DROPPING /*****************/--

function private:DropCategory()
	-- the drop data is constantly updated while dragging,
	-- now we do the actual dropping
	if not dragndrop.dragging or dragndrop.cancelling then return end
	if not targetDropFrame then return end -- just in case we didn't find anything
	if not mainFrame:GetFrame():IsMouseOver() then return end -- we cancel the drop if we were out of the frame

	local newParentID = targetDropFrame.dropData.catID or false
	mainFrame:DontRefreshNextTime()
	dataManager:MoveCategory(draggingWidget.catID, newPos, newParentID, startingTab, currentTab)
end

function private:DropItem()
	-- the drop data is constantly updated while dragging,
	-- now we do the actual dropping
	if not dragndrop.dragging or dragndrop.cancelling then return end
	if not targetDropFrame then return end -- just in case we didn't find anything
	if not mainFrame:GetFrame():IsMouseOver() then return end -- we cancel the drop if we were out of the frame

	local targetCat = targetDropFrame.dropData.catID
	mainFrame:DontRefreshNextTime()
	dataManager:MoveItem(draggingWidget.itemID, newPos, targetCat)
end

--/***************/ START&STOP /*****************/--

function private:DragStart()
	if not mainFrame.editMode then return end

	-- drag init
	dragndrop.dragging = true

	-- vars reset & init
	dropFrames = nil
	lastCursorPosX = nil
	lastCursorPosY = nil
	tdlFrame = mainFrame:GetFrame()
	draggingWidget = self:GetParent():GetParent()
	targetDropFrame, newPos = nil, nil
	startingTab, currentTab = nil, nil
	dropLine = dropLine or CreateFrame("Frame", nil, tdlFrame.content, "NysTDL_DropLine") -- creating the drop line
	dropLine:SetFrameStrata("HIGH")
	dropLine:SetScale(utils:Clamp(listScale, 0, 1)) -- we need to re-set the scale of the drop line here (for reasons)
	dropLine:Show()

	if tooltip then
		LibQTip:Release(tooltip)
		tooltip = nil
	end

	-- NysTDL.libs.AceTimer:ScheduleTimer(function() -- TDLATER TAB SWITCH
	-- 	local id = dataManager:FindFirstIDByName("tab1", enums.tab, true)
	-- 	mainFrame:ChangeTab(id)
	-- end, 3)
end

function private:DragStop()
	if not dragndrop.dragging then return end

	dragndrop.dragging = false

	-- // we reset everything

	-- debug stuff -- REMOVE
	-- if targetDropFrame then
	--   print ("--------- Drop data: ----------")
	--   print ("tab", targetDropFrame.dropData.tabID and dataManager:GetName(targetDropFrame.dropData.tabID) or nil)
	--   print ("cat", targetDropFrame.dropData.catID and dataManager:GetName(targetDropFrame.dropData.catID) or nil)
	--   print ("pos", targetDropFrame.dropData.pos)
	--   print ("-------------------------------")
	-- end

	-- we reset the alpha states
	local contentWidgets = mainFrame:GetContentWidgets()
	if draggingWidget.enum == enums.category then
		local widget = contentWidgets[draggingWidget.catID]
		widget.tabulation:SetParent(widget)
		widget.addEditBox:SetParent(widget)
		widget.emptyLabel:SetParent(widget)
	end
	for _,widget in pairs(contentWidgets) do
		widget:SetAlpha(normalAlpha)
		if widget.enum == enums.category then
			widget.tabulation:SetAlpha(normalAlpha)
			widget.addEditBox:SetAlpha(normalAlpha)
			widget.emptyLabel:SetAlpha(normalAlpha)
		end
	end

	-- we hide the dragging widget, as well as the drop line and drop frames
	if draggingWidget then draggingWidget:StopMovingOrSizing() draggingWidget:ClearAllPoints() draggingWidget:Hide() end
	if dropLine then dropLine:ClearAllPoints() dropLine:Hide() end
	for _,frame in pairs(dropFramesBank) do
		if frame then frame:Hide() end
	end

	-- we stop the dragUpdate
	dragUpdate:SetScript("OnUpdate", nil)

	-- // refresh the mainFrame
	mainFrame:Refresh()
end

function private:DragMouseDown()
	-- this is for snapping the widget on the cursor, where we started to drag it
	clickX, clickY = private:GetCursorScaledPosition() -- UIPARENT CS
end

function private:DragMouseStart()
	if not dragndrop.dragging then return end

	-- we snap the one we are dragging to the current cursor position,
	-- where the widget was first clicked on before the drag, and we start moving it
	-- (it is a dummy widget, perfect duplicate just for a visual feedback, but it doesn't actually do anything)

	-- !! I am using this custom snapping and NOT using the default drag's StartMoving and StopMovingOrSizing snap because
	-- !! it simply doesn't work for different frames. when dragging we are clicking on the button of the interactiveLabel of the widget,
	-- !! but the drag needs to be moving the entire widget --> it simply doesn't know where the original click was since it was on a sub-frame
	-- (maaaaybe there was an other solution that I don't know of, but whatever :D)

	draggingWidget:SetParent(UIParent) -- PARENT SWITCH !! IMPORTANT TO TAKE THIS INTO ACCOUNT FOR THE SCALE (LIST CS | UIPARENT CS) (CS = Coordinate Space)
	draggingWidget:SetScale(listScale) -- since switching parents changed the scale, we set it again to copy the list's widgets

	local widgetX, widgetY = draggingWidget:GetCenter() -- UIPARENT CS
	local ofsx, ofsy = clickX - widgetX, clickY - widgetY -- here we take the offset between the original click's pos (dragMouseDown) and the widget's center

	-- update points of the interactive label (valid for item & cat widgets)
	local width = draggingWidget.interactiveLabel:GetWidth()
	draggingWidget.interactiveLabel:ClearAllPoints()
	draggingWidget.interactiveLabel:SetPoint("LEFT", draggingWidget.interactiveLabel.pointLeft, "RIGHT", 0, 0)
	draggingWidget.interactiveLabel:SetWidth(width)

	local cursorX, cursorY = private:GetCursorScaledPosition() -- UIPARENT CS
	draggingWidget:ClearAllPoints()
	draggingWidget:SetPoint("CENTER", nil, "BOTTOMLEFT", cursorX-ofsx, cursorY-ofsy) -- so we can snap the widget to the cursor at the same place that we clicked on (like a typical drag&drop)

	draggingWidget:StartMoving()
	draggingWidget:SetUserPlaced(false)
	draggingWidget:SetToplevel(true)
	draggingWidget:Raise()
end

function dragndrop:RegisterForDrag(widget)
	-- drag properties
	widget:EnableMouse(true)
	widget:SetMovable(true)

	-- we detect the dragging on the label of the widget
	local dragFrame = widget.interactiveLabel.Button

	-- // drag scripts

	-- / register
	dragFrame:RegisterForDrag("LeftButton")

	-- / start
	dragFrame:SetScript("OnDragStart", private.DragStart)
	dragFrame:HookScript("OnMouseDown", private.DragMouseDown)
	dragFrame:HookScript("OnDragStart", private.DragMouseStart)

	-- specific
	if widget.enum == enums.category then
		dragFrame:HookScript("OnDragStart", private.InitCategoryDrag)
		dragFrame:SetScript("OnDragStop", private.DropCategory)
	elseif widget.enum == enums.item then
		dragFrame:HookScript("OnDragStart", private.InitItemDrag)
		dragFrame:SetScript("OnDragStop", private.DropItem)
	end

	dragFrame:HookScript("OnDragStart", function()
		if not dragndrop.dragging then return end

		-- and finally, when everything is set up, we start the drop update managment
		dragUpdate:SetScript("OnUpdate", private.DragUpdateFunc)

		-- show the selected drop frames
		for _,frame in pairs(dropFrames) do
			if frame then frame:Show() end
		end
	end)

	-- TODO DEBUG
	dragFrame:HookScript("OnClick", function(self, button)
		if button == "RightButton" then
			print("-------------------")
			if widget.enum == enums.item then
				print("*** <item>")
				print("** NAME = "..dataManager:GetName(widget.itemID))
				print("* orig.tab = "..dataManager:GetName(widget.itemData.originalTabID))
				for k,v in pairs(widget.itemData.tabIDs) do
					if v then
						print(dataManager:GetName(k))
					end
				end
			else
				print("*** <category>")
				print("** NAME = "..dataManager:GetName(widget.catID))
				print("* orig.tab = "..dataManager:GetName(widget.catData.originalTabID))
				for k,v in pairs(widget.catData.tabIDs) do
					if v then
						print("- "..dataManager:GetName(k))
					end
				end
			end
		end
	end)
	dragFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	-- / stop
	dragFrame:HookScript("OnDragStop", private.DragStop)

	-- / display
	dragFrame:HookScript("OnEnter", function(self)
		if dragndrop.dragging or not mainFrame.editMode then return end
		dragFrame:SetHighlightShown(true)

        -- <!> tooltip content <!>

        tooltip = widgets:AcquireTooltip("NysTDL_Tooltip_DragAndDrop", self)

		tooltip:SetFont("GameTooltipText")

		tooltip:ClearAllPoints()
		tooltip:SetPoint("BOTTOMLEFT", self, "TOPLEFT", -5, 2)

		tooltip:AddLine(string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), L["Double-Click"])..utils:GetMinusStr()..L["Rename"])
		tooltip:AddLine(string.format("|cff%s%s|r", utils:RGBToHex(database.themes.theme), L["Drag and Drop"])..utils:GetMinusStr()..L["Reorder"])
	end)
	dragFrame:HookScript("OnLeave", function(self)
		if dragFrame:IsHighlightShown() then
			dragFrame:SetHighlightShown(false)
		end

		if tooltip then
			LibQTip:Release(tooltip)
			tooltip = nil
		end
	end)
end

function dragndrop:CancelDragging()
	if not dragndrop.dragging then return end

	dragndrop.cancelling = true
	local dragFrame = draggingWidget.interactiveLabel.Button
	dragFrame:GetScript("OnDragStop")(dragFrame)
	dragndrop.cancelling = false
end
