--------------------------------------
-- Namespaces
--------------------------------------
local _, tdlTable = ...;
tdlTable.config = {}; -- adds config table to addon namespace

local config = tdlTable.config;

--------------
-- Database
--------------

local database = {
	theme = {
		r = 0,
		g = 0.8, -- 204/255
		b = 1,
		hex = "00ccff"
	},
}

--------------------------------------
-- General config functions
--------------------------------------

-- Other general purposes functions:
function config:Print(...)
    local hex = (select(4, config:GetThemeColor()));
    local prefix = string.format("|cff%s%s|r", hex:upper(), "ToDoList:");

    local tab = {}
    for i = 0, #... do
      local s = (select(i+1, ...))
      if type(s) == "table" then
        for i = 0, #s do
          table.insert(tab, (select(i+1, unpack(s))))
        end
      else
        table.insert(tab, s)
      end
    end

    DEFAULT_CHAT_FRAME:AddMessage(string.join(' ', prefix, unpack(tab)))
end

function config:GetThemeColor()
	local c = database.theme;
	return c.r, c.g, c.b, c.hex;
end

function config:HasItem(table, item)
	local isPresent = false;
	local pos = 0;
	for key,value in pairs(table) do
		if (value == item) then
			isPresent = true;
			pos = key;
			break;
		end
	end
	return isPresent, pos;
end

function config:HasKey(table, key)
	for k,v in pairs(table) do
		if (k == key) then
			return true;
		end
	end
	return false;
end

function config:HasAtLeastOneItem(tabSource,tabDest)
	for i=1,#tabSource do
		if (config:HasItem(tabDest,tabSource[i])) then
			return true;
		end
	end
	return false;
end

function config:GetTimeUntilReset()
	local dateValue = date("*t");

	local function gethours()
		local n = 0;
		local value = dateValue.hour;
		while (value ~= 9) do
			if (value == 24) then
				value = 0;
			end
			n = n+1;
			value = value+1;
		end

		if (n == 0) then
			n = 24;
		end
		return n-1; -- because min and sec are displayed
	end

	local function getdays()
		local n = 0;
		local value = dateValue.wday;
		if (dateValue.hour >= 9) then
			value = value+1;
		end
		while (value ~= 4) do
			if (value == 8) then
				value = 1;
			end
			n = n+1;
			value = value+1;
		end
		return n;
	end

	local timeUntil = {
		days = getdays(),
		hour = gethours(),
		min = math.abs(dateValue.min-59),
		sec = math.abs(dateValue.sec-59),
	}

	return timeUntil;
end

function config:GetSecondsToReset()
	local secondsUntil = {
		weekly = config:GetTimeUntilReset().days * 24 * 60 * 60
		+ config:GetTimeUntilReset().hour * 60 * 60
		+ config:GetTimeUntilReset().min * 60
		+ config:GetTimeUntilReset().sec
		+ time(),

		daily = config:GetTimeUntilReset().hour * 60 * 60
		+ config:GetTimeUntilReset().min * 60
		+ config:GetTimeUntilReset().sec
		+ time(),
	}

	return secondsUntil;
end

-- Widget creation functions:--
function config:CreateButton(point, relativeFrame, relativePoint, xOffset, yOffset, text)
	local btn = CreateFrame("Button", nil, relativeFrame, "UIPanelButtonTemplate");
	btn:SetPoint(point, relativeFrame, relativePoint, xOffset, yOffset);
	btn:SetSize(140, 40);
	btn:SetText(text);
	btn:SetNormalFontObject("GameFontNormalLarge");
	btn:SetHighlightFontObject("GameFontHighlightLarge");
	return btn;
end

function config:CreateMinusButton(relativeCheckButton)
	local btn = CreateFrame("Button", nil, relativeCheckButton, "UIPanelCloseButton");
	btn:SetPoint("LEFT", relativeCheckButton, "LEFT", -25, 0);
	btn:SetSize(25, 25);
	btn:SetNormalFontObject("GameFontNormalLarge");
	btn:SetHighlightFontObject("GameFontHighlightLarge");
	return btn;
end

function config:CreateAddButton(relativeEditBox)
	local btn = CreateFrame("Button", nil, relativeEditBox, "UIPanelButtonTemplate");
	btn:SetPoint("RIGHT", relativeEditBox, "RIGHT", 20, 0);
	btn:SetSize(18, 15);
	btn:SetText("+");
	btn:SetNormalFontObject("GameFontNormalLarge");
	btn:SetHighlightFontObject("GameFontHighlightLarge");
	return btn;
end

function config:CreateNoPointsLabelEditBox(name)
	local edb = CreateFrame("EditBox", name, nil, "InputBoxTemplate");
	edb:SetSize(130, 30);
	edb:SetAutoFocus(false);
	return edb;
end

function config:CreateLabel(point, relativeFrame, relativePoint, xOffset, yOffset, text)
	local label = relativeFrame:CreateFontString(nil);
	label:SetPoint(point, relativeFrame, relativePoint, xOffset, yOffset);
	label:SetFontObject("GameFontHighlightLarge");
	label:SetText(text);
	return label;
end

function config:CreateNoPointsLabel(relativeFrame, name, text)
	local label = relativeFrame:CreateFontString(name);
	label:SetFontObject("GameFontHighlightLarge");
	label:SetText(text);
	return label;
end

function config:CreateNothingLabel(relativeFrame)
	local label = relativeFrame:CreateFontString(nil);
	label:SetFontObject("GameFontHighlightLarge");
	label:SetText("There are no items!");
	label:SetTextColor(0.5,0.5,0.5,0.5);
	return label;
end

function config:CreateDummy(relativeFrame, xOffset, yOffset)
	local dummy = CreateFrame("Frame", nil, ItemsFrameUI, nil);
	dummy:SetPoint("TOPLEFT", relativeFrame, "TOPLEFT", xOffset, yOffset);
	dummy:SetSize(1, 1);
  dummy:Show();
	return dummy;
end
