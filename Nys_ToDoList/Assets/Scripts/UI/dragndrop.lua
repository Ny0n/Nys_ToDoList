--/*******************/ IMPORTS /*************************/--

-- File init

local dragndrop = NysTDL.dragndrop
NysTDL.dragndrop = dragndrop

-- Primary aliases

local enums = NysTDL.enums
local utils = NysTDL.utils
local database = NysTDL.database
local mainFrame = NysTDL.mainFrame
local dataManager = NysTDL.dataManager

--/*******************************************************/--

-- // Variables

local private = {}

dragndrop.dragging = false -- ez access
dragndrop.cancelling = false

-- DRY

local normalAlpha = 1
local selectedDimAlpha = 0 -- TDLATER glow
local forbiddenDimAlpha = 0.3

local catTopPos = { 4, enums.ofsyCat/2 }
local catBottomPos = { 4, -enums.ofsyCat/2 }
local catItemPos = { enums.ofsxContent, -enums.ofsyCatContent/2+4 }
local itemPos = { 0, -enums.ofsyContent/2+4 }
local itemCatPos = { -enums.ofsxContent+4, -enums.ofsyContentCat/2 }

-- drag&drop data

local draggingWidget
local targetDropFrame, newPos
local startingTab, currentTab

local dragUpdate = CreateFrame("Frame", nil, UIParent)
local dropLine
local minDist = 10000

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

function private:TestDist(dropFrame, cursorY)
	-- we get the distance between the given drop frame and the cursor,
	-- to determine which one is the closest to it

	local _, dropFrameY = dropFrame:GetCenter() -- LIST CS
	local targetDropFrameDist = math.abs(cursorY-dropFrameY) -- dist

	if targetDropFrameDist < minDist then -- new minimum?
		targetDropFrame = dropFrame
		minDist = targetDropFrameDist
	end
end

function private:CreateDuplicate(enum, ID)
	-- first in each drag, since we are stealing the widget we are dragging from the frame,
	-- we create a new one to replace it

	local contentWidgets = mainFrame:GetContentWidgets()
	contentWidgets[ID] = nil
	mainFrame:UpdateWidget(ID, enum)
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

	-- // let's go!

	minDist = 10000 -- we reset the dist to find the closest drop point each frame
	for _,dropFrame in pairs(dropFrames) do
		if dropFrame:IsVisible() then -- we only care about a drop point if we can see it
			private:TestDist(dropFrame, cursorY)
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
	do return false end -- TDLATER sub-cat drag&drop (fix (add) missing drop points (under sub-cats) & verify tab switch)

	-- returns false if:
	-- - (1) the targetCatID's original tab is different from the one we're currently dragging
	-- - (2) the targetCatID is a child of the category we're currently dragging
	if not draggingWidget or not targetCatID or draggingWidget.enum ~= enums.category then return false end -- luacheck: ignore

	local catData = select(3, dataManager:Find(targetCatID))

	-- (1)
	if draggingWidget.catData.originalTabID ~= catData.originalTabID then
		return false
	end

	-- (2)
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

function private:RecursiveUpdate(catWidget, w)
	local catID, catData, newDropFrame = catWidget.catID, catWidget.catData
	local contentWidgets = mainFrame:GetContentWidgets()

	if not catData.closedInTabIDs[currentTab] then -- if the cat is not closed
		newDropFrame = dragndrop:CreateDropFrame(catWidget, unpack(catItemPos)) -- /*item/*cat/ first pos, under the cat
		dragndrop:SetDropFrameData(newDropFrame, currentTab, catID, 1)
		tinsert(favsDropFrames, newDropFrame) -- favs can always be placed first
		if dataManager:GetNextFavPos(catID) == 1 then
			tinsert(itemsDropFrames, newDropFrame) -- and normal items only if there are no favs
		end
		if private:IsCatDropValid(catID) then
			tinsert(categoryDropFrames, newDropFrame)
		end

		-- content widgets loop
		for contentOrder,contentID in ipairs(catData.orderedContentIDs) do -- for everything in a base category
			local contentWidget = contentWidgets[contentID]
			w.lastWidget = contentWidget

			if not dataManager:IsHidden(contentID, currentTab) then -- if it's not hidden, we show the corresponding widget
				if contentWidget.enum == enums.category then -- sub-category
					private:RecursiveUpdate(contentWidget, w)
				elseif contentWidget.enum == enums.item then -- item
					newDropFrame = dragndrop:CreateDropFrame(contentWidget, unpack(itemPos)) -- /*item/*cat/ under each item/cat
					dragndrop:SetDropFrameData(newDropFrame, currentTab, catID, contentOrder+1)
					if contentWidget.itemData.favorite then
						tinsert(favsDropFrames, newDropFrame) -- we can always place a fav item below a fav item
						if dataManager:GetNextFavPos(catID) == contentOrder+1 then -- if it's the last fav in the cat, we can drop a normal item below it as well
							tinsert(itemsDropFrames, newDropFrame)
						end
					else
						tinsert(itemsDropFrames, newDropFrame) -- we can always place a normal item below a normal item
					end

					if private:IsCatDropValid(catID) then
						tinsert(categoryDropFrames, newDropFrame) -- we can place a category as a sub-cat anywhere, considering it's not inside itself
					end
				end
			end
		end
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
	local w = {
		lastWidget = nil,
	}

	-- // this is basically the same loop as the one in mainFrame,
	-- but instead of adding drag&drop code in that file,
	-- I prefer to put everything here

	-- I am looping on every widget in order,
	-- while figuring out every drop point, their data (pos), and UI positioning

	for catOrder,catID in ipairs(tabData.orderedCatIDs) do -- for every base category
		-- // categories
		local catWidget = contentWidgets[catID]
		w.lastWidget = catWidget

		local newDropFrame = dragndrop:CreateDropFrame(catWidget, unpack(catTopPos)) -- /*cat/ over each cat
		dragndrop:SetDropFrameData(newDropFrame, currentTab, nil, catOrder) -- no parent cat (base cat)
		tinsert(categoryDropFrames, newDropFrame)

		-- // content
		private:RecursiveUpdate(catWidget, w)
	end

	-- this part is specifically for the last category drop point (under the last shown item/cat)
	if w.lastWidget then
		local offset, catID
		if w.lastWidget.enum == enums.category then
			offset = catBottomPos
			catID = w.lastWidget.catID
		elseif w.lastWidget.enum == enums.item then
			offset = itemCatPos
			catID = w.lastWidget.itemData.catID
		end

		local newDropFrame = dragndrop:CreateDropFrame(w.lastWidget, unpack(offset)) -- /*cat/ under the last category
		dragndrop:SetDropFrameData(newDropFrame, currentTab, nil, dataManager:GetPosData(catID, nil, true)+1) -- no parent cat (base cat)
		tinsert(categoryDropFrames, newDropFrame)
	end
end

function dragndrop:CreateDropFrame(parent, ofsx, ofsy)
	-- here we get a drop frame (basically a drop point), or create one if it doesn't exist
	dropFrameNb = dropFrameNb + 1

	-- default values (just in case)
	parent = parent or UIParent
	ofsx = ofsx or 0
	ofsy = ofsy or 0

	-- create new or get next one
	local dropFrame
	if dropFramesBank[dropFrameNb] then
		dropFrame = dropFramesBank[dropFrameNb]
	else
		dropFrame = CreateFrame("Frame", nil, parent)
		dropFrame:SetSize(1, 1)
		dropFrame.dropData = {}

		tinsert(dropFramesBank, dropFrame)
	end

	dropFrame:ClearAllPoints()
	dropFrame:SetParent(parent)
	dropFrame:SetPoint("CENTER", parent, "CENTER", ofsx, ofsy) -- LIST CS
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

	-- when we are dragging a category, we dim every place we can't drag it to (for a visual feedback)
	local contentWidgets = mainFrame:GetContentWidgets()
	contentWidgets[draggingWidget.catID]:SetAlpha(selectedDimAlpha)
	for _,widget in pairs(contentWidgets) do
		if widget.enum == enums.item then
			widget:SetAlpha(forbiddenDimAlpha)
		end
	end

	-- selecting the right drop frames to check
	dropFrames = categoryDropFrames
end

function private:InitItemDrag()
	if not dragndrop.dragging then return end

	-- creating the duplicate, and getting the dragging's widget current position
	private:CreateDuplicate(enums.item, draggingWidget.itemID)

	-- hiding the buttons on the left of the dragging widget
	draggingWidget.editModeFrame:Hide()
	draggingWidget.removeBtn:Hide()
	draggingWidget.favoriteBtn:Hide()
	draggingWidget.descBtn:Hide()

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
	local widget = self:GetParent():GetParent()

	if widget.enum == enums.category then
		if not mainFrame.editMode then return end
	end

	-- drag init
	dragndrop.dragging = true

	-- vars reset & init
	dropFrames = nil
	lastCursorPosX = nil
	lastCursorPosY = nil
	tdlFrame = mainFrame:GetFrame()
	draggingWidget = widget
	targetDropFrame, newPos = nil, nil
	startingTab, currentTab = nil, nil
	dropLine = dropLine or CreateFrame("Frame", nil, tdlFrame.content, "NysTDL_DropLine") -- creating the drop line
	dropLine:SetScale(utils:Clamp(listScale, 0, 1)) -- we need to re-set the scale of the drop line here (for reasons)
	dropLine:Show()
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
	for _,widget in pairs(contentWidgets) do
		widget:SetAlpha(normalAlpha)
	end

	-- we hide the dragging widget, as well as the drop line
	if draggingWidget then draggingWidget:StopMovingOrSizing() draggingWidget:ClearAllPoints() draggingWidget:Hide() end
	if dropLine then dropLine:ClearAllPoints() dropLine:Hide() end

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

	local cursorX, cursorY = private:GetCursorScaledPosition() -- UIPARENT CS
	draggingWidget:ClearAllPoints()
	draggingWidget:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorX-ofsx, cursorY-ofsy) -- so we can snap the widget to the cursor at the same place that we clicked on (like a typical drag&drop)

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
	end)

	-- / stop
	dragFrame:HookScript("OnDragStop", private.DragStop)
end

function dragndrop:CancelDragging()
	if not dragndrop.dragging then return end

	dragndrop.cancelling = true
	local dragFrame = draggingWidget.interactiveLabel.Button
	dragFrame:GetScript("OnDragStop")(dragFrame)
	dragndrop.cancelling = false
end
