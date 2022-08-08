--/*******************/ IMPORTS /*************************/--

-- File init

local tutorialsManager = NysTDL.tutorialsManager
NysTDL.tutorialsManager = tutorialsManager

-- Primary aliases

local libs = NysTDL.libs
local chat = NysTDL.chat
local utils = NysTDL.utils
local widgets = NysTDL.widgets
local mainFrame = NysTDL.mainFrame

-- Secondary aliases

local L = libs.L

--/*******************************************************/--

-- tutorial
local tutorialFrames = {}
local tutorialFramesTarget = {}

-- default ordered tutorial
local tutorialOrder = {
	"TM_introduction_addNewCat",
	"TM_introduction_addCat",
	"TM_introduction_addItem",
	"TM_introduction_accessOptions",
	"TM_introduction_getMoreInfo",
	"TM_introduction_editmode",
	"TM_introduction_editmodeChat",
}

--[[ -- TDLATER new tuto system

-- tutorials_progression how it works:
-- tutorials_progression = {
-- 	-- "tutoName" = true/nil,
-- 	-- "tutoName" = true/nil,
-- 	-- ...
-- },

-- tutorials (names are unique)
local tutorials = {
	["introduction"] = {
		IsEnabled = function()
			return not NysTDL.acedb.global.tutorials_progression["introduction"]
		end,
		tutosOrdered = {
			"TM_introduction_addNewCat",
			"TM_introduction_addCat",
			"TM_introduction_addItem",
			"TM_introduction_accessOptions",
			"TM_introduction_getMoreInfo",
		},
		progress = 0,
		OnFinish = function()
			NysTDL.acedb.global.tutorials_progression["introduction"] = true
		end
	},
	["editmode"] = {
		IsEnabled = function()
			return NysTDL.acedb.global.tutorials_progression["introduction"]
			and not NysTDL.acedb.global.tutorials_progression["editmode"]
		end,
		tutosOrdered = {
			"TM_editmode_editmodeBtn",
			"TM_editmode_delete",
			"TM_editmode_favdesc",
			"TM_editmode_rename",
			"TM_editmode_sort",
			"TM_editmode_resize",
			"TM_editmode_buttons",
			"TM_editmode_undo",
		},
		progress = 0,
		OnFinish = function()
			NysTDL.acedb.global.tutorials_progression["editmode"] = true
		end
	},
}

]]

--/*******************/ FRAMES /*************************/--

function tutorialsManager:CreateTutoFrames()
	-- POLISH if text is bigger than width, ... by default but not right AND frame strata too high
	tutorialFrames.TM_introduction_addNewCat = widgets:TutorialFrame("TM_introduction_addNewCat", false, "UP", L["Start by adding a new category!"], 190, 50)
	tutorialFrames.TM_introduction_addCat = widgets:TutorialFrame("TM_introduction_addCat", true, "UP", L["This will add your category to the current tab"], 240, 50)
	tutorialFrames.TM_introduction_addItem = widgets:TutorialFrame("TM_introduction_addItem", false, "RIGHT", L["To add new items to existing categories, just right-click the category names"], 220, 50)
	tutorialFrames.TM_introduction_accessOptions = widgets:TutorialFrame("TM_introduction_accessOptions", false, "DOWN", L["You can access the options from here"], 220, 50)
	tutorialFrames.TM_introduction_getMoreInfo = widgets:TutorialFrame("TM_introduction_getMoreInfo", false, "LEFT", L["If you're having any problems or you just want more information, you can always click here to print help in the chat!"], 275, 50)
	tutorialFrames.TM_introduction_editmode = widgets:TutorialFrame("TM_introduction_editmode", false, "DOWN", L["To delete items and do a lot more, you can right-click anywhere on the list or click on this button to toggle the edit mode"], 275, 50)
	tutorialFrames.TM_introduction_editmodeChat = widgets:TutorialFrame("TM_introduction_editmodeChat", true, "RIGHT", utils:SafeStringFormat(L["Please type %s and read the chat message for more information about this mode"], "\""..chat.slashCommand..' '..L["editmode"].."\""), 275, 50)

	-- tutorialFrames.TM_editmode_editmodeBtn = widgets:TutorialFrame("TM_editmode_editmodeBtn", false, "DOWN", L["To delete items and do a lot more, you can right-click anywhere on the list or click on this button to toggle the edit mode"], 275, 50)
	-- tutorialFrames.TM_editmode_delete = widgets:TutorialFrame("TM_editmode_delete", true, "RIGHT", L["Delete items and categories"], 275, 50)
	-- tutorialFrames.TM_editmode_favdesc = widgets:TutorialFrame("TM_editmode_favdesc", true, "RIGHT", L["Favorite and add descriptions on items"], 275, 50)
	-- tutorialFrames.TM_editmode_rename = widgets:TutorialFrame("TM_editmode_rename", false, "UP", L["Rename items and categories"].." ("..L["Double-Click"]..")", 275, 50)
	-- tutorialFrames.TM_editmode_sort = widgets:TutorialFrame("TM_editmode_sort", false, "DOWN", L["Reorder/Sort the list"].." ("..L["Drag and Drop"]..")", 275, 50)
	-- tutorialFrames.TM_editmode_resize = widgets:TutorialFrame("TM_editmode_resize", true, "LEFT", L["Resize the list"], 275, 50)
	-- tutorialFrames.TM_editmode_buttons = widgets:TutorialFrame("TM_editmode_buttons", true, "DOWN", L["Undo what you deleted and access special actions for the tab"], 275, 50)
	-- tutorialFrames.TM_editmode_undo = widgets:TutorialFrame("TM_editmode_undo", true, "DOWN", L["More specifically you can undo items, categories, and even tab deletions"], 275, 50)
end

function tutorialsManager:SetPoint(tutoName, point, relativeTo, relativePoint, ofsx, ofsy)
	-- sets the points and target frame of a given tutorial
	if utils:HasValue(tutorialOrder, tutoName) then
		tutorialFramesTarget[tutoName] = relativeTo
		tutorialFrames[tutoName]:ClearAllPoints()
		tutorialFrames[tutoName]:SetPoint(point, relativeTo, relativePoint, ofsx, ofsy)
	end
end

function tutorialsManager:SetFramesScale(scale)
	for _, v in pairs(tutorialFrames) do
		v:SetScale(scale)
	end
end

function tutorialsManager:UpdateFramesVisibility()
	-- here we manage the visibility of the tutorial frames, showing them if their corresponding frames are shown,
	-- their tuto has not been completed (false) and the previous one is true.
	-- this is called by the OnUpdate event of the tdlFrame

	-- for _,tuto in ipairs(tutorials) do
	-- 	if tuto:IsEnabled() then
	-- 		-- TDLATER
	-- 	end
	-- end

	if NysTDL.acedb.global.tuto_progression < #tutorialOrder then
		for i, v in pairs(tutorialOrder) do
			local isShown = false
			if NysTDL.acedb.global.tuto_progression < i then -- if the current loop tutorial has not already been done
				if NysTDL.acedb.global.tuto_progression == i-1 then -- and the previous one has been done
					if tutorialFramesTarget[v] ~= nil and tutorialFramesTarget[v]:IsVisible() then -- and his corresponding target frame is currently visible
						isShown = true -- then we can show the tutorial frame
					end
				end
			end
			tutorialFrames[v]:SetShown(isShown)
		end
	elseif NysTDL.acedb.global.tuto_progression == #tutorialOrder then -- we completed the last tutorial
		tutorialFrames[tutorialOrder[#tutorialOrder]]:SetShown(false) -- we don't need to do the big loop above, we just need to hide the last tutorial frame (it's just optimization)
		tutorialsManager:Next() -- and we also add a step of progression, just so that we never enter this 'if' again. (optimization too :D)
		-- mainFrame:Event_TDLFrame_OnVisibilityUpdate() -- and finally, we reset the menu openings of the list at the end of the tutorial, for more visibility
	end
end

--/*******************/ MANAGMENT /*************************/--

---Tries to validate the given tutorial if it hasn't already been validated.
---@param tuto_name string
function tutorialsManager:Validate(tuto_name)
	-- completes the "tuto_name" tutorial, only if it was active
	local i = utils:GetKeyFromValue(tutorialOrder, tuto_name)
	if NysTDL.acedb.global.tuto_progression < i then
		if NysTDL.acedb.global.tuto_progression == i-1 then
			tutorialsManager:Next() -- we validate the tutorial by going to the next one
			return true
		end
	end
end

function tutorialsManager:Next()
	NysTDL.acedb.global.tuto_progression = NysTDL.acedb.global.tuto_progression + 1
end

function tutorialsManager:Previous()
	NysTDL.acedb.global.tuto_progression = NysTDL.acedb.global.tuto_progression - 1
	if NysTDL.acedb.global.tuto_progression < 0 then
		NysTDL.acedb.global.tuto_progression = 0
	end
end

function tutorialsManager:Reset()
	NysTDL.acedb.global.tuto_progression = 0
	-- wipe(NysTDL.acedb.global.tutorials_progression) TDLATER
	mainFrame:Event_TDLFrame_OnVisibilityUpdate()
	mainFrame:GetFrame().ScrollFrame:SetVerticalScroll(0)
end
