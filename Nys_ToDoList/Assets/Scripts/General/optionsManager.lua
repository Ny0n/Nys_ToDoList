--/*******************/ IMPORTS /*************************/--

-- File init

local optionsManager = NysTDL.optionsManager
NysTDL.optionsManager = optionsManager

-- Primary aliases

local libs = NysTDL.libs
local core = NysTDL.core
local enums = NysTDL.enums
local utils = NysTDL.utils
local widgets = NysTDL.widgets
local mainFrame = NysTDL.mainFrame
local tabsFrame = NysTDL.tabsFrame
local databroker = NysTDL.databroker
local dataManager = NysTDL.dataManager
local resetManager = NysTDL.resetManager
local importexport = NysTDL.importexport

-- Secondary aliases

local L = libs.L
local AceConfig = libs.AceConfig
local AceConfigDialog = libs.AceConfigDialog
local AceConfigRegistry = libs.AceConfigRegistry
local AceDBOptions = libs.AceDBOptions
local addonName = core.addonName

--/*******************************************************/--

-- Variables

local private = {}

local wDef = { toggle = 160, select = 265, range = 200, execute = 180, keybinding = 200, color = 180, input = 240 } -- the max width (this is for the locales), more than this and we scale

local frameStratas = {
	"DIALOG", -- [1]
	"HIGH", -- [2]
	"MEDIUM", -- [3]
	"LOW", -- [4]
}

--/*******************/ OPTIONS TABLES /*************************/--

function private:GetLeaf(info, x)
	local tbl = optionsManager.optionsTable

	for i=1,x do
		tbl = tbl.args[info[i]]
	end

	return tbl
end

function private:GetTabInfo(info)
	local tabID = private:GetLeaf(info, 4).arg
	local tabData = select(3, dataManager:Find(tabID))

	local resetData
	if tabData.reset.isSameEachDay then
		resetData = tabData.reset.sameEachDay
	else
		resetData = tabData.reset.days[tabData.reset.configureDay]
	end

	return tabID, tabData, resetData
end

local tabManagementTable = {
	-- / settings / --

	settingsTab = {
		order = 1.1,
		type = "group",
		name = L["Settings"],
		args = {
			removeTabExecute = {
				order = 1.1,
				type = "execute",
				name = L["Delete tab"],
				confirm = true,
				confirmText = L["Deleting this tab will delete everything that was created in it"]..".\n"..L["Are you sure?"],
				func = function(info)
					local tabID = private:GetTabInfo(info)
					dataManager:DeleteTab(tabID)
					private:RefreshTabManagement()
				end,
				disabled = function(info)
					local tabID = private:GetTabInfo(info)
					return dataManager:IsProtected(tabID)
				end,
			},
			removeTabDescription = {
				order = 1.2,
				type = "description",
				name = L["Cannot remove this tab"].."\n("..L["There must be at least one left"]..")",
				hidden = function(info)
					local tabID = private:GetTabInfo(info)
					return not dataManager:IsProtected(tabID)
				end,
			},
			moveTabUpExecute = {
				order = 1.3,
				type = "execute",
				name = L["Move up"],
				func = function(info)
					local tabID = private:GetTabInfo(info)
					local pos = dataManager:GetPosData(tabID, nil, true)
					dataManager:MoveTab(tabID, pos-1)
				end,
				disabled = function(info)
					local tabID = private:GetTabInfo(info)
					return dataManager:GetPosData(tabID, nil, true) <= 1
				end,
			},
			moveTabDownExecute = {
				order = 1.4,
				type = "execute",
				name = L["Move down"],
				func = function(info)
					local tabID = private:GetTabInfo(info)
					local pos = dataManager:GetPosData(tabID, nil, true)
					dataManager:MoveTab(tabID, pos+1)
				end,
				disabled = function(info)
					local tabID = private:GetTabInfo(info)
					local loc, pos = dataManager:GetPosData(tabID)
					return pos >= #loc
				end,
			},
			migrateTabExecute = {
				order = 1.5,
				type = "execute",
				name = L["Switch Global/Profile"],
				func = function(info)
					local tabID = private:GetTabInfo(info)
					dataManager:ChangeTabsGlobalState({[tabID] = true})
				end,
				disabled = function(info)
					local tabID = private:GetTabInfo(info)
					return dataManager:IsProtected(tabID)
				end,
			},
			renameTabInput = {
				order = 1.6,
				type = "input",
				name = L["Rename"],
				get = function(info)
					local _, tabData = private:GetTabInfo(info)
					return tabData.name
				end,
				set = function(info, newName)
					local tabID = private:GetTabInfo(info)
					dataManager:Rename(tabID, newName)
				end,
			},
			instantRefreshToggle = {
				order = 1.7,
				type = "toggle",
				name = L["Instant refresh"],
				desc = L["Delete/Hide items instantly when checking them"].."\n("..L["Applies to all tabs"]..")",
				get = function()
					return NysTDL.acedb.profile.instantRefresh
				end,
				set = function(_, state)
					NysTDL.acedb.profile.instantRefresh = state
					mainFrame:Refresh()
				end,
			},
			groupItemSettings = {
				order = 1.8,
				type = "group",
				name = L["Items"],
				inline = true,
				args = {
					deleteCheckedItemsToggle = {
						order = 1.1,
						type = "toggle",
						name = L["Delete checked items"],
						get = function(info)
							local _, tabData = private:GetTabInfo(info)
							return tabData.deleteCheckedItems
						end,
						set = function(info, state)
							local _, tabData = private:GetTabInfo(info)
							-- SAME CODE in var migrations (migrationData.codes["6.0"])
							tabData.deleteCheckedItems = state
							if state then
								tabData.hideCheckedItems = false
							end
							mainFrame:Refresh()
						end,
						disabled = function(info)
							local _, tabData = private:GetTabInfo(info)
							return tabData.hideCheckedItems
						end,
					},
					hideCheckedItemsToggle = {
						order = 1.2,
						type = "toggle",
						name = L["Hide checked items"],
						get = function(info)
							local _, tabData = private:GetTabInfo(info)
							return tabData.hideCheckedItems
						end,
						set = function(info, state)
							local _, tabData = private:GetTabInfo(info)
							-- SAME CODE in var migrations (migrationData.codes["6.0"])
							tabData.hideCheckedItems = state
							if state then
								tabData.deleteCheckedItems = false
							end
							mainFrame:Refresh()
						end,
						disabled = function(info)
							local _, tabData = private:GetTabInfo(info)
							return tabData.deleteCheckedItems
						end,
					},
				},
			},
			groupCategorySettings = {
				order = 1.9,
				type = "group",
				name = L["Categories"],
				inline = true,
				args = {
					hideCompletedCategoriesToggle = {
						order = 1.1,
						type = "toggle",
						name = L["Hide completed categories"],
						get = function(info)
							local _, tabData = private:GetTabInfo(info)
							return tabData.hideCompletedCategories
						end,
						set = function(info, state)
							local _, tabData = private:GetTabInfo(info)
							tabData.hideCompletedCategories = state
							mainFrame:Refresh()
						end,
					},
					hideEmptyCategoriesToggle = {
						order = 1.2,
						type = "toggle",
						name = L["Hide empty categories"],
						get = function(info)
							local _, tabData = private:GetTabInfo(info)
							return tabData.hideEmptyCategories
						end,
						set = function(info, state)
							local _, tabData = private:GetTabInfo(info)
							tabData.hideEmptyCategories = state
							mainFrame:Refresh()
						end,
					},
				},
			},
			shownTabsMultiSelect = {
				order = 2.0,
				type = "multiselect",
				name = L["Shown tabs"],
				width = "full",
				values = function(info)
					local originalTabID = private:GetTabInfo(info)
					local shownIDs = {}
					for tabID,tabData in dataManager:ForEach(enums.tab, private:GetLeaf(info, 3).arg) do
						if tabID ~= originalTabID then
							shownIDs[tabID] = tabData.name
						end
					end
					return shownIDs
				end,
				get = function(info, key)
					local _, tabData = private:GetTabInfo(info)
					return not not tabData.shownIDs[key]
				end,
				set = function(info, key, state)
					local tabID = private:GetTabInfo(info)
					dataManager:UpdateShownTabID(tabID, key, state)
				end,
			},

			-- / layout widgets / --

			-- spacers
			spacer121 = {
				order = 1.21,
				type = "description",
				width = "full",
				name = "\n",
			},
			spacer131 = {
				order = 1.31,
				type = "description",
				width = "full",
				name = "",
			},
			spacer141 = {
				order = 1.41,
				type = "description",
				width = "full",
				name = "\n",
			},
			spacer151 = {
				order = 1.51,
				type = "description",
				width = "full",
				name = "",
			},
			spacer161 = {
				order = 1.61,
				type = "description",
				width = "full",
				name = "",
			},
			spacer171 = {
				order = 1.71,
				type = "description",
				width = "full",
				name = "",
			},
			spacer181 = {
				order = 1.81,
				type = "description",
				width = "full",
				name = "",
			},
			spacer191 = {
				order = 1.91,
				type = "description",
				width = "full",
				name = "",
			},
			spacer201 = {
				order = 2.01,
				type = "description",
				width = "full",
				name = "",
			},

			-- headers
			header1 = {
				order = 1,
				type = "header",
				name = L["Settings"],
			},
			header159 = {
				order = 1.59,
				type = "header",
				name = L["Content"],
			},
		},
	},

	-- / auto-reset / --

	autoResetTab = {
		order = 1.2,
		type = "group",
		name = L["Auto-Reset"],
		args = {
			resetDaysSelect = {
				order = 2.1,
				type = "multiselect",
				name = L["Reset days"],
				width = "full",
				values = function()
					return enums.days
				end,
				get = function(info, key)
					local _, tabData = private:GetTabInfo(info)
					return not not tabData.reset.days[key]
				end,
				set = function(info, key, state)
					local tabID = private:GetTabInfo(info)
					resetManager:UpdateResetDay(tabID, key, state)
				end,
			},
			configureResetGroup = {
				order = 2.2,
				type = "group",
				name = L["Configure reset times"],
				inline = true,
				args = {
					isSameEachDayToggle = {
						order = 1.1,
						type = "toggle",
						name = L["Same each day"],
						get = function(info)
							local _, tabData = private:GetTabInfo(info)
							return tabData.reset.isSameEachDay
						end,
						set = function(info, state)
							local tabID = private:GetTabInfo(info)
							resetManager:UpdateIsSameEachDay(tabID, state)
						end,
					},
					configureDaySelect = {
						order = 1.2,
						type = "select",
						name = L["Configure day"],
						values = function(info)
							local _, tabData = private:GetTabInfo(info)
							local days = {}
							for day in pairs(tabData.reset.days) do
								days[day] = enums.days[day]
							end
							if not days[tabData.reset.configureDay] then
								tabData.reset.configureDay = next(days)
							end
							return days
						end,
						get = function(info)
							local _, tabData = private:GetTabInfo(info)
							return tabData.reset.configureDay
						end,
						set = function(info, value)
							local _, tabData = private:GetTabInfo(info)
							tabData.reset.configureDay = value
						end,
						hidden = function(info)
							local _, tabData = private:GetTabInfo(info)
							return tabData.reset.isSameEachDay
						end,
					},
					addNewResetTimeExecute = {
						order = 1.3,
						type = "execute",
						name = L["Add new reset"],
						func = function(info)
							local tabID, _, resetData = private:GetTabInfo(info)
							resetManager:AddResetTime(tabID, resetData)
						end,
					},
					removeResetTimeExecute = {
						order = 1.4,
						type = "execute",
						name = L["Remove reset"],
						func = function(info)
							local tabID, tabData, resetData = private:GetTabInfo(info)
							resetManager:RemoveResetTime(tabID, resetData, tabData.reset.configureResetTime)
						end,
						hidden = function(info)
							local _, _, resetData = private:GetTabInfo(info)
							return not resetManager:CanRemoveResetTime(resetData)
						end
					},
					configureResetTimeSelect = {
						order = 1.5,
						type = "select",
						name = L["Configure reset"],
						values = function(info)
							local _, tabData, resetData = private:GetTabInfo(info)
							local resets = {}
							for resetTimeName in pairs(resetData.resetTimes) do
								resets[resetTimeName] = resetTimeName
							end
							if not resets[tabData.reset.configureResetTime] then
								tabData.reset.configureResetTime = next(resets)
							end
							return resets
						end,
						get = function(info)
							local _, tabData = private:GetTabInfo(info)
							return tabData.reset.configureResetTime
						end,
						set = function(info, value)
							local _, tabData = private:GetTabInfo(info)
							tabData.reset.configureResetTime = value
						end,
					},
					renameResetTimeInput = {
						order = 1.6,
						type = "input",
						name = L["Rename"],
						get = function(info)
							local _, tabData = private:GetTabInfo(info)
							return tabData.reset.configureResetTime
						end,
						set = function(info, newName)
							local tabID, tabData, resetData = private:GetTabInfo(info)
							resetManager:RenameResetTime(tabID, resetData, tabData.reset.configureResetTime, newName)
						end,
					},
					hourResetTimeRange = {
						order = 1.7,
						type = "range",
						name = L["Hour"],
						width = "double",
						min = 0,
						max = 23,
						step = 1,
						get = function(info)
							local _, tabData, resetData = private:GetTabInfo(info)
							return resetData.resetTimes[tabData.reset.configureResetTime].hour
						end,
						set = function(info, value)
							local tabID, tabData, resetData = private:GetTabInfo(info)
							local timeData = resetData.resetTimes[tabData.reset.configureResetTime]
							resetManager:UpdateTimeData(tabID, timeData, value)
						end,
					},
					minResetTimeRange = {
						order = 1.8,
						type = "range",
						name = L["Minute"],
						width = "double",
						min = 0,
						max = 59,
						step = 1,
						get = function(info)
							local _, tabData, resetData = private:GetTabInfo(info)
							return resetData.resetTimes[tabData.reset.configureResetTime].min
						end,
						set = function(info, value)
							local tabID, tabData, resetData = private:GetTabInfo(info)
							local timeData = resetData.resetTimes[tabData.reset.configureResetTime]
							resetManager:UpdateTimeData(tabID, timeData, nil, value)
						end,
					},
					secResetTimeRange = {
						order = 1.9,
						type = "range",
						name = L["Second"],
						width = "double",
						min = 0,
						max = 59,
						step = 1,
						get = function(info)
							local _, tabData, resetData = private:GetTabInfo(info)
							return resetData.resetTimes[tabData.reset.configureResetTime].sec
						end,
						set = function(info, value)
							local tabID, tabData, resetData = private:GetTabInfo(info)
							local timeData = resetData.resetTimes[tabData.reset.configureResetTime]
							resetManager:UpdateTimeData(tabID, timeData, nil, nil, value)
						end,
					},

					-- / layout widgets / --

					spacer121 = {
						order = 1.21,
						type = "description",
						width = "full",
						name = "",
					},
					spacer141 = {
						order = 1.41,
						type = "description",
						width = "full",
						name = "",
					},
					spacer161 = {
						order = 1.61,
						type = "description",
						width = "full",
						name = "",
					},
					spacer171 = {
						order = 1.71,
						type = "description",
						width = "full",
						name = "",
					},
					spacer181 = {
						order = 1.81,
						type = "description",
						width = "full",
						name = "",
					},
				},
				hidden = function(info)
					local _, tabData = private:GetTabInfo(info)
					return not next(tabData.reset.days) -- the configure group only appears if there is at least one day selected
				end,
			},
		},
	},
}

local tabAddTable = {
	addGlobalInput = {
		order = 1.1,
		type = "input",
		name = L["Create a new global tab"],
		get = function()
			return ""
		end,
		set = function(info, tabName)
			dataManager:CreateTab(tabName, true)
		end,
	},
	addProfileInput = {
		order = 1.2,
		type = "input",
		name = L["Create a new profile tab"],
		get = function()
			return ""
		end,
		set = function(info, tabName)
			dataManager:CreateTab(tabName, false)
		end,
	},

	-- / layout widgets / --

	-- spacers
	spacer0 = {
		order = 1.109,
		type = "description",
		width = 0.01,
		name = "",
	},
	imageGlobal = {
		order = 1.11,
		type = "description",
		width = 0.1,
		name = "",
		image = enums.icons.global.info,
		imageCoords = enums.icons.global.texCoords,
	},
	spacer1 = {
		order = 1.12,
		type = "description",
		width = "full",
		name = "",
	},
	spacer2 = {
		order = 1.209,
		type = "description",
		width = 0.01,
		name = "",
	},
	imageProfile = {
		order = 1.21,
		type = "description",
		width = 0.1,
		name = "",
		image = enums.icons.profile.info,
		imageCoords = enums.icons.profile.texCoords,
	},
}

function private:UpdateTabsInOptions(options)
	-- local options = private:GetLeaf(info, 3)
	local arg, args = options.arg, options.args

	for k,v in pairs(args) do
		if v.type == "group" then
			args[k] = nil
		end
	end

	for tabID,tabData in dataManager:ForEach(enums.tab, arg) do -- for each tab in the correct profile state
		args[tabID] = { -- we add them as selectable sub-groups under the good parent
			order = function()
				return dataManager:GetPosData(tabID, nil, true)
			end,
			type = "group",
			childGroups = "tab",
			name = tabData.name,
			arg = tabID,
			args = tabManagementTable,
		}
	end
end

function private:RefreshTabManagement()
	-- !! this func is important, as it refreshes the profile/global groups contents when adding/removing tabs
	local profile = optionsManager.optionsTable.args.main.args.tabs.args["groupProfileTabManagement"]
	local global = optionsManager.optionsTable.args.main.args.tabs.args["groupGlobalTabManagement"]
	private:UpdateTabsInOptions(profile)
	private:UpdateTabsInOptions(global)
end

function private:CreateAddonOptionsTable()
	optionsManager.optionsTable = {
		handler = optionsManager,
		type = "group",
		name = core.toc.title.." ("..core.toc.version..core.toc.isDev..")",
		get = function(info)
			return NysTDL.acedb.profile[info[#info]]
		end,
		set = function(info, ...)
			if NysTDL.acedb.profile[info[#info]] ~= nil then
				NysTDL.acedb.profile[info[#info]] = ...
			end
		end,
		args = {
			main = {
				order = 0,
				type = "group",
				name = L["Options"],
				childGroups = "tab",
				args = {
					general = {
						order = 1,
						type = "group",
						name = L["General"],
						args = {

							-- / options widgets / --

							openBehavior = {
								order = 1.2,
								type = "select",
								name = L["Open behavior on login"],
								values = function()
									local openBehaviors = {
										[1] = L["None"],
										[2] = L["Remember"],
										[4] = L["Always open"],
										[5] = L["Open if not done"].." (<24h)",
										[6] = L["Open if not done"].." (<7d)",
										[7] = L["Open if not done"],
									 }
									return openBehaviors
								end,
							}, -- openBehavior
							frameStrata = {
								order = 1.35,
								type = "select",
								name = "",
								values = function()
									return frameStratas
								end,
								get = function()
									return select(2, utils:HasValue(frameStratas, NysTDL.acedb.profile.frameStrata))
								end,
								set = function(info, value)
									value = frameStratas[value]
									NysTDL.acedb.profile.frameStrata = value

									local tdlFrame = mainFrame:GetFrame()
									tdlFrame:SetFrameStrata(value)

									local descFrames = widgets:GetDescFrames()
									for _, descFrame in pairs(descFrames) do
										descFrame:SetFrameStrata(value)
									end
								end,
							}, -- frameStrata
							lockList = {
								order = 1.4,
								type = "toggle",
								name = L["Lock position"],
							}, -- lockList
							frameScale = {
								order = 1.3,
								type = "range",
								name = L["Font size"],
								min = 0.5,
								max = 2,
								step = 0.01,
								set = function(info, value)
									NysTDL.acedb.profile.frameScale = value
									mainFrame:RefreshScale()
								end,
							}, -- frameScale
							frameAlpha = {
								order = 1.5,
								type = "range",
								name = L["Frame opacity"],
								min = 0,
								max = 100,
								step = 1,
								set = function(info, value)
									mainFrame:Event_FrameAlphaSlider_OnValueChanged(value)
								end,
							}, -- frameAlpha
							frameContentAlpha = {
								order = 1.6,
								type = "range",
								name = L["Frame content opacity"],
								min = 60,
								max = 100,
								step = 1,
								set = function(info, value)
									mainFrame:Event_FrameContentAlphaSlider_OnValueChanged(value)
								end,
							}, -- frameContentAlpha
							affectDesc = {
								order = 1.7,
								type = "toggle",
								name = L["Apply to description frames"],
								desc = L["Share the opacity options of the list to the description frames"].." ("..L["Only when checked"]..")",
								set = function(info, value)
									NysTDL.acedb.profile.affectDesc = value
									mainFrame:Event_FrameAlphaSlider_OnValueChanged(NysTDL.acedb.profile.frameAlpha)
									mainFrame:Event_FrameContentAlphaSlider_OnValueChanged(NysTDL.acedb.profile.frameContentAlpha)
								end
							}, -- affectDesc
							rememberUndo = {
								order = 3.6,
								type = "toggle",
								name = L["Remember undos"],
								desc = L["Save undos between sessions"],
							}, -- rememberUndo
							addLast = {
								order = 3.7,
								type = "toggle",
								name = L["Add elements in last position"],
							}, -- addLast
							highlightOnFocus = {
								order = 3.5,
								type = "toggle",
								name = L["Highlight edit boxes"],
								desc = L["When clicking on edit boxes, automatically highlights the text inside"],
							}, -- highlightOnFocus
							descriptionTooltip = {
								order = 3.4,
								type = "toggle",
								name = L["Description tooltip"],
								desc = L["Show the item's description in a tooltip when hovering the icon"],
							}, -- descriptionTooltip
							favoritesColor = {
								order = 3.1,
								type = "color",
								name = L["Favorites color"],
								desc = L["Change the color for the favorite items"],
								get = function()
									return unpack(NysTDL.acedb.profile.favoritesColor)
								end,
								set = function(_, ...)
									NysTDL.acedb.profile.favoritesColor = { ... }
									mainFrame:UpdateVisuals()
								end,
								disabled = function()
									return NysTDL.acedb.profile.rainbow
								end,
							}, -- favoritesColor
							rainbow = {
								order = 3.2,
								type = "toggle",
								name = L["Rainbow"],
								desc = L["Too.. Many.. Colors..."],
							}, -- rainbow
							rainbowSpeed = {
								order = 3.3,
								type = "range",
								name = L["Rainbow speed"],
								desc = L["Because why not?"],
								min = 1,
								max = 6,
								step = 1,
								hidden = function() return not NysTDL.acedb.profile.rainbow end,
							}, -- rainbowSpeed
							tdlButtonShow = {
								order = 2.3,
								type = "toggle",
								name = L["Show movable button"],
								desc = utils:SafeStringFormat(L["Toggles the display of the %s button"], "\""..core.simpleAddonName.."\""),
								get = function()
									return NysTDL.acedb.profile.tdlButton.show
								end,
								set = function(_, value)
									NysTDL.acedb.profile.tdlButton.show = value
									widgets:RefreshTDLButton()
								end,
							}, -- tdlButtonShow
							lockTdlButton = {
								order = 2.4,
								type = "toggle",
								name = L["Lock position"],
								hidden = function()
									return not NysTDL.acedb.profile.tdlButton.show
								end
							}, -- lockTdlButton
							tdlButtonRed = {
								order = 2.5,
								type = "toggle",
								name = L["Red"],
								desc = L["Changes the color of the movable button if there are items left to do before tomorrow"],
								get = function()
									return NysTDL.acedb.profile.tdlButton.red
								end,
								set = function(_, value)
									NysTDL.acedb.profile.tdlButton.red = value
									widgets:UpdateTDLButtonColor()
								end,
								hidden = function()
									return not NysTDL.acedb.profile.tdlButton.show
								end
							}, -- tdlButtonShow
							minimapButtonHide = {
								order = 2.1,
								type = "toggle",
								name = L["Show minimap button"],
								get = function()
									return not NysTDL.acedb.profile.minimap.hide
								end,
								set = function(_, value)
									NysTDL.acedb.profile.minimap.hide = not value
									databroker:RefreshMinimapButton()
								end,
							}, -- minimapButtonHide
							minimapButtonTooltip = {
								order = 2.2,
								type = "toggle",
								name = L["Show tooltip"],
								desc = L["Show the tooltip of the minimap/databroker button"],
								get = function()
									return NysTDL.acedb.profile.minimap.tooltip
								end,
								set = function(_, value)
									NysTDL.acedb.profile.minimap.tooltip = value
									databroker:RefreshMinimapButton()
								end,
								-- disabled = function()
								-- 	return NysTDL.acedb.profile.minimap.hide
								-- end,
							}, -- minimapButtonTooltip
							keyBind = {
								type = "keybinding",
								name = L["Show/Hide the To-Do List"],
								desc = L["Bind a key to toggle the list"],
								order = 1.1,
								get = function()
									return GetBindingKey(core.bindings.toggleList)
								end,
								set = function(_, newKey)
									-- we only want one key to be ever bound to this
									local key1, key2 = GetBindingKey(core.bindings.toggleList) -- so first we get both keys associated to thsi addon (in case there are)
									-- then we delete their binding from this addon (we clear every binding from this addon)
									if key1 then SetBinding(key1) end
									if key2 then SetBinding(key2) end

									-- and finally we set the new binding key
									if newKey ~= '' then -- considering we pressed one (not ESC)
										SetBinding(newKey, core.bindings.toggleList)
									end

									-- and save the changes

									if AttemptToSaveBindings then
										AttemptToSaveBindings(GetCurrentBindingSet())
									else
										SaveBindings(GetCurrentBindingSet())
									end
								end,
							}, -- keyBind

							-- / layout widgets / --

							-- spacers
							spacer111 = {
								order = 1.21,
								type = "description",
								width = "full",
								name = "",
							}, -- spacer199
							spacer131 = {
								order = 1.41,
								type = "description",
								width = "full",
								name = "",
							}, -- spacer131
							spacer199 = {
								order = 1.99,
								type = "description",
								width = "full",
								name = "\n",
							}, -- spacer199
							spacer221 = {
								order = 2.21,
								type = "description",
								width = "full",
								name = "",
							}, -- spacer221
							spacer299 = {
								order = 2.99,
								type = "description",
								width = "full",
								name = "\n",
							}, -- spacer299
							spacer331 = {
								order = 3.31,
								type = "description",
								width = "full",
								name = "",
							}, -- spacer331
							spacer399 = {
								order = 3.99,
								type = "description",
								width = "full",
								name = "\n",
							}, -- spacer399

							-- headers
							header1 = {
								order = 1,
								type = "header",
								name = L["List"],
							}, -- header1
							header2 = {
								order = 2,
								type = "header",
								name = L["Buttons"],
							}, -- header2
							header3 = {
								order = 3,
								type = "header",
								name = L["Settings"],
							}, -- header3
						}, -- args
					}, -- general
					chat = {
						order = 2,
						type = "group",
						name = L["Chat Messages"],
						args = {
							showChatMessages = {
								order = 0.1,
								type = "toggle",
								name = L["Show chat messages"],
								desc = L["Enable or disable non-essential chat messages"].."\n("..L["Warnings ignore this option"]..")",
							}, -- showChatMessages
							showWarnings = {
								order = 1.1,
								type = "toggle",
								name = L["Show warnings"],
								desc = L["Enable or disable the chat warning/reminder system"].."\n("..L["Chat message when logging in"]..")",
							}, -- showWarnings
							groupWarnings = {
								order = 1.2,
								type = "group",
								name = L["Warnings"]..":",
								inline = true,
								hidden = function() return not NysTDL.acedb.profile.showWarnings end,
								args = {
									favoritesWarning = {
										order = 1.1,
										type = "toggle",
										name = L["Favorites warning"],
										desc = L["Enable warnings for favorite items"],
									}, -- favoritesWarning
									normalWarning = {
										order = 1.2,
										type = "toggle",
										name = L["Normal warning"],
										desc = L["Enable warnings for non-favorite items"],
									}, -- normalWarning
									hourlyReminder = {
										order = 1.3,
										type = "toggle",
										name = L["Hourly reminder"],
										desc = L["Show warnings every 60 min following your log-in time"],
										disabled = function()
											return not (NysTDL.acedb.profile.favoritesWarning or NysTDL.acedb.profile.normalWarning)
										end,
									}, -- hourlyReminder
								}
							}, -- groupWarnings

							-- / layout widgets / --

							-- spacers
							spacer011 = {
								order = 0.99,
								type = "description",
								width = "full",
								name = "\n",
							}, -- spacer011

							-- headers
							header1 = {
								order = 0,
								type = "header",
								name = L["General"],
							}, -- header1
							header2 = {
								order = 1,
								type = "header",
								name = L["Warnings"],
							}, -- header2
						} -- args
					}, -- chat
					tabs = {
						order = 3,
						type = "group",
						name = L["Tabs"],
						args = {
							optionsUpdater = {
								-- this is completely hidden from the UI and is only here to silently update
								-- the tab groups whenever there is a change.
								order = 0.1,
								type = "toggle",
								name = "options updater",
								-- whenever a setter is called when this tab of the options is opened OR we opened this tab,
								-- AceConfig will call each getter/disabled/hidden values of everything present on the page,
								-- so putting the update func here actually works really well
								hidden = function()
									private:RefreshTabManagement()
									widgets:UpdateTDLButtonColor() -- in case we changed reset times
									tabsFrame:Refresh() -- in case we changed tab data
									return true
								end,
							}, -- optionsUpdater
							groupTabManagement = {
								order = 1,
								type = "group",
								name = L["Tab Management"],
								args = tabAddTable,
							},
							groupGlobalTabManagement = {
								order = 1.1,
								type = "group",
								name = L["Global tabs"],
								arg = true,
								args = {},
							}, -- groupGlobalTabManagement
							groupProfileTabManagement = {
								order = 1.2,
								type = "group",
								name = L["Profile tabs"],
								arg = false,
								args = {},
							}, -- groupProfileTabManagement
						} -- args
					}, -- tabs
					importexport = {
						order = 4,
						type = "group",
						name = L["Import"].."/"..L["Export"],
						args = {
							header1 = {
								order = 1,
								type = "header",
								name = L["Import"],
							},
							importExecute = {
								order = 1.1,
								type = "execute",
								name = L["Import tabs"],
								func = function()
									StaticPopup_Hide("NysTDL_StaticPopupDialog")
									StaticPopupDialogs["NysTDL_StaticPopupDialog"] = {
										text = core.toc.title.." - "..L["Import tabs"].."\n\n"..L["Do you wish to create a backup before proceeding?"],
										button1 = YES,
										button2 = NO,
										selectCallbackByIndex = true,
										OnButton1 = function()
											importexport:ShowIEFrame(true, nil, false)
											NysTDLBackup:OpenList()
										end,
										OnButton2 = function()
											importexport:ShowIEFrame(true)
										end,
										OnShow = function(self)
											self:SetWidth(320) -- reset the width, because the closeButton sets it to 420
										end,
										closeButton = true,
										closeButtonIsHide = true,
										timeout = 0,
										whileDead = true,
										hideOnEscape = true,
										preferredIndex = 3,
									}
									StaticPopup_Show("NysTDL_StaticPopupDialog")
								end,
							},
							spacer111 = {
								order = 1.11,
								type = "description",
								width = "full",
								name = "",
							},
							overrideDataSelect = {
								order = 1.2,
								type = "select",
								name = L["Data to overwrite on import"],
								desc = L["Delete the selected data to keep only what is imported (only if there is something to import)"].."\n"..L["Can be undone by pressing the list's undo button"],
								values = function()
									return importexport.dataToOverrideOnImportTypes
								end,
								get = function()
									return importexport.dataToOverrideOnImport
								end,
								set = function(_, value)
									importexport.dataToOverrideOnImport = value
								end,
							},
							header2 = {
								order = 2,
								type = "header",
								name = L["Export"],
							},
							exportExecute = {
								order = 2.1,
								type = "execute",
								name = L["Export selected tabs"],
								func = function()
									importexport:LaunchExportProcess()
								end,
								disabled = function()
									return importexport:CountSelectedTabs() <= 0
								end
							},
							exportTabsDropDownExecute = {
								order = 2.2,
								type = "execute",
								name = "",
								func = importexport.OpenTabsSelectMenu,
								image = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up",
								width = 0.18,
							},
						} -- args
					} -- importexport
					-- new main tab
				}, -- args
			}, -- main
			child_profiles = {
				order = 1,
				type = "group",
				name = L["Profiles"],
				childGroups = "tab",
				args = {
					-- ** new profiles tab (created from AceDBOptions) **
				}, -- args
			} -- child_profiles
		} -- args
	}
end

---This is a helper used to update the `width` field of everything in the given options table.
---If the actual locale width is larger than the standard width (@see wDef), it updates it to match the locale width.
---@param tbl table The options table.
---@param wDef table The standard width table.
function private:InitializeOptionsWidthRecursive(tbl, wDef)
	for _,v in pairs(tbl) do
		if v.type == "group" then
			private:InitializeOptionsWidthRecursive(v.args, wDef)
		elseif v.type ~= "description" and v.type ~= "header" then -- for every widget (except the descriptions and the headers), we keep their min normal width, we change it only if their name is bigger than the default width
			local w = widgets:GetWidth(v.name)
			if wDef[v.type] then
				-- print (v.name.."_"..w)
				w = tonumber(string.format("%.3f", w/wDef[v.type]))
				if w > 1 then
					v.width = w -- w is a factor
				end
			end
		end
	end
end

--/*******************/ GENERAL FUNCTIONS /*************************/--

---Toggles the interface addon frame.
---@param fromFrame boolean Did we call this func from the mainFrame?
function optionsManager:ToggleOptions(fromFrame)
	if InterfaceOptionsFrame then
		if InterfaceOptionsFrame:IsShown() then -- if the interface options frame is currently opened
			if InterfaceOptionsFrameAddOns.selection ~= nil then -- then we check if we're currently in the AddOns tab and if we are currently selecting an addon
				if InterfaceOptionsFrameAddOns.selection.name == core.toc.title then -- and if we are, we check if we're looking at this addon
					if fromFrame then return true end
						InterfaceOptionsFrame:Hide() -- and only if we are and we click again on the button, we close the interface options frame.
					return
				end
			end
			InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
		else
			InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
			if InterfaceOptionsFrameAddOns.selection == nil then -- for the first opening, we have to do it 2 time for it to correctly open our addon options page
				InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
			end
		end
	elseif Settings then
		-- if SettingsPanel:IsShown() then
		-- 	SettingsPanel:Close(true)
		-- 	return
		-- end
		Settings.OpenToCategory(optionsManager.optionsFrameID)
	end

	AceConfigRegistry:NotifyChange(addonName)
end

--/*******************/ INITIALIZATION /*************************/--

function optionsManager:Initialize()
	-- first things first, we create the addon's options table
	-- we do that here so that we have access to other files's functions and data
	private:CreateAddonOptionsTable()

	-- this is for adapting the width of the widgets to the length of their respective names (that can change with the locale)
	private:InitializeOptionsWidthRecursive(optionsManager.optionsTable.args.main.args, wDef)
	private:InitializeOptionsWidthRecursive(tabManagementTable, wDef)

	-- we register our options table for AceConfig
	AceConfigRegistry:ValidateOptionsTable(optionsManager.optionsTable, addonName)
	AceConfig:RegisterOptionsTable(addonName, optionsManager.optionsTable)

	-- then we add the profiles management, using AceDBOptions
	optionsManager.optionsTable.args.child_profiles.args.profiles = AceDBOptions:GetOptionsTable(NysTDL.acedb)
	-- we also modify it a bit to better fit our needs (by adding some confirm pop-ups)
	local args = utils:Deepcopy(optionsManager.optionsTable.args.child_profiles.args.profiles.args)
	args.reset.confirm = true
	args.reset.confirmText = L["Warning"]:upper().."\n\n"..L["Resetting this profile will also clear the list"]..".\n"..L["Are you sure?"].."\n"
	args.copyfrom.confirm = true
	args.copyfrom.confirmText = L["This action will overwrite your settings, including the list"]..".\n"..L["Are you sure?"].."\n"
	optionsManager.optionsTable.args.child_profiles.args.profiles.args = args

	-- we add our frame to wow's interface options panel
	optionsManager.optionsFrame, optionsManager.optionsFrameID = AceConfigDialog:AddToBlizOptions(addonName, core.toc.title, nil, "main")
	AceConfigDialog:AddToBlizOptions(addonName, L["Profiles"], core.toc.title, "child_profiles")
end
