-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local utils = addonTable.utils

-- Variables
local L = addonTable.core.L

--/*******************/ COMMON (utils) FUNCTIONS /*************************/--

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
        return str.."|cffff0000 --> !"..L["translation error"].."!|r"
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

function utils:HasValue(table, value)
  local isPresent, key = false, 0
  if type(table) == "table" then -- just in case
	  for k, v in pairs(table) do
	    if v == value then
	      isPresent = true
	      key = k
	      break
	    end
	  end
  end
  return isPresent, key
end

function utils:HasKey(table, key)
  if type(table) == "table" then -- just in case
	  for k in pairs(table) do
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
