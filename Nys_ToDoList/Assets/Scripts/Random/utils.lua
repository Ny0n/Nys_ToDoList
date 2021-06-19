-- Namespaces
local addonName, addonTable = ...

local config = addonTable.config
local utils = addonTable.utils
local autoReset = addonTable.autoReset
local widgets = addonTable.widgets
local itemsFrame = addonTable.itemsFrame
local init = addonTable.init

-- Variables

local L = config.L

--/*******************/ COMMON (utils) FUNCTIONS /*************************/--

function utils.print(...)
  if (not NysTDL.db.profile.showChatMessages) then return end -- we don't print anything if the user chose to deactivate this
  utils.printForced(...)
end

local T_printForced = {}
function utils.printForced(...)
  if (... == nil) then return end

  local hex = utils.RGBToHex(config.database.theme)
  local prefix = string.format("|cff%s%s|r", hex, config.toc.title..':')

  wipe(T_printForced)
  local message = T_printForced
  for i = 1, select("#", ...) do
    local s = (select(i, ...))
    if type(s) == "table" then
      for j = 1, #s do
        table.insert(message, (select(j, unpack(s))))
      end
    else
      table.insert(message, s)
    end
  end

  DEFAULT_CHAT_FRAME:AddMessage(string.join(' ', prefix, unpack(message)))
end

function utils.RGBToHex(rgb)
	local hexadecimal = ""

	for _, value in pairs(rgb) do
		local hex = ''

		while(value > 0)do
			local index = math.fmod(value, 16) + 1
			value = math.floor(value / 16)
			hex = string.sub('0123456789ABCDEF', index, index) .. hex
		end

		if(string.len(hex) == 0)then
			hex = '00'

		elseif(string.len(hex) == 1)then
			hex = '0' .. hex
		end

		hexadecimal = hexadecimal..hex
	end

	return hexadecimal
end

local T_themeDownTo01 = {}
function utils.themeDownTo01(theme)
  local r, g, b = unpack(theme)

  wipe(T_themeDownTo01)
  table.insert(T_themeDownTo01, r/255)
  table.insert(T_themeDownTo01, g/255)
  table.insert(T_themeDownTo01, b/255)

  return T_themeDownTo01
end

local T_dimTheme = {}
function utils.dimTheme(theme, dim)
  local r, g, b = unpack(theme)

  wipe(T_dimTheme)
  table.insert(T_dimTheme, r*dim)
  table.insert(T_dimTheme, g*dim)
  table.insert(T_dimTheme, b*dim)

  return T_dimTheme
end

function utils.deepcopy(orig, copies)
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
                copy[utils.deepcopy(orig_key, copies)] = utils.deepcopy(orig_value, copies)
            end
            setmetatable(copy, utils.deepcopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function utils.safeStringFormat(str, ...)
  -- safe format, in case there is an error in the localization (happened once)
  -- (we check if there are the necessary %x in the string, corresponding to the content of ...)
  -- only accepting %i and %s, it's enough for my use
  local dup = str
  for i=1, select("#", ...) do
    local var = select(i, ...)
    if (var) then
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

function utils.hasHyperlink(s)
  if s ~= nil then
    -- a hyperlink pattern has at least one '|H' and two '|h', so this is the closest test i can think of
    if (select(2, string.gsub(s, "|H", "")) >= 1) and (select(2, string.gsub(s, "|h", "")) >= 2) then
      return true
    end
  end
  return false
end

function utils.hasItem(table, item)
  if type(table) ~= "table" then -- just in case
    return false, 0
  end

  local isPresent = false
  local pos = 0
  for key, value in pairs(table) do
    if (value == item) then
      isPresent = true
      pos = key
      break
    end
  end
  return isPresent, pos
end

function utils.hasKey(table, key)
  if type(table) ~= "table" then -- just in case
    return false
  end

  for k in pairs(table) do
    if (k == key) then
      return true
    end
  end
  return false
end

function utils.itemExists(catName, itemName)
  -- returns true or false, depending on the existence of the item
  -- it's basically a sanity check for functions that need it
  if utils.hasKey(NysTDL.db.profile.itemsList, catName) then
    if utils.hasKey(NysTDL.db.profile.itemsList[catName], itemName) then
      return true
    end
  end
  return false
end

function utils.getKeyFromValue(tabSource, value)
  for k, v in pairs(tabSource) do
    if v == value then return k end
  end
  return nil
end
