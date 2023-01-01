--/*******************/ IMPORTS /*************************/--

-- File init

local impexp = NysTDL.impexp
NysTDL.impexp = impexp

-- Primary aliases

local libs = NysTDL.libs
local widgets = NysTDL.widgets

-- Secondary aliases

local L = libs.L
local AceSerializer = libs.AceSerializer
local LibDeflate = libs.LibDeflate
local AceGUI = libs.AceGUI

--/*******************************************************/--

---@class impexp.deflateMethod
impexp.deflateMethod = {
	PRINT = 1,
	WOW_ADDON_CHANNEL = 2,
	WOW_CHAT_CHANNEL = 3,
 }

---Exports as a string the given data, using the given deflate method.
---Order of operation: Serialize -> Compress -> Encode -> return
---@param data any
---@param method impexp.deflateMethod
---@return string encodedData
function impexp:Export(data, method)
	if type(data) == "nil" then return end

    local serialized = AceSerializer:Serialize(data)
	if not serialized then return end

    local compressed = LibDeflate:CompressDeflate(serialized, {level = 9})
	if not compressed then return end

	local encoded
	if method == impexp.deflateMethod.WOW_ADDON_CHANNEL then
		encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)
	elseif method == impexp.deflateMethod.WOW_CHAT_CHANNEL then
		encoded = LibDeflate:EncodeForWoWChatChannel(compressed)
	else
		encoded = LibDeflate:EncodeForPrint(compressed)
	end

    return encoded
end

---Imports the given text, using the given deflate method.
---Order of operation: Decode -> Decompress -> Deserialize -> return
---@param text string
---@param method impexp.deflateMethod
---@return any decodedData
function impexp:Import(text, method)
	if type(text) ~= "string" then return end

	local decoded
	if method == impexp.deflateMethod.WOW_ADDON_CHANNEL then
		decoded = LibDeflate:DecodeForWoWAddonChannel(text)
	elseif method == impexp.deflateMethod.WOW_CHAT_CHANNEL then
		decoded = LibDeflate:DecodeForWoWChatChannel(text)
	else
		decoded = LibDeflate:DecodeForPrint(text)
	end
    if not decoded then return end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return end

    local success, data = AceSerializer:Deserialize(decompressed)
    if not success then return end

    return data
end

function impexp:TryToImport(editbox)
	if not editbox or not editbox.GetText then return end

	local success
	local decodedData = impexp:Import(editbox:GetText())
	if decodedData then
		print("Import successful")
		-- import data...
		success = true
	else
		print("Import error")
		success = false
	end

	collectgarbage()
	return success
end

---Shows an editbox where the player can copy or paste serialized data
function impexp:ShowIEFrame(title, statusText, data)
	local frame = AceGUI:Create("Frame")
	frame:SetTitle(title or "")
	frame:SetStatusText(statusText or "")
	frame:SetLayout("Fill")
	frame:SetWidth(525)
	frame:SetHeight(375)
	frame:SetCallback("OnClose", function(widget)
		AceGUI:Release(widget)
	end)

	local editbox = AceGUI:Create("MultiLineEditBox")
	editbox.editBox:SetFontObject("GameFontHighlightSmall")
	editbox:SetLabel("")
	editbox:SetFullWidth(true)
	editbox:SetFullHeight(true)
	frame:AddChild(editbox)

	if type(data) == "string" then
		editbox:SetText(data)
		editbox.button:SetEnabled(true)
		editbox.button:SetText(L["Ctrl+A"])
		editbox.button:SetScript("OnClick", function()
			widgets:SetFocusEditBox(editbox, true)
		end)
	else
		editbox.button:SetEnabled(false)
		editbox.button:SetText(L["Import"])
		editbox.button:SetScript("OnClick", function()
			if impexp:TryToImport(editbox) then
				frame:Hide()
			end
		end)
	end
end
