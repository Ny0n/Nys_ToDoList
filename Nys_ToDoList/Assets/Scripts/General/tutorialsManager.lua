---@diagnostic disable: unused-function
--/*******************/ IMPORTS /*************************/--

-- File init

local tutorialsManager = NysTDL.tutorialsManager
NysTDL.tutorialsManager = tutorialsManager

-- Primary aliases

local core = NysTDL.core
local libs = NysTDL.libs
local chat = NysTDL.chat
local enums = NysTDL.enums
local utils = NysTDL.utils
local widgets = NysTDL.widgets
local mainFrame = NysTDL.mainFrame

-- Secondary aliases

local L = libs.L

--/*******************************************************/--

local private = {}

-- tutorials
tutorialsManager.tutorials = {}
local tutorials = tutorialsManager.tutorials

local tutorialFrames = {}
local tutorialFramesTarget = {}

--[[

-- tutorials_progression how it works: (saved variable)
tutorials_progression = {
	"tutoCategory" = nil by default (non-existant), a number when in-progress (progress), true when finished
	...
}

]]

--/*******************************************************/--

---Generate Name (gn), helper function.
local function gn(tutoCategory, tutoName)
	return "TM_"..tutoCategory.."_"..tutoName
end

local tp = {} -- a.k.a tutorials_progression, useful functions

---Raw value.
function tp:Value(tutoCategory)
	if type(tutoCategory) ~= "string" then
		error("tutoCategory must be a string") -- dev error
		return
	end

	return NysTDL.acedb.global.tutorials_progression[tutoCategory]
end

---Raw value ~= nil ?
function tp:Exists(tutoCategory)
	return tp:Value(tutoCategory) ~= nil
end

---IsFinished?
function tp:ValueBool(tutoCategory)
	local value = tp:Value(tutoCategory)

	if type(value) == "boolean" or type(value) == "nil" then
		return not not value
	end

	return false
end

---Progression.
function tp:ValueNumber(tutoCategory)
	-- the number of tutos DONE in this category

	local value = tp:Value(tutoCategory)

	if type(value) == "number" then
		return value
	end

	if type(value) == "nil" then
		return 0
	end

	return tp:GetMaxProgress(tutoCategory)
end

---Helper function.
function tp:GetMaxProgress(tutoCategory)
	if type(tutoCategory) ~= "string" then
		error("tutoCategory must be a string") -- dev error
		return
	end

	return tutorials[tutoCategory]:GetMaxProgress()
end

---Helper function.
function tp:IsProgressAtLeast(tutoCategory, minProgress)
	if type(tutoCategory) ~= "string" then
		error("tutoCategory must be a string") -- dev error
		return
	end

	if type(minProgress) == "boolean" then
		if minProgress then
			return tp:Exists(tutoCategory) and (tp:ValueBool(tutoCategory) or tp:ValueNumber(tutoCategory) >= tp:GetMaxProgress(tutoCategory))
		else
			return true
		end
	end

	if type(minProgress) == "number" then
		return tp:Exists(tutoCategory) and (tp:ValueBool(tutoCategory) or tp:ValueNumber(tutoCategory) >= minProgress)
	end

	return false
end

---The tutorial tables generation.
function tp:GenerateTutoTable(tutoCategory, defaultTable)
	defaultTable = defaultTable or {}

	if not defaultTable.tutoCategory then
		defaultTable.tutoCategory = tutoCategory
	end

	if not defaultTable.IsEnabled then
		defaultTable.IsEnabled = function(self)
			return not tp:ValueBool(self.tutoCategory)
		end
	end

	if not defaultTable.OnFinish then
		defaultTable.OnFinish = function(self) end
	end

	if not defaultTable.tutosOrdered then
		defaultTable.tutosOrdered = {}
	end

	for i,name in pairs(defaultTable.tutosOrdered) do
		defaultTable[i] = gn(tutoCategory, name)
	end

	if not defaultTable.GetCurrentTutoName then
		defaultTable.GetCurrentTutoName = function(self) -- easy access
			return defaultTable.tutosOrdered[defaultTable:GetProgress()+1]
		end
	end

	if not defaultTable.GetMaxProgress then
		defaultTable.GetMaxProgress = function(self) -- easy access
			return #self.tutosOrdered
		end
	end

	if not defaultTable.GetProgress then
		defaultTable.GetProgress = function(self) -- easy access
			return tp:ValueNumber(self.tutoCategory)
		end
	end

	if not defaultTable.SetProgress then
		defaultTable.SetProgress = function(self, newProgress)
			newProgress = utils:Clamp(newProgress, 0, self:GetMaxProgress())

			if newProgress <= 0 then
				tutorialsManager:ResetTuto(self.tutoCategory)
				return
			end

			NysTDL.acedb.global.tutorials_progression[self.tutoCategory] = newProgress

			if tp:IsProgressAtLeast(self.tutoCategory, true) then
				NysTDL.acedb.global.tutorials_progression[self.tutoCategory] = true
				self:OnFinish()
			end

			tutorialsManager:Refresh()
		end
	end

	if not defaultTable.Progress then
		defaultTable.Progress = function(self, count)
			count = count or 1

			local currentProgress = self:GetProgress()
			self:SetProgress(currentProgress+count)
		end
	end

	tutorials[tutoCategory] = defaultTable
end

--/*******************/ FRAMES /*************************/--

function private:CreateTutoFrame(tutoCategory, tutoName, showCloseButton, arrowSide, text, width)
	tutorialFrames[gn(tutoCategory, tutoName)] = widgets:TutorialFrame(tutoCategory, tutoName, showCloseButton, arrowSide, text, width)
end

function tutorialsManager:SetPoint(tutoCategory, tutoName, point, relativeTo, relativePoint, ofsx, ofsy)
	-- sets the points and target frame of a given tutorial
	local frameName = gn(tutoCategory, tutoName)
	local tutoFrame = tutorialFrames[frameName]
	if tutoFrame then
		tutorialFramesTarget[frameName] = relativeTo
		tutoFrame:ClearAllPoints()
		tutoFrame:SetPoint(point, relativeTo, relativePoint, ofsx, ofsy)

		if relativeTo and relativeTo.HookScript and relativeTo.IsVisible then
			-- bind visibility scripts (only once!)
			if relativeTo.boundTutorialFrameName == nil then -- this means our visibility scripts were never bound to this frame
				relativeTo:HookScript("OnShow", function(self)
					local frameName = self.boundTutorialFrameName
					if type(frameName) ~= "string" then return end

					if tutorialFramesTarget[frameName] == self and tutorialFrames[frameName] then
						if tutorialFrames[frameName].shouldBeShown then
							tutorialFrames[frameName]:Show()
						end
					end
				end)
				relativeTo:HookScript("OnHide", function(self)
					local frameName = self.boundTutorialFrameName
					if type(frameName) ~= "string" then return end

					if tutorialFramesTarget[frameName] == self and tutorialFrames[frameName] then
						tutorialFrames[frameName]:Hide()
					end
				end)
			end

			relativeTo.boundTutorialFrameName = frameName -- update target

			tutoFrame:SetShown(tutoFrame.shouldBeShown and relativeTo:IsVisible())
		else
			tutoFrame:Hide()
		end
	end
end

function tutorialsManager:SetFramesScale(scale)
	for _, v in pairs(tutorialFrames) do
		v:SetScale(scale)
	end
end

--/*******************/ MANAGMENT /*************************/--

function tutorialsManager:Refresh()
	for frameName,frame in pairs(tutorialFrames) do
		frame.shouldBeShown = false
	end

	for tutoCategory,tutoTable in pairs(tutorials) do
		if tutoTable:IsEnabled() then
			local currentName = tutoTable:GetCurrentTutoName()
			local frameName = gn(tutoCategory, currentName)
			if tutorialFrames[frameName] then
				tutorialFrames[frameName].shouldBeShown = true
			end
		end
	end

	for frameName,frame in pairs(tutorialFrames) do
		if tutorialFramesTarget[frameName] then
			frame:SetShown(frame.shouldBeShown and tutorialFramesTarget[frameName]:IsVisible())
		else
			frame:Hide()
		end
	end
end

---Tries to validate the given tutorial if it hasn't already been validated.
---@param tutoCategory string
---@param tutoName string
function tutorialsManager:Validate(tutoCategory, tutoName)
	-- completes the "tutoName" tutorial in the "tutoCategory" category, only if it was active
	if tutorials[tutoCategory] then
		if tutorials[tutoCategory]:GetCurrentTutoName() == tutoName then
			tutorialsManager:Progress(tutoCategory)
		end
	end
end

function tutorialsManager:Progress(tutoCategory, count)
	if tutorials[tutoCategory] then
		count = count or 1
		tutorials[tutoCategory]:Progress(count)
	end
end

function tutorialsManager:Previous(tutoCategory)
	if tutorials[tutoCategory] then
		tutorials[tutoCategory]:Progress(-1)
	end
end

function tutorialsManager:SetProgress(tutoCategory, newProgress)
	if tutorials[tutoCategory] then
		newProgress = newProgress or tutorials[tutoCategory]:GetProgress()
		tutorials[tutoCategory]:SetProgress(newProgress)
	end
end

function tutorialsManager:CompleteTuto(tutoCategory)
	if tutorials[tutoCategory] then
		tutorials[tutoCategory]:SetProgress(tp:GetMaxProgress(tutoCategory))
		tutorialsManager:Refresh()
	end
end

function tutorialsManager:ResetTuto(tutoCategory)
	NysTDL.acedb.global.tutorials_progression[tutoCategory] = nil
	tutorialsManager:Refresh()
end

function tutorialsManager:Reset()
	wipe(NysTDL.acedb.global.tutorials_progression)
	tutorialsManager:Refresh()

	mainFrame:Event_TDLFrame_OnVisibilityUpdate()
	mainFrame:GetFrame().ScrollFrame:SetVerticalScroll(0)
end

--/*******************/ TUTORIALS /*************************/--

function private:CreateTutorials()
	local cat = ""

	-- // Example tutorial table
	-- tp:GenerateTutoTable("example",
	-- 	{
	-- 		IsEnabled = function(self)
	-- 			return tp:ValueBool("otherTutorialCategory")
	-- 			and not tp:ValueBool(self.tutoCategory)
	-- 		end,
	-- 		tutosOrdered = {
	-- 			"tuto1",
	-- 			"tuto2",
	-- 			"tuto3",
	-- 		},
	-- 		OnFinish = function(self)
	-- 			mainFrame:Event_TDLFrame_OnVisibilityUpdate()
	-- 			mainFrame:GetFrame().ScrollFrame:SetVerticalScroll(0)
	-- 		end,
	-- 	}
	-- )

	-- // ******************** // --

	cat = "introduction"

	tp:GenerateTutoTable("introduction",
		{
			tutosOrdered = {
				"addNewCat",
				"addCat",
				"addItem",
				"editmode",
				"editmodeChat",
				"getMoreInfo",
				"miniView",
			},
			OnFinish = function(self)
				mainFrame:Event_TDLFrame_OnVisibilityUpdate()
				mainFrame:GetFrame().ScrollFrame:SetVerticalScroll(0)
			end,
		}
	)

	private:CreateTutoFrame(cat, "addNewCat", false, "UP", L["Start by adding a new category!"], 240)
	private:CreateTutoFrame(cat, "addCat", true, "UP", L["This will add your category to the current tab"], 240)
	private:CreateTutoFrame(cat, "addItem", false, "RIGHT", utils:SafeStringFormat(L["To add new items, hover the category names and press the %s icon"], enums.icons.add.texHyperlinkTuto), 270)
	private:CreateTutoFrame(cat, "editmode", false, "DOWN", L["To delete items and do a lot more, you can right-click anywhere on the list or click on this button to toggle the edit mode"], 300)
	private:CreateTutoFrame(cat, "editmodeChat", true, "RIGHT", utils:SafeStringFormat(L["Please type %s and read the chat message for more information about this mode"], "\""..chat.slashCommand..' '..L["editmode"].."\""), 275)
	private:CreateTutoFrame(cat, "getMoreInfo", false, "RIGHT", L["If you're having any problems or you just want more information, you can always click here to print help in the chat!"], 290)
	private:CreateTutoFrame(cat, "miniView", true, "LEFT", L["One last thing: you can change what you see using this button. It's up to you now!"], 240)

	-- // ******************** // --

	cat = "tabSwitchState"

	tp:GenerateTutoTable(cat,
		{
			tutosOrdered = {
				"explainSwitchButton",
			},
		}
	)

	private:CreateTutoFrame(cat, "explainSwitchButton", true, "LEFT", L["You can click on this button to switch between global and profile tabs"], 285)

	-- // ******************** // --

	cat = "migration"

	tp:GenerateTutoTable(cat,
		{
			tutosOrdered = {
				"explainFrame",
			},
		}
	)

	private:CreateTutoFrame(cat, "explainFrame", true, "DOWN", L["You can click on any name to put it in the input field below, you can then Ctrl+C/Ctrl+V"], 200)

	-- // ******************** // --

	-- cat = "editmode"

	-- tp:GenerateTutoTable(cat,
	-- 	{
	-- 		IsEnabled = function(self)
	-- 			return tp:ValueBool("introduction")
	-- 			and not tp:ValueBool(self.tutoCategory)
	-- 		end,
	-- 		tutosOrdered = {
	-- 			"TM_editmode_editmodeBtn",
	-- 			"TM_editmode_delete",
	-- 			"TM_editmode_favdesc",
	-- 			"TM_editmode_rename",
	-- 			"TM_editmode_sort",
	-- 			"TM_editmode_resize",
	-- 			"TM_editmode_buttons",
	-- 			"TM_editmode_undo",
	-- 		},
	-- 	}
	-- )

	-- private:CreateTutoFrame(cat, "editmodeBtn", false, "DOWN", L["To delete items and do a lot more, you can right-click anywhere on the list or click on this button to toggle the edit mode"], 275)
	-- private:CreateTutoFrame(cat, "delete", true, "RIGHT", L["Delete items and categories"], 275)
	-- private:CreateTutoFrame(cat, "favdesc", true, "RIGHT", L["Favorite and add descriptions on items"], 275)
	-- private:CreateTutoFrame(cat, "rename", false, "UP", L["Rename items and categories"].." ("..L["Double-Click"]..")", 275)
	-- private:CreateTutoFrame(cat, "sort", false, "DOWN", L["Reorder/Sort the list"].." ("..L["Drag and Drop"]..")", 275)
	-- private:CreateTutoFrame(cat, "resize", true, "LEFT", L["Resize the list"], 275)
	-- private:CreateTutoFrame(cat, "buttons", true, "DOWN", L["Undo what you deleted and access special actions for the tab"], 275)
	-- private:CreateTutoFrame(cat, "undo", true, "DOWN", L["More specifically you can undo items, categories, and even tab deletions"], 275)

	-- // ******************** // --

	-- ...
end

table.insert(core.Event_OnInitialize_Start, private.CreateTutorials) -- we wait for the addon's initialization (when every file is loaded) before creating the tutorial frames
