-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local core = addonTable.core
local enums = addonTable.enums
local utils = addonTable.utils

-- Variables
local L = core.L

--/*******************/ COMMON (utils) FUNCTIONS /*************************/--

function utils:IsVersionOlderThan(latestVersion, vMax) -- equivalent thing as testing v < vMax
  if (not latestVersion) or (latestVersion == "") then return true end -- old version
  if not utils:HasValue(core.toc.versions, latestVersion) then return false end -- "future" version
  if not utils:HasValue(core.toc.versions, vMax) then return true end -- "future" version
  for i,version in ipairs(core.toc.versions) do -- from recent to old
    if version == latestVersion then
      return false
    elseif version == vMax then
      return true
    end
  end
end

function utils:GetAllVersionsOlderThan(v) -- returns a table containing every version number older than the given one
  if not utils:HasValue(core.toc.versions, v) then return utils:Deepcopy(core.toc.versions) end -- "future" version
  local versions = {}
  local startAdding = false
  for i,version in ipairs(core.toc.versions) do -- from recent to old
    if startAdding then
      table.insert(versions, version)
    elseif version == v then
      startAdding = true
    end
  end
  return versions
end

function utils:Clamp(number, min, max)
  return math.min(math.max(number, min), max)
end

function utils:RGBToHex(rgb)
  -- thanks to marceloCodget/gist:3862929 on GitHub

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
function utils:ThemeDownTo01(theme)
  local r, g, b = unpack(theme)

  wipe(T_ThemeDownTo01)
  table.insert(T_ThemeDownTo01, r/255)
  table.insert(T_ThemeDownTo01, g/255)
  table.insert(T_ThemeDownTo01, b/255)

  return T_ThemeDownTo01
end

local T_DimTheme = {}
function utils:DimTheme(theme, dim)
  local r, g, b = unpack(theme)

  wipe(T_DimTheme)
  table.insert(T_DimTheme, r*dim)
  table.insert(T_DimTheme, g*dim)
  table.insert(T_DimTheme, b*dim)

  return T_DimTheme
end

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
        copy[self:Deepcopy(orig_key, copies)] = self:Deepcopy(orig_value, copies)
      end
      setmetatable(copy, self:Deepcopy(getmetatable(orig), copies))
    end
  else -- number, string, boolean, etc
    copy = orig
  end
  return copy
end

function utils:SafeStringFormat(str, ...)
  -- safe format, in case there is an error in the localization (happened once)
  -- (we check if there are the necessary %x in the string, corresponding to the content of ...)
  -- only accepting %i and %s, it's enough for my use
  local dup = str
  for i=1, select("#", ...) do
    local var = select(i, ...)
    if var then
      local toMatch = (type(var) == "number") and "%%i" or "%%s"
      if (string.find(dup, toMatch)) then
        dup = string.gsub(dup, toMatch, "", 1)
      else
        return str.."|cffff0000 --> "..enums.translationErrMsg.."|r"
      end
    end
  end
  return str:format(...) -- it should be good
end

function utils:HasHyperlink(s)
  if s ~= nil then
    -- a hyperlink pattern has at least one '|H' and two '|h', so this is the closest test i can think of
    if (select(2, string.gsub(s, "|H", "")) >= 1) and (select(2, string.gsub(s, "|h", "")) >= 2) then
      return true
    end
  end
  return false
end

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

function utils:HasKey(tbl, key)
  if type(tbl) == "table" then -- just in case
	  for k in pairs(tbl) do
	    if (k == key) then
	      return true
	    end
	  end
  end
  return false
end

function utils:GetKeyFromValue(tabSource, value)
  for k, v in pairs(tabSource) do
    if v == value then return k end
  end
  return nil
end

function utils:ColorText(colorTable, text)
	-- alpha is 1
	return string.format("|cff%s%s|r", utils:RGBToHex(colorTable), text)
end
