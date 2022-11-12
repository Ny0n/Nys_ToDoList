--/*******************/ IMPORTS /*************************/--

-- File init

local widgets = NysTDL.widgets
NysTDL.widgets = widgets

-- Primary aliases

local libs = NysTDL.libs
local core = NysTDL.core
local utils = NysTDL.utils
local enums = NysTDL.enums
local database = NysTDL.database
local dragndrop = NysTDL.dragndrop
local mainFrame = NysTDL.mainFrame
local tabsFrame = NysTDL.tabsFrame
local databroker = NysTDL.databroker
local dataManager = NysTDL.dataManager
local tutorialsManager = NysTDL.tutorialsManager

-- Secondary aliases

local L = libs.L
local LibQTip = libs.LibQTip
local AceTimer = libs.AceTimer

--/*******************************************************/--

widgets.frame = CreateFrame("Frame", nil, UIParent) -- utility frame
local widgetsFrame = widgets.frame

local private = {}

local tdlButton
local hyperlinkEditBoxes = {}
local descFrames = { -- all opened description frames
	-- [itemID] = frame,
	-- ...
}
local descFrameInfo = {
	width = 180,
	height = 110,
	buttons = 75, -- the additional space to account for the buttons at the right of the title
	font = "ChatFontNormal"
}

local updateRate = 0.05
local refreshRate = 1

-- // WoW & Lua APIs

-- local PlaySound = PlaySound -- TDLATER
-- local CreateFrame = CreateFrame -- breaks external hooks?
local UIParent = UIParent
local select = select

--/*******************/ MISC /*************************/--

-- // hyperlink edit boxes

function widgets:AddHyperlinkEditBox(editBox)
	table.insert(hyperlinkEditBoxes, editBox)
end

function widgets:RemoveHyperlinkEditBox(editBox)
	table.remove(hyperlinkEditBoxes, select(2, utils:HasValue(hyperlinkEditBoxes, editBox))) -- removing the ref of the hyperlink edit box
end

function widgets:SetEditBoxesHyperlinksEnabled(enabled)
	-- IMPORTANT: this code is to activate hyperlink clicks in edit boxes such as the ones for adding new items in categories,
	-- I disabled this for practical reasons: it's easier to write new item names in them if we can click on the links without triggering the hyperlink (and it's not very useful anyways :D).

	for _, editBox in pairs(hyperlinkEditBoxes) do
		widgets:SetHyperlinksEnabled(editBox, enabled)
	end
end

function widgets:EditBoxInsertLink(text)
	-- when we shift-click on things, we hook the link from the chat function,
	-- and add it to the one of my edit boxes who has the focus (if there is one)
	-- basically, it's what allows hyperlinks in my addon edit boxes
	for _, v in pairs(hyperlinkEditBoxes) do
		if v and v:IsVisible() and v:HasFocus() then
			v:Insert(text)
			return true
		end
	end
end

-- // description frames

function widgets:SetDescFramesAlpha(alpha)
	-- first we update (or not) the saved variable
	if NysTDL.acedb.profile.affectDesc then
		NysTDL.acedb.profile.descFrameAlpha = alpha
	end

	-- and then we update the alpha
	alpha = NysTDL.acedb.profile.descFrameAlpha/100
	for _, descFrame in pairs(descFrames) do -- we go through every desc frame
		descFrame:SetBackdropColor(0, 0, 0, alpha)
		descFrame:SetBackdropBorderColor(1, 1, 1, alpha)
		for k, x in pairs(descFrame.descriptionEditBox) do
			-- setting the backdrop alpha is not enough, we also have to change the alpha of the big edit box,
			-- the thing is that this template (from WoW) uses A LOT of sub-frames to make up that edit box,
			-- as well as other frames for the char count, etc, so we have to find all of the edit box frames,
			-- and set the alpha for each one
			if type(k) == "string" then
				if string.sub(k, k:len()-2, k:len()) == "Tex" then -- fortunately, they all end up with the letters "Tex" ("LeftTex", "RightTex", ...)
					x:SetAlpha(alpha)
				end
			end
		end
	end
end

function widgets:SetDescFramesContentAlpha(alpha)
	-- first we update (or not) the saved variable
	if NysTDL.acedb.profile.affectDesc then
		NysTDL.acedb.profile.descFrameContentAlpha = alpha
	end

	-- and then we update the alpha
	alpha = NysTDL.acedb.profile.descFrameContentAlpha/100
	for _, descFrame in pairs(descFrames) do -- we go through every desc frame
		descFrame.title:SetAlpha(alpha)
		descFrame.closeButton:SetAlpha(alpha)
		descFrame.clearButton:SetAlpha(alpha)
		descFrame.descriptionEditBox.EditBox:SetAlpha(alpha)
		descFrame.descriptionEditBox.ScrollBar:SetAlpha(alpha)
		descFrame.resizeButton:SetAlpha(alpha)
	end
end

function widgets:UpdateDescFramesTitle()
	-- refreshes the name & name color of each description frame
	-- (also useful to update the names when renaming items)
	local contentWidgets = mainFrame:GetContentWidgets()
	for _, descFrame in pairs(descFrames) do -- we go through each of them
		if contentWidgets[descFrame.itemID] then -- if the corresponding item still exists (i'm not sure if it's necessary, but it's just there in case it is)
			descFrame.title:SetText(descFrame.itemData.name)
			descFrame.title:SetTextColor(contentWidgets[descFrame.itemID].interactiveLabel.Text:GetTextColor())
			descFrame.title:SetAlpha(NysTDL.acedb.profile.descFrameContentAlpha/100)

			local w = widgets:GetWidth(descFrame.itemData.name)

			if descFrame.SetResizeBounds then
				descFrame:SetResizeBounds(math.max(180+75, w+75), 110)
			else
				descFrame:SetMinResize(math.max(180+75, w+75), 110)
			end

			if descFrame:GetWidth() < w+75 then
				descFrame:SetSize(w+75, 110)
			end
		end
	end
end

function widgets:DescFrameHide(itemID)
	-- we hide and delete the description frame of itemID if it exists
	local frame = descFrames[itemID]

	if frame then
		frame:Hide()
		frame:ClearAllPoints()
		widgets:RemoveHyperlinkEditBox(frame.descriptionEditBox.EditBox)
		descFrames[itemID] = nil
		return true
	end

	return false
end

function widgets:WipeDescFrames()
	-- resets every desc frame
	for _, frame in pairs(descFrames) do
		frame:Hide()
		frame:ClearAllPoints()
		widgets:RemoveHyperlinkEditBox(frame.descriptionEditBox.EditBox)
	end
	wipe(descFrames)
end

function widgets:DescriptionFrame(itemWidget)
	-- // the big function to create the description frame for each item

	local itemID = itemWidget.itemID
	local itemData = select(3, dataManager:Find(itemID))

	-- first we check if it's already opened, in which case we act as a toggle, and hide it
	if widgets:DescFrameHide(itemID) then return end

	-- // creating the frame and all of its content

	-- we create the mini frame holding the name of the item and his description in an edit box
	local descFrame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	local w = widgets:GetWidth(itemData.name)
	descFrame:SetSize(w < descFrameInfo.width and descFrameInfo.width+descFrameInfo.buttons or w+descFrameInfo.buttons, descFrameInfo.height)

	-- background
	descFrame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false, tileSize = 1, edgeSize = 10,
		insets = { left = 2, right = 2, top = 2, bottom = 2 }
	})
	descFrame:SetBackdropColor(0, 0, 0, 1)

	-- quick access
	descFrame.itemID = itemID
	descFrame.itemData = itemData

	-- properties
	descFrame:EnableMouse(true)
	descFrame:SetMovable(true)
	descFrame:SetClampedToScreen(true)
	descFrame:SetResizable(true)
	if descFrame.SetResizeBounds then
		descFrame:SetResizeBounds(descFrame:GetWidth(), descFrame:GetHeight())
	else
		descFrame:SetMinResize(descFrame:GetWidth(), descFrame:GetHeight())
	end
	descFrame:SetToplevel(true)
	widgets:SetHyperlinksEnabled(descFrame, true)

	-- frame vars
	descFrame.opening = 0 -- for the scrolling up on opening

	-- to move the frame
	descFrame:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			self:StartMoving()
		end
	end)
	descFrame:SetScript("OnMouseUp", descFrame.StopMovingOrSizing)

	-- OnUpdate script
	descFrame:SetScript("OnUpdate", function(self)
		-- we update non-stop the width of the description edit box to match that of the frame if we resize it, and when the scrollbar kicks in. (this is the secret to make it work)
		self.descriptionEditBox.EditBox:SetWidth(self.descriptionEditBox:GetWidth() - (self.descriptionEditBox.ScrollBar:IsShown() and 15 or 0))

		if self.opening < 5 then -- doing this only on the 5 first updates after creating the frame, I won't go into the details but updating the vertical scroll of this template is a real fucker :D
			self.descriptionEditBox:SetVerticalScroll(0)
			self.opening = self.opening + 1
		end
	end)

	-- position
	descFrame:SetPoint("BOTTOMRIGHT", itemWidget.descBtn, "TOPRIGHT", 0, 0) -- we spawn it basically where we clicked

	-- to unlink it from the itemWidget
	descFrame:StartMoving()
	descFrame:StopMovingOrSizing()

	-- / content of the frame / --

	-- / resize button
	descFrame.resizeButton = CreateFrame("Button", nil, descFrame, "NysTDL_ResizeButton")
	descFrame.resizeButton:SetPoint("BOTTOMRIGHT")
	descFrame.resizeButton:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			descFrame:StartSizing("BOTTOMRIGHT")
			self:GetHighlightTexture():Hide() -- more noticeable
		end
	end)
	descFrame.resizeButton:SetScript("OnMouseUp", function(self)
		descFrame:StopMovingOrSizing()
		self:GetHighlightTexture():Show()
	end)

	-- / close button
	descFrame.closeButton = CreateFrame("Button", nil, descFrame, "NysTDL_CloseButton")
	descFrame.closeButton:SetPoint("TOPRIGHT", descFrame, "TOPRIGHT", -2, -2)
	descFrame.closeButton:SetScript("OnClick", function() widgets:DescFrameHide(itemID) end)

	-- / clear button
	descFrame.clearButton = widgets:IconTooltipButton(descFrame, "NysTDL_ClearButton", L["Clear"].."\n("..L["Right-Click"]..")")
	descFrame.clearButton:SetPoint("TOPRIGHT", descFrame, "TOPRIGHT", -24, -2)
	descFrame.clearButton:RegisterForClicks("RightButtonUp") -- only responds to right-clicks
	descFrame.clearButton:SetScript("OnClick", function(self)
		self:GetParent().descriptionEditBox.EditBox:SetText("")
	end)

	-- / item label
	descFrame.title = descFrame:CreateFontString(nil)
	descFrame.title:SetFontObject("GameFontNormalLarge")
	descFrame.title:SetPoint("TOPLEFT", descFrame, "TOPLEFT", 6, -5)
	descFrame.title:SetText(itemData.name)
	descFrame.title:SetTextColor(itemWidget.interactiveLabel.Text:GetTextColor())

	-- / description edit box
	descFrame.descriptionEditBox = CreateFrame("ScrollFrame", nil, descFrame, "NysTDL_InputScrollFrameTemplate")
	descFrame.descriptionEditBox:SetPoint("TOPLEFT", descFrame, "TOPLEFT", 10, -30)
	descFrame.descriptionEditBox:SetPoint("BOTTOMRIGHT", descFrame, "BOTTOMRIGHT", -10, 10)
	descFrame.descriptionEditBox.EditBox:SetFontObject(descFrameInfo.font)
	descFrame.descriptionEditBox.EditBox:SetAutoFocus(false)

	-- /-> char count
	descFrame.descriptionEditBox.EditBox:SetMaxLetters(enums.maxDescriptionCharCount)
	descFrame.descriptionEditBox.CharCount:Hide() -- TDLATER polish

	-- /-> hint
	descFrame.descriptionEditBox.EditBox.Instructions:SetFontObject("GameFontNormal")
	descFrame.descriptionEditBox.EditBox.Instructions:SetText(L["Add a description"].."...\n("..L["Automatically saved"]..")")

	-- /-> scripts
	descFrame.descriptionEditBox.EditBox:HookScript("OnTextChanged", function(self)
		-- and here we save the description everytime the text is updated (best auto-save possible I think)
		dataManager:UpdateDescription(itemID, self:GetText())
	end)
	widgets:SetHyperlinksEnabled(descFrame.descriptionEditBox.EditBox, true)
	widgets:AddHyperlinkEditBox(descFrame.descriptionEditBox.EditBox)

	-- /-> default value
	if itemData.description then -- if there is already a description for this item, we write it on frame creation
		descFrame.descriptionEditBox.EditBox:SetText(itemData.description)
	end

	descFrames[itemID] = descFrame -- we save it for access, hide, and alpha purposes

	-- // finished creating the frame

	-- we update the alpha if it needs to be
	mainFrame:Event_FrameAlphaSlider_OnValueChanged(NysTDL.acedb.profile.frameAlpha)
	mainFrame:Event_FrameContentAlphaSlider_OnValueChanged(NysTDL.acedb.profile.frameContentAlpha)
end

-- // tdl button

function widgets:RefreshTDLButton()
	-- // to refresh everything concerbing the tdl button

	-- updating its position and shown state in accordance to the saved variables
	local points = NysTDL.acedb.profile.tdlButton.points
	tdlButton:ClearAllPoints()
	tdlButton:SetPoint(points.point, nil, points.relativePoint, points.xOffset, points.yOffset) -- relativeFrame = nil -> entire screen
	tdlButton:SetShown(NysTDL.acedb.profile.tdlButton.show)

	-- and updating its color
	widgets:UpdateTDLButtonColor()
end

function widgets:UpdateTDLButtonColor()
	-- the TDL button red option, if any tab has a reset in less than 24 hours,
	-- and also has unchecked items, we color in red the text of the tdl button

	tdlButton:SetNormalFontObject("GameFontNormalLarge") -- by default, we reset the color of the TDL button to yellow
	if NysTDL.acedb.profile.tdlButton.red then -- if the option is checked
		local maxTime = time() + 86400
		dataManager:DoIfFoundTabMatch(maxTime, "totalUnchecked", function()
			-- we color the button in red
			tdlButton:SetNormalFontObject("NysTDL_GameFontNormalLarge_Red")
		end)
	end
end

-- // other

function widgets:SetFocusEditBox(editBox, forceHighlight) -- DRY
	editBox:SetFocus()
	if forceHighlight or NysTDL.acedb.profile.highlightOnFocus then
		editBox:HighlightText()
	else
		editBox:HighlightText(0, 0)
	end
end

function widgets:GetWidth(text, font)
	-- not the length (#) of a string, but the width it takes when placed on the screen as a font string
	local l = widgets:NoPointsLabel(UIParent, nil, text)

	if font then
		l:SetFontObject(font)
	end

	local width = l:GetWidth()
	l:Hide()

	return width
end

function widgets:SetHyperlinksEnabled(frame, enabled)
	if enabled then
		frame:SetHyperlinksEnabled(true) -- to enable OnHyperlinkClick
		frame:SetScript("OnHyperlinkClick", function(_, linkData, link, button)
			ChatFrame_OnHyperlinkShow(ChatFrame1, linkData, link, button)
		end)
	else
		frame:SetHyperlinksEnabled(false) -- to disable OnHyperlinkClick
		frame:SetScript("OnHyperlinkClick", nil)
	end
end

--/*******************/ FRAMES /*************************/--

function widgets:TutorialFrame(tutoCategory, tutoName, showCloseButton, arrowSide, text, width)
	local tutoFrame = CreateFrame("Frame", "NysTDL_TutorialFrame_"..tutoCategory.."_"..tutoName, UIParent, "NysTDL_HelpPlateTooltip") -- TDLATER POLISH check if name is mandatory, also checl ALL addon names for the same thing
	tutoFrame.Text:SetText(text)
	tutoFrame.Text:SetWidth(width-15-15)

	if arrowSide == "UP" then tutoFrame.ArrowDOWN:Show()
	elseif arrowSide == "DOWN" then tutoFrame.ArrowUP:Show()
	elseif arrowSide == "LEFT" then tutoFrame.ArrowRIGHT:Show()
	elseif arrowSide == "RIGHT" then tutoFrame.ArrowLEFT:Show() end

	if showCloseButton then
		tutoFrame.closeButton = CreateFrame("Button", nil, tutoFrame, "UIPanelCloseButton")
		tutoFrame.closeButton:SetFrameLevel(tutoFrame:GetFrameLevel()+1)
		tutoFrame.closeButton:SetPoint("TOPRIGHT", tutoFrame, "TOPRIGHT", 4, 4)
		tutoFrame.closeButton:SetScript("OnClick", function() tutorialsManager:Validate(tutoCategory, tutoName) end)
		tutoFrame.Text:SetWidth(width-15-25) -- we add an offset because of the close button
	end

	tutoFrame:SetWidth(width)
	tutoFrame:Hide() -- we hide them by default, we show them only when we need to

	tutoFrame:SetScript("OnUpdate", function(self)
		if not utils:Approximately(self:GetHeight(), self.Text:GetHeight()+30) then
			self:SetHeight(self.Text:GetHeight()+30)
		end
	end)

	return tutoFrame
end

function widgets:Dummy(parentFrame, relativeFrame, xOffset, yOffset)
	-- a frame with a nil template, this means that it'll be invisible no matter what (perfect for a dummy frame)
	local dummy = CreateFrame("Frame", nil, parentFrame, nil)
	dummy:SetPoint("TOPLEFT", relativeFrame, "TOPLEFT", xOffset, yOffset)
	dummy:SetSize(1, 1)
	dummy:Show()
	return dummy
end

--/*******************/ LABELS /*************************/--

function widgets:NoPointsLabel(relativeFrame, name, text, font)
	local label = relativeFrame:CreateFontString(name)
	if font and type(font) == "string" then
		label:SetFontObject(font)
	else
		label:SetFontObject("GameFontHighlightLarge")
	end
	label:SetText(text)
	return label
end

function widgets:NoPointsInteractiveLabel(relativeFrame, name, text, fontObjectString)
	local interactiveLabel = CreateFrame("Frame", name, relativeFrame, "NysTDL_InteractiveLabel")
	interactiveLabel.Text:SetFontObject(fontObjectString)
	interactiveLabel.Text:SetText(text)
	interactiveLabel:SetSize(interactiveLabel.Text:GetWidth(), interactiveLabel.Text:GetHeight()) -- we init the size to the text's size

	-- this updates the frame's size each time the text's size is changed
	interactiveLabel.Button:SetScript("OnSizeChanged", function(self, width, height)
		self:GetParent():SetSize(width, height)
	end)

	return interactiveLabel
end

function widgets:HintLabel(relativeFrame, name, text)
	local label = relativeFrame:CreateFontString(name)
	label:SetFontObject("GameFontHighlightLarge")
	label:SetTextColor(0.5, 0.5, 0.5, 0.5)
	label:SetText(text)
	return label
end

--/*******************/ BUTTONS /*************************/--

function widgets:Button(name, relativeFrame, text, iconPath, fc, bonusWidth)
	fc = fc or false
	iconPath = type(iconPath) == "string" and iconPath or nil
	bonusWidth = bonusWidth or 0

	local btn = CreateFrame("Button", name, relativeFrame, "NysTDL_NormalButton")

	btn:SetText(text)
	btn:SetNormalFontObject("GameFontNormalLarge")
	if fc == true then btn:SetHighlightFontObject("GameFontHighlightLarge") end

	local w = widgets:GetWidth(text)
	if iconPath ~= nil then
		w = w + 23
		btn.Icon = btn:CreateTexture(nil, "ARTWORK")
		btn.Icon:SetPoint("LEFT", btn, "LEFT", 10, 0)
		btn.Icon:SetTexture(iconPath)
		btn.Icon:SetSize(17, 17)
		btn:GetFontString():SetPoint("LEFT", btn, "LEFT", 33, 0)
		btn:HookScript("OnMouseDown", function(self) self.Icon:SetPoint("LEFT", self, "LEFT", 12, -2) end)
		btn:HookScript("OnMouseUp", function(self) self.Icon:SetPoint("LEFT", self, "LEFT", 10, 0) end)
	end
	btn:SetWidth(w + 20 + bonusWidth)

	return btn
end

function widgets:IconTooltipButton(relativeFrame, template, tooltip)
	local btn = CreateFrame("Button", nil, relativeFrame, template)
	btn.tooltip = tooltip
	return btn
end

function widgets:HelpButton(relativeFrame)
	local btn = CreateFrame("Button", nil, relativeFrame, "NysTDL_HelpButton")
	btn.tooltip = L["Information"]
	btn:SetAlpha(0.7)

	-- these are for changing the color depending on the mouse actions (since they are custom xml)
	btn:HookScript("OnEnter", function(self)
		self:SetAlpha(1)
	end)
	btn:HookScript("OnLeave", function(self)
		self:SetAlpha(0.7)
	end)
	btn:HookScript("OnShow", function(self)
		self:SetAlpha(0.7)
	end)
	return btn
end

function widgets:CreateTDLButton()
	-- creating the big button to easily toggle the frame
	tdlButton = widgets:Button("NysTDL_tdlButton", UIParent, core.simpleAddonName)

	-- properties
	tdlButton:SetFrameStrata("LOW")
	tdlButton:EnableMouse(true)
	tdlButton:SetMovable(true)
	tdlButton:SetClampedToScreen(true)
	tdlButton:SetToplevel(true)

	-- drag
	tdlButton:RegisterForDrag("LeftButton")
	tdlButton:SetScript("OnDragStart", function()
		if not NysTDL.acedb.profile.lockTdlButton then
			tdlButton:StartMoving()
		end
	end)
	tdlButton:SetScript("OnDragStop", function() -- we save its position
		tdlButton:StopMovingOrSizing()
		local points, _ = NysTDL.acedb.profile.tdlButton.points, nil
		points.point, _, points.relativePoint, points.xOffset, points.yOffset = tdlButton:GetPoint()
	end)

	-- click
	tdlButton:SetScript("OnClick", mainFrame.Toggle) -- the function the button calls when pressed
end

-- item buttons

function widgets:RemoveButton(widget, parent)
	local btn = CreateFrame("Button", nil, parent, "NysTDL_RemoveButton")
	local ID = widget.itemID or widget.catID
	local desaturated = widget.enum == enums.category and 1 or nil

	-- these are for changing the color depending on the mouse actions (since they are custom xml)
	btn:HookScript("OnEnter", function(self)
		if not dataManager:IsID(ID) then return end
		if not dataManager:IsProtected(ID) then
			self.Icon:SetDesaturated(desaturated)
			self.Icon:SetVertexColor(0.8, 0.2, 0.2)
		end
	end)
	btn:HookScript("OnLeave", function(self)
		if not dataManager:IsID(ID) then return end
		if not dataManager:IsProtected(ID) then
			if tonumber(string.format("%.1f", self.Icon:GetAlpha())) ~= 0.5 then
				self.Icon:SetDesaturated(desaturated)
				self.Icon:SetVertexColor(1, 1, 1)
			end
		end
	end)
	btn:HookScript("OnMouseUp", function(self)
		if not dataManager:IsID(ID) then return end
		if not dataManager:IsProtected(ID) then
			self.Icon:SetDesaturated(desaturated)
			self.Icon:SetVertexColor(1, 1, 1)
		end
	end)
	btn:HookScript("OnShow", function(self)
		if not dataManager:IsID(ID) then return end
		if dataManager:IsProtected(ID) then
			self:Disable()
			self.Icon:SetDesaturated(1)
			self.Icon:SetVertexColor(0.4, 0.4, 0.4)
		else
			self:Enable()
			self.Icon:SetDesaturated(desaturated)
			self.Icon:SetVertexColor(1, 1, 1)
		end
	end)
	return btn
end

function widgets:FavoriteButton(widget, parent)
	local btn = CreateFrame("Button", nil, parent, "NysTDL_FavoriteButton")

	-- these are for changing the color depending on the mouse actions (since they are custom xml)
	-- and yea, this one's a bit complicated because I wanted its look to be really precise...
	btn:HookScript("OnEnter", function(self)
		if not widget.itemData.favorite then -- not favorited
			self.Icon:SetDesaturated(nil)
			self.Icon:SetVertexColor(1, 1, 1)
		else
			self:SetAlpha(0.6)
		end
	end)
	btn:HookScript("OnLeave", function(self)
		if not widget.itemData.favorite then
			if tonumber(string.format("%.1f", self.Icon:GetAlpha())) ~= 0.5 then -- if we are currently clicking on the button
				self.Icon:SetDesaturated(1)
				self.Icon:SetVertexColor(0.4, 0.4, 0.4)
			end
		else
			self:SetAlpha(1)
		end
	end)
	btn:HookScript("OnMouseUp", function(self)
		self:SetAlpha(1)
		if not widget.itemData.favorite then
			self.Icon:SetDesaturated(1)
			self.Icon:SetVertexColor(0.4, 0.4, 0.4)
		end
	end)
	btn:HookScript("PostClick", function(self)
		self:GetScript("OnShow")(self)
	end)
	btn:HookScript("OnShow", function(self)
		self:SetAlpha(1)
		if not widget.itemData.favorite then
			self.Icon:SetDesaturated(1)
			self.Icon:SetVertexColor(0.4, 0.4, 0.4)
		else
			self.Icon:SetDesaturated(nil)
			self.Icon:SetVertexColor(1, 1, 1)
		end
	end)
	return btn
end

function widgets:DescButton(widget, parent)
	local btn = CreateFrame("Button", nil, parent, "NysTDL_DescButton")

	-- // Appearance

	-- these are for changing the color depending on the mouse actions (since they are custom xml)
	-- and yea, this one's a bit complicated too because it works in very specific ways
	btn:HookScript("OnEnter", function(self)
		if not widget.itemData.description then -- no description
			self.Icon:SetDesaturated(nil)
			self.Icon:SetVertexColor(1, 1, 1)
		else
			self:SetAlpha(0.6)
		end
	end)
	btn:HookScript("OnLeave", function(self)
		if not widget.itemData.description then
			if tonumber(string.format("%.1f", self.Icon:GetAlpha())) ~= 0.5 then -- if we are currently clicking on the button
				self.Icon:SetDesaturated(1)
				self.Icon:SetVertexColor(0.4, 0.4, 0.4)
			end
		else
			self:SetAlpha(1)
		end
	end)
	btn:HookScript("OnMouseUp", function(self)
		self:SetAlpha(1)
		if not widget.itemData.description then
			self.Icon:SetDesaturated(1)
			self.Icon:SetVertexColor(0.4, 0.4, 0.4)
		end
	end)
	btn:HookScript("PostClick", function(self)
		self:GetScript("OnShow")(self)
	end)
	btn:HookScript("OnShow", function(self)
		self:SetAlpha(1)
		if not widget.itemData.description then
			self.Icon:SetDesaturated(1)
			self.Icon:SetVertexColor(0.4, 0.4, 0.4)
		else
			self.Icon:SetDesaturated(nil)
			self.Icon:SetVertexColor(1, 1, 1)
		end
	end)

	-- // Tooltip

	btn.tooltip = nil
	btn.isTooltipShown = function()
		return not (descFrames[widget.itemID] and true or false)
	end

	btn:HookScript("OnEnter", function(self)
		-- we don't do anything in 3 cases
		-- if we unchecked the option in the addon options
		if not NysTDL.acedb.profile.descriptionTooltip then
			return
		end

		-- if the item doesn't have a description
		if not widget.itemData.description then
			return
		end

		-- if the tooltip is already in use by someone else
		if LibQTip:IsAcquired("NysTDL_DescButton_tooltip") then
			return
		end

		-- we're good to go
		btn.tooltip = LibQTip:Acquire("NysTDL_DescButton_tooltip", 1)
		local tooltip = btn.tooltip

		tooltip:Clear()
		tooltip:SmartAnchorTo(self)
		tooltip:ClearAllPoints()
		tooltip:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, 0)

		-- we use the same code to set the description frame's width
		local w = widgets:GetWidth(widget.itemData.name)
		local width = w < descFrameInfo.width and descFrameInfo.width+descFrameInfo.buttons or w+descFrameInfo.buttons

		tooltip:SetFont(descFrameInfo.font)

		tooltip:AddLine()
		tooltip:SetCell(1, 1, widget.itemData.description, nil, nil, nil, nil, nil, nil, width-20)

		tooltip:SetShown(btn.isTooltipShown())
	end)
	btn:HookScript("OnLeave", function()
		if btn.tooltip then
			LibQTip:Release(btn.tooltip)
			btn.tooltip = nil
		end
	end)
	btn:HookScript("OnShow", function()
		if btn.tooltip then
			btn.tooltip:SetShown(btn.isTooltipShown())
		end
	end)

  return btn
end

function widgets:ValidButton(parent)
	local btn = CreateFrame("Button", nil, parent, "NysTDL_ValidButton")
	local function toGreen()
		btn.Icon = btn.IconGreen
		btn.IconYellow:Hide()
		btn.IconGreen:Show()
	end
	local function toYellow()
		btn.Icon = btn.IconYellow
		btn.IconGreen:Hide()
		btn.IconYellow:Show()
	end
	toYellow()

	-- these are for changing the color depending on the mouse actions (since they are custom xml)
	btn:HookScript("OnEnter", function()
		toGreen()
	end)
	btn:HookScript("OnLeave", function(self)
		if not self.pressed then
			toYellow()
		end
	end)
	btn:HookScript("OnMouseUp", function()
		toYellow()
	end)
	btn:HookScript("OnShow", function()
		toYellow()
	end)
	return btn
end

--/*******************/ ITEM/CATEGORY WIDGETS /*************************/--

local Widget_doubleClicked = false -- see CategoryWidget > interactiveLabel.Button > OnClick

---DRY function to rename the widgets (OnDoubleClick).
function private.Widget_OnDoubleClick(self, button)
	-- first we check if we can rename right now
	if not mainFrame.editMode then return end -- we can only rename in edit mode
	if dragndrop.dragging then return end -- we can't rename if we are dragging something
	if button ~= "LeftButton" then return end -- only double-left click

	Widget_doubleClicked = true

	-- we get all the relevant data
	local widget = self:GetParent():GetParent() -- self is the interactiveLabel's button (interactiveLabel.Button)

	local ID, name, renameEditBoxWidth
	if widget.enum == enums.item then
		ID = widget.itemID
		name = widget.itemData.name
		renameEditBoxWidth = 0
	elseif widget.enum == enums.category then
		ID = widget.catID
		name = widget.catData.name
		renameEditBoxWidth = enums.maxNameWidth[enums.category]
	end

	-- we're ready, now we start by hiding the interactiveLabel
	self:GetParent():Hide()

	-- then, we can create the new edit box to rename the object, where the label was
	local renameEditBox = widgets:NoPointsRenameEditBox(widget, name, renameEditBoxWidth, self:GetHeight())
	renameEditBox:SetPoint("LEFT", widget.interactiveLabel, "LEFT", 5, 0)

	if widget.enum == enums.item then
		renameEditBox:SetPoint("RIGHT", widget:GetParent(), "RIGHT", -3, 0)
		widgets:AddHyperlinkEditBox(renameEditBox) -- so that we can add hyperlinks in it
		-- widgets:SetHyperlinksEnabled(renameEditBox, true) -- to click on hyperlinks inside the edit box
	end

	-- let's go!
	renameEditBox:SetScript("OnEnterPressed", function(self)
		dataManager:Rename(ID, self:GetText())
	end)

	-- cancelling
	renameEditBox:SetScript("OnEscapePressed", function(self)
		-- we hide the edit box and show the label
		self:Hide()
		self:ClearAllPoints()
		widget.interactiveLabel:Show()

		if widget.enum == enums.item then
			widgets:RemoveHyperlinkEditBox(self)
		end
	end)
	renameEditBox:HookScript("OnEditFocusLost", function(self)
		self:GetScript("OnEscapePressed")(self)
	end)
end

--[[

-- // categoryWidget example:

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
		...
	},
	...
}

]]

function private:Category_SetEditMode(state)
	if state then
		self.editModeFrame:Show()
		self.interactiveLabel:SetPoint("LEFT", self.editModeFrame, "RIGHT", 0, 0)
		self.interactiveLabel.Button:GetScript("OnLeave")(self.interactiveLabel.Button)
	else
		self.editModeFrame:Hide()
		self.interactiveLabel:SetPoint("LEFT", self, "LEFT", 0, 0)
	end
end

function widgets:CategoryWidget(catID, parentFrame)
	local categoryWidget = CreateFrame("Frame", nil, parentFrame, nil)
	categoryWidget:SetSize(1, 1) -- so that its children are visible

	-- // data

	categoryWidget.enum = enums.category
	categoryWidget.catID = catID
	categoryWidget.catData = select(3, dataManager:Find(catID))
	categoryWidget.color = { 1, 1, 1, 1 }
	local catData = categoryWidget.catData

	-- // frames

	-- / interactiveLabel
	categoryWidget.interactiveLabel = widgets:NoPointsInteractiveLabel(categoryWidget, nil, catData.name, "GameFontHighlightLarge")

	-- / interactiveLabel.Button
	categoryWidget.interactiveLabel.Button:SetScript("OnEnter", function(self)
		if dragndrop.dragging then return end

		local r, g, b = unpack(utils:ThemeDownTo01(database.themes.theme))
		self:GetParent().Text:SetTextColor(r, g, b, 1) -- when we hover it, we color the label
	end)
	categoryWidget.interactiveLabel.Button:SetScript("OnLeave", function(self)
		self:GetParent().Text:SetTextColor(unpack(categoryWidget.color)) -- back to the default color
	end)
	categoryWidget.interactiveLabel.Button:SetScript("OnClick", function(self, button, forced)
		if dragndrop.dragging then return end

		if button == "LeftButton" then -- we open/close the category
			if mainFrame.editMode and not forced then
				-- when in edit mode, since we can rename an object by double-clicking on it (only "LeftButton"),
				-- the first click also opens/closes the category, which is something I don't want.
				-- So I'm simply delaying the first click, and only doing it if we didn't meant to double-click.
				Widget_doubleClicked = false
				AceTimer:ScheduleTimer(function()
					if Widget_doubleClicked then return end
					categoryWidget.interactiveLabel.Button:GetScript("OnClick")(self, button, true)
				end, 0.3)
				return
			end

			dataManager:ToggleClosed(catID, database.ctab())
		elseif button == "RightButton" then -- we try to toggle the addEditBox
			-- if the cat we right clicked on is NOT a closed category
			if catData.closedInTabIDs[database.ctab()] then return end

			-- we toggle its edit box
			categoryWidget.addEditBox:SetShown(not categoryWidget.addEditBox:IsShown())
			-- categoryWidget.addCatEditBox:SetShown(not categoryWidget.addCatEditBox:IsShown()) -- TDLATER sub-cats
		end
	end)
	categoryWidget.interactiveLabel.Button:SetScript("OnDoubleClick", private.Widget_OnDoubleClick)

	-- / editModeFrame
	categoryWidget.editModeFrame = CreateFrame("Frame", nil, categoryWidget, nil)
	categoryWidget.editModeFrame:SetPoint("LEFT", categoryWidget, "LEFT", 0, 0)
	categoryWidget.editModeFrame:SetSize(20, 20) -- CVAL
	local emf = categoryWidget.editModeFrame

	-- / removeBtn
	categoryWidget.removeBtn = widgets:RemoveButton(categoryWidget, emf)
	categoryWidget.removeBtn:SetPoint("LEFT", emf, "LEFT", 0, -1)
	categoryWidget.removeBtn:SetScript("OnClick", function() dataManager:DeleteCat(catID) end)

	-- / favsRemainingLabel
	categoryWidget.favsRemainingLabel = widgets:NoPointsLabel(categoryWidget.interactiveLabel, nil, "")
	categoryWidget.favsRemainingLabel:SetPoint("LEFT", categoryWidget.interactiveLabel, "RIGHT", 6, 0)

	-- / originalTabLabel
	categoryWidget.originalTabLabel = widgets:HintLabel(categoryWidget.interactiveLabel, nil, "")

	-- / emptyLabel
	categoryWidget.emptyLabel = widgets:HintLabel(categoryWidget, nil, L["Empty category"])
	categoryWidget.emptyLabel:SetPoint("LEFT", categoryWidget, "TOPLEFT", enums.ofsxContent, -enums.ofsyCatContent)

	-- / hiddenLabel
	categoryWidget.hiddenLabel = widgets:HintLabel(categoryWidget, nil, L["Completed category"])
	categoryWidget.hiddenLabel:SetPoint("LEFT", categoryWidget, "TOPLEFT", enums.ofsxContent, -enums.ofsyCatContent)
	categoryWidget.hiddenLabel:Hide()

	-- / addEditBox
	categoryWidget.addEditBox = widgets:NoPointsCatEditBox("NysTDL_"..catID.."_widget_addEditBox", categoryWidget)
	categoryWidget.addEditBox:SetHeight(30)
	categoryWidget.addEditBox:Hide()
	categoryWidget.addEditBox:SetScript("OnEnterPressed", function(self)
		if dataManager:CreateItem(self:GetText(), catData.originalTabID, catID) then -- calls mainFrame:Refresh()
			self:SetText("") -- we clear the box if the adding was a success
		end
		self:Show() -- we keep it shown to add more items
	end)
	-- cancelling
	categoryWidget.addEditBox:SetScript("OnEscapePressed", function(self)
		self:Hide()
	end)
	categoryWidget.addEditBox:HookScript("OnEditFocusLost", function(self)
		if not NysTDL.acedb.profile.migrationData.failed then
			self:GetScript("OnEscapePressed")(self)
		end
	end)
	categoryWidget.addEditBox:SetScript("OnShow", function(self)
		-- // we reset its points
		categoryWidget.addEditBox:ClearAllPoints()
		categoryWidget.addEditBox:SetPoint("LEFT", categoryWidget.interactiveLabel, "RIGHT", 10, 0)
		categoryWidget.addEditBox:SetPoint("RIGHT", parentFrame, "RIGHT", -3, 0)
		-- categoryWidget.addCatEditBox:ClearAllPoints() -- TDLATER sub-cats

		-- // we give it the focus
		widgets:SetFocusEditBox(categoryWidget.addEditBox)
		tutorialsManager:Validate("introduction", "addItem") -- tutorial

		-- we hide the originalTabLabel so it doesn't overlap (we show it back when the edit box dissapears)
		categoryWidget.originalTabLabel:Hide()
	end)
	categoryWidget.addEditBox:SetScript("OnHide", function(self)
		self:ClearAllPoints()
		-- if the originalTabLabel was hidden because the add edit box was shown, we show it back if it's necessary
		if catData.originalTabID ~= database.ctab() then
			categoryWidget.originalTabLabel:Show()
		end
	end)
	widgets:AddHyperlinkEditBox(categoryWidget.addEditBox)

	-- -- TDLATER sub-cat creation
	-- -- / addCatEditBox
	-- categoryWidget.addCatEditBox = widgets:NoPointsCatEditBox(categoryWidget)
	-- categoryWidget.addCatEditBox:SetPoint("RIGHT", categoryWidget.interactiveLabel, "LEFT", 270, -20)
	-- categoryWidget.addCatEditBox:SetPoint("LEFT", categoryWidget.interactiveLabel, "RIGHT", 10, -20)
	-- categoryWidget.addCatEditBox:SetSize(100, 30)
	-- categoryWidget.addCatEditBox:Hide()
	-- categoryWidget.addCatEditBox:SetScript("OnEnterPressed", function(self)
	-- 	if dataManager:CreateCategory(self:GetText(), catData.originalTabID, catID) then
	-- 		self:SetText("") -- we clear the box if the adding was a success
	-- 	end
	-- 	self:Show() -- we keep it shown to add more categories
	-- 	widgets:SetFocusEditBox(self)
	-- end)
	-- -- cancelling
	-- categoryWidget.addCatEditBox:SetScript("OnEscapePressed", function(self)
	-- 	self:Hide()
	-- 	self:ClearAllPoints()
	-- end)
	-- categoryWidget.addCatEditBox:HookScript("OnEditFocusLost", function(self)
	-- 	self:GetScript("OnEscapePressed")(self)
	-- end)

	-- / drag&drop
	dragndrop:RegisterForDrag(categoryWidget)

	-- / edit mode
	categoryWidget.SetEditMode = private.Category_SetEditMode
	categoryWidget:SetEditMode(mainFrame.editMode)

	return categoryWidget
end

--[[

-- // itemWidget example:

contentWidgets = {
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
		...
	},
	...
}

]]

function private:Item_SetCheckBtnExtended(state)
	if state then
		if not utils:HasHyperlink(self.itemData.name) then -- so that we can actually click on the hyperlinks
			-- self.checkBtn:SetHitRectInsets(0, -enums.maxNameWidth[enums.item], 0, 0)
			self.checkBtn:SetHitRectInsets(0, -widgets:GetWidth(self.itemData.name), 0, 0)
		end
	else
		self.checkBtn:SetHitRectInsets(0, 0, 0, 0)
	end
end

function private:Item_SetEditMode(state)
	if state then
		self.editModeFrame:Show()

		self.favoriteBtn:SetParent(self.editModeFrame)
		self.favoriteBtn:SetPoint("LEFT", self.removeBtn, "LEFT", 20, -2)
		self.descBtn:SetParent(self.editModeFrame)
		self.descBtn:SetPoint("LEFT", self.favoriteBtn, "LEFT", 20, 3)

		self.checkBtn:SetPoint("LEFT", self.editModeFrame, "RIGHT", 0, 0)

		self.interactiveLabel.Button:Show()
	else
		self.editModeFrame:Hide()

		self.favoriteBtn:SetParent(self)
		self.favoriteBtn:SetPoint("LEFT", self, "LEFT", enums.ofsxItemIcons, -2)
		self.descBtn:SetParent(self)
		self.descBtn:SetPoint("LEFT", self, "LEFT", enums.ofsxItemIcons, 0)

		self.checkBtn:SetPoint("LEFT", self, "LEFT", 0, 0)

		self.interactiveLabel.Button:Hide()
	end
	private.Item_SetCheckBtnExtended(self, not state)
	mainFrame:UpdateItemButtons(self.itemID)
end

function widgets:ItemWidget(itemID, parentFrame)
	local itemWidget = CreateFrame("Frame", nil, parentFrame, nil)
	itemWidget:SetSize(1, 1) -- so that its children are visible

	-- // data

	itemWidget.enum = enums.item
	itemWidget.itemID = itemID
	itemWidget.itemData = select(3, dataManager:Find(itemID))
	local itemData = itemWidget.itemData

	-- // frames

	-- / checkBtn
	itemWidget.checkBtn = CreateFrame("CheckButton", nil, itemWidget, "UICheckButtonTemplate")
	-- itemWidget.checkBtn = CreateFrame("CheckButton", nil, itemWidget, "ChatConfigCheckButtonTemplate")
	-- itemWidget.checkBtn = CreateFrame("CheckButton", nil, itemWidget, "OptionsCheckButtonTemplate")
	itemWidget.checkBtn:SetScript("OnClick", function() dataManager:ToggleChecked(itemID) end)
	-- itemWidget.checkBtn:SetPoint("LEFT", itemWidget, "LEFT", 0, 0)
	-- itemWidget.checkBtn:SetSize(28, 28)
	itemWidget.SetCheckBtnExtended = private.Item_SetCheckBtnExtended
	itemWidget:SetCheckBtnExtended(true)

	-- / interactiveLabel
	itemWidget.interactiveLabel = widgets:NoPointsInteractiveLabel(itemWidget, nil, itemData.name, "GameFontNormalLarge")
	itemWidget.interactiveLabel:SetPoint("LEFT", itemWidget.checkBtn, "RIGHT", 0, 0)
	widgets:SetHyperlinksEnabled(itemWidget.interactiveLabel, true)

	-- / interactiveLabel.Text
	if utils:HasHyperlink(itemData.name) then -- this is for making more space for items that have hyperlinks in them
		if itemWidget.interactiveLabel.Text:GetWidth() > enums.maxNameWidth[enums.item] then
			itemWidget.interactiveLabel.Text:SetFontObject("GameFontNormal")
		end
	end

	-- / interactiveLabel.Button
	itemWidget.interactiveLabel.Button:Hide() -- we are not in edit mode by default
	itemWidget.interactiveLabel.Button:SetScript("OnDoubleClick", private.Widget_OnDoubleClick)

	-- / editModeFrame
	itemWidget.editModeFrame = CreateFrame("Frame", nil, itemWidget, nil)
	itemWidget.editModeFrame:SetPoint("LEFT", itemWidget, "LEFT", 0, 0)
	itemWidget.editModeFrame:SetSize(40, 20) -- CVAL
	local emf = itemWidget.editModeFrame

	-- / removeBtn
	itemWidget.removeBtn = widgets:RemoveButton(itemWidget, emf)
	itemWidget.removeBtn:SetPoint("LEFT", emf, "LEFT", enums.ofsxItemIcons, 0)
	itemWidget.removeBtn:SetScript("OnClick", function() dataManager:DeleteItem(itemID) end)

	-- / favoriteBtn
	itemWidget.favoriteBtn = widgets:FavoriteButton(itemWidget, emf)
	itemWidget.favoriteBtn:SetScript("OnClick", function() dataManager:ToggleFavorite(itemID) end)

	-- / descBtn
	itemWidget.descBtn = widgets:DescButton(itemWidget, emf)
	itemWidget.descBtn:SetScript("OnClick", function() widgets:DescriptionFrame(itemWidget) end)

	-- / drag&drop
	dragndrop:RegisterForDrag(itemWidget)

	-- / edit mode
	itemWidget.SetEditMode = private.Item_SetEditMode
	itemWidget:SetEditMode(mainFrame.editMode)

	return itemWidget
end

--/*******************/ EDIT BOXES /*************************/--

function widgets:NoPointsRenameEditBox(relativeFrame, text, width, height)
	local renameEditBox = CreateFrame("EditBox", nil, relativeFrame, "InputBoxTemplate")
	renameEditBox:SetSize(width-10, height)
	renameEditBox:SetText(text)
	renameEditBox:SetFontObject("GameFontHighlightLarge")
	renameEditBox:SetAutoFocus(false)
	widgets:SetFocusEditBox(renameEditBox)
	return renameEditBox
end

function widgets:NoPointsCatEditBox(name, categoryWidget)
	local edb = CreateFrame("EditBox", name, categoryWidget, "InputBoxTemplate")
	edb:SetAutoFocus(false)
	-- edb:SetTextInsets(0, 15, 0, 0)

	-- local btn = CreateFrame("Button", nil, edb, "NysTDL_AddButton")
	-- btn.tooltip = L["Press enter to add the item"]
	-- btn:SetPoint("RIGHT", edb, "RIGHT", -4, -1.2)
	-- btn:EnableMouse(true)

	-- -- these are for changing the color depending on the mouse actions (since they are custom xml)
	-- btn:HookScript("OnEnter", function(self)
	-- 	self.Icon:SetTextColor(1, 1, 0, 0.6)
	-- end)
	-- btn:HookScript("OnLeave", function(self)
	-- 	self.Icon:SetTextColor(1, 1, 1, 0.4)
	-- end)
	-- btn:HookScript("OnShow", function(self)
	-- 	self.Icon:SetTextColor(1, 1, 1, 0.4)
	-- end)

	return edb
end

--/*******************/ OTHER /*************************/--

function widgets:NoPointsLine(relativeFrame, thickness, r, g, b, a)
	a = a or 1
	local line = relativeFrame:CreateLine()
	line:SetThickness(thickness)
	if r and g and b and a then line:SetColorTexture(r, g, b, a) end
	return line
end

function widgets:ThemeLine(relativeFrame, theme, dim)
	return widgets:NoPointsLine(relativeFrame, 2, unpack(utils:ThemeDownTo01(utils:DimTheme(theme, dim))))
end

--/*******************/ INITIALIZATION /*************************/--

function private:Event_widgetsFrame_OnUpdate(elapsed)
	widgetsFrame.timeSinceLastUpdate = widgetsFrame.timeSinceLastUpdate + elapsed
	widgetsFrame.timeSinceLastRefresh = widgetsFrame.timeSinceLastRefresh + elapsed

	-- // every frame // --

	-- tuto frames visibility
	tutorialsManager:UpdateFramesVisibility()

	-- // ----------- // --

	while widgetsFrame.timeSinceLastUpdate > updateRate do
		widgetsFrame.timeSinceLastUpdate = widgetsFrame.timeSinceLastUpdate - updateRate

		-- // every 0.05 sec // -- (instead of every frame which is every 1/144 (0.007) sec for a 144hz display... optimization :D)

		-- rainbow update
		if NysTDL.acedb.profile.rainbow then
			if next(descFrames) or mainFrame:GetFrame():IsShown() then -- we don't really need to update the color at all times
				mainFrame:ApplyNewRainbowColor()
			end
		end

		-- // -------------- // --

		while widgetsFrame.timeSinceLastRefresh > refreshRate do
			widgetsFrame.timeSinceLastRefresh = widgetsFrame.timeSinceLastRefresh - refreshRate

			-- // every 1 sec // --

			-- xxx

			-- // ----------- // --
		end
	end
end

function widgets:Initialize()
	-- first we create every visual widget of every file
	tutorialsManager:CreateTutoFrames()
	widgets:CreateTDLButton()
	databroker:CreateDatabrokerObject()
	-- databroker:CreateTooltipFrame() -- TDLATER
	databroker:CreateMinimapButton()
	mainFrame:CreateTDLFrame()
	tabsFrame:CreateTabsFrame()

	-- then we manage the widgetsFrame
	widgetsFrame.timeSinceLastUpdate = 0
	widgetsFrame.timeSinceLastRefresh = 0
	widgetsFrame:SetScript("OnUpdate", private.Event_widgetsFrame_OnUpdate)

	-- and finally, we can refresh everything
	widgets:ProfileChanged()
end

function widgets:ProfileChanged()
	-- visual updates to match the new profile
	widgets:RefreshTDLButton()
	databroker:SetMode(NysTDL.acedb.profile.databrokerMode)
	-- TDLATER ici ligne pr refresh tooltip frame de databroker
	databroker:RefreshMinimapButton()

	widgets:WipeDescFrames()
	mainFrame:Init()
	tabsFrame:Init()
	tutorialsManager:Refresh()
end
