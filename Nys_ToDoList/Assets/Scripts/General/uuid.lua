-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local uuid = addonTable.uuid

-- Variables
local random = math.random

--/*******************/ UUID /*************************/--

function uuid:newraw()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

function uuid:new(toCheck)
  -- first, we generate a new uuid
  local new = uuid:newraw()

  -- then, if we sent a table here, we check that the uuid is not in there already (as a key)
  -- this is a bit overkill, i know :D
  if type(toCheck) == "table" then
    while toCheck[new] ~= nil do new = uuid:newraw() end
  end

  return new
end
