--/*******************/ IMPORTS /*************************/--

-- File init

local utils = NysTDL.utils
NysTDL.utils = utils

-- Primary aliases

local libs = NysTDL.libs
local enums = NysTDL.enums

-- Secondary aliases

local L = libs.L

--/*******************************************************/--

--/*******************/ COMMON (utils) FUNCTIONS /*************************/--

---Compares the release type of both versions to figure out if v1's release type is older than v2.
---@param v1 string
---@param v2 string
---@return boolean # v1 < v2
function utils:IsReleaseTypeOlderThan(v1, v2)
    -- alpha < beta < release ("alpha" < "beta" < "")
    -- we first release alpha versions, then beta, then release
    -- (that's what I mean by "which release type is older", alpha is older than beta, which itself is older than release)

    local releaseTypes = {
        -- older
        "alpha",
        "beta",
        -- "",
        -- newer
    }

    local versions = {
        [v1] = 1,
        [v2] = 1
    }

    for v in pairs(versions) do
        for i,releaseType in ipairs(releaseTypes) do
            if string.find(v, releaseType) then
                break
            end
            versions[v] = i+1
        end
    end

    return versions[v1] < versions[v2]
end

---This function can compare two addon version strings,
---and tell if the first one is older than the second one
---(meaning: was v1 a version released before v2?).
---equivalent thing as testing v1 < v2
---@param v1 string
---@param v2 string
---@return boolean # v1 < v2 (is v1 older than v2)
function utils:IsVersionOlderThan(v1, v2)
    if (not v1) or (v1 == "") then return true end -- old version (special case)
    if (not v2) or (v2 == "") then return false end -- should never happen

    local f1 = string.gmatch(v1, "%d+")
    local f2 = string.gmatch(v2, "%d+")

    while true do
        local n1 = f1()
        local n2 = f2()

        if not n1 and not n2 then
            return utils:IsReleaseTypeOlderThan(v1, v2)
        end

        if not (n1 and n2) then
            return n2 and true or false
        end

        n1 = tonumber(n1)
        n2 = tonumber(n2)

        if n1 < n2 then
            return true
        elseif n1 > n2 then
            return false
        end
    end
end

---Clamps the given value between min and max.
---@param number number
---@param min number
---@param max number
---@return number clampedNumber
function utils:Clamp(number, min, max)
	return math.min(math.max(number, min), max)
end

---Floating point almost equal test.
---@param number1 number
---@param number2 number
---@param delta number default 0.01
---@return boolean AlmostEqual
function utils:Approximately(number1, number2, delta)
	delta = delta or 0.01
	return math.abs(number1-number2) <= delta
end

---Takes in a rgb index table ({r, g, b}), and returns the hexadecimal value ("ff00ff").
---@param rgb table
---@return string hex
function utils:RGBToHex(rgb)
	-- from marceloCodget/gist:3862929 on GitHub

	local hexadecimal = ""

	for _, value in pairs(rgb) do
		local hex = ''

		while value > 0 do
			local index = math.fmod(value, 16) + 1
			value = math.floor(value / 16)
			hex = string.sub('0123456789ABCDEF', index, index)..hex
		end

		if string.len(hex) == 0 then
			hex = '00'
		elseif string.len(hex) == 1 then
			hex = '0'..hex
		end

		hexadecimal = hexadecimal..hex
	end

	return hexadecimal
end

local T_ThemeDownTo01 = {}
---Takes in a rgb index table ({r, g, b}), and downgrades it from 0-255 to 0-1.
---@param theme table
---@return table theme01
function utils:ThemeDownTo01(theme, unpacked)
	local r, g, b = unpack(theme)

	wipe(T_ThemeDownTo01)
	table.insert(T_ThemeDownTo01, r/255)
	table.insert(T_ThemeDownTo01, g/255)
	table.insert(T_ThemeDownTo01, b/255)

	if unpacked == true then
		return T_ThemeDownTo01[1], T_ThemeDownTo01[2], T_ThemeDownTo01[3]
	end

	return T_ThemeDownTo01
end

local T_DimTheme = {}
---Takes in a rgb index table ({r, g, b}), and dims it by `dim`.
---@param theme table
---@param dim number
---@return table themeDimmed
function utils:DimTheme(theme, dim)
	local r, g, b = unpack(theme)

	wipe(T_DimTheme)
	table.insert(T_DimTheme, r*dim)
	table.insert(T_DimTheme, g*dim)
	table.insert(T_DimTheme, b*dim)

	return T_DimTheme
end

---Quick and easy check to know if we are currently running Dragonflight or not
---@return boolean
function utils:IsDF()
	return LE_EXPANSION_LEVEL_CURRENT >= 9
end

---To copy any table.
---@param orig table
---@param copies any Do not use
---@return table copy
function utils:Deepcopy(orig, copies)
	copies = copies or {}
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		if copies[orig] then
			copy = copies[orig]
		else
			copy = {}
			copies[orig] = copy
			for orig_key, orig_value in next, orig, nil do
				copy[utils:Deepcopy(orig_key, copies)] = utils:Deepcopy(orig_value, copies)
			end
			setmetatable(copy, utils:Deepcopy(getmetatable(orig), copies))
		end
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

---Safe format, in case there is an error in the localization (happened once).
---We check if there are the necessary %x in the string, corresponding to the content of `...`.
---Only accepting %i and %s, it's enough for my use.
---@param str string
---@param ... any
---@return string formattedString
function utils:SafeStringFormat(str, ...)
	local dup = str
	for i=1, select("#", ...) do
		local var = select(i, ...)
		if var then
			local toMatch = (type(var) == "number") and "%%i" or "%%s"
			if (string.find(dup, toMatch)) then
				dup = string.gsub(dup, toMatch, "", 1)
			else
				return str.." "..enums.translationErrMsg
			end
		end
	end
	return str:format(...) -- it should be good
end

---Helper to test if a string contains a wow hyperlink.
---@param s string
---@return boolean
function utils:HasHyperlink(s)
	if s ~= nil then
		-- a hyperlink pattern has at least one '|H' and two '|h', so this is the closest test I can think of
		-- TDLATER replace with a regex match
		if (select(2, string.gsub(s, "|H", "")) >= 1) and (select(2, string.gsub(s, "|h", "")) >= 2) then
			return true
		end
	end
	return false
end

---Helper to test if a table contains a given value.
---@param tbl table
---@param value any
---@return boolean isPresent
---@return string|number key
function utils:HasValue(tbl, value)
	local isPresent, key = false, 0
	if type(tbl) == "table" then -- just in case
		for k, v in pairs(tbl) do
			if v == value then
				isPresent = true
				key = k
				break
			end
		end
	end
	return isPresent, key
end

---Helper to test if a table contains a given key.
---@param tbl table
---@param key any
---@return boolean isPresent
function utils:HasKey(tbl, key)
	if type(tbl) == "table" then -- just in case
		for k in pairs(tbl) do
			if k == key then
				return true
			end
		end
	end
	return false
end

---Returns the first key matching the given value in the table.
---@param tabSource table
---@param value any
---@return string|number|nil key
function utils:GetKeyFromValue(tabSource, value)
	for k, v in pairs(tabSource) do
		if v == value then return k end
	end
	return nil
end

---Returns the given text colored with the given color table ({r,g,b}).
---@param colorTable table
---@param text string
---@return string
function utils:ColorText(colorTable, text)
	-- alpha is 1
	return string.format("|cff%s%s|r", utils:RGBToHex(colorTable), text)
end
