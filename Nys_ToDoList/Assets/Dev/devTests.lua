-- pure lua testing

-- local a = {
--
-- }
--
-- a[10] = {5}
-- a[42] = {78}
--
-- for k,v in pairs(a) do
--   print("ola")
--   print(k, v)
-- end
--
-- a[42] = nil
--
-- for k,v in pairs(a) do
--   print("ola")
--   print(k, v)
-- end

-- local a = {}
-- for i=1,100 do
--   if true then
--     a[i] = i*42
--   end
-- end
-- print(next(a))

--
-- for k,v in pairs(a) do
--   a[k] = v*42
--   --print(k, a[k])
-- end

-- local date = os.date("*t")
-- for k,v in pairs(date) do
--   print(k, v)
-- end

local a = {}
a["ola"] = 5
a["bla"] = 6
a["nil"] = 7

for k,v in next, a do
  print(k, v)
end

print(next(a, nil))
print(next(a, "ola"))
for i = 1, 3 do

end

-- local a = { ["ola"] = 1, ["bla"] = 2, ["oula"] = 3 }
-- local a = { 1, 2, 3 }
-- local b = {[next(a)] = 55}
-- print(table.remove(a, 1))
-- print(next(a))
-- print(next(b))
-- print(nil or false)
-- select(2, nil)
