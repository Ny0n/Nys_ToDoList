-- Namespace
local _, addonTable = ...

local utils = addonTable.utils

--/*******************/ Functions /*************************/--

function utils:GetCurrentPlayerName()
	local playerName, realmName = UnitFullName("player")
	return playerName.."-"..realmName
end

function utils:IsValidVariableName(name)
	return not not (type(name) == "string" and name:match("^[%a_]+") and name:match("^[%w_]*$"))
end

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
				return str.." << TRANSLATION ERROR"
			end
		end
	end
	return str:format(...) -- it should be good
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
