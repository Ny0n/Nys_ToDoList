local addonName = ...

local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "frFR")
if not L then return end

-- ============================================ --

--@localization(locale="frFR", format="lua_additive_table", handle-unlocalized="ignore", same-key-is-true=true)@

--@do-not-package@
local addonTable = (select(2, ...))
for k, v in pairs(addonTable.devLocale) do
  L[k] = v
end
--@end-do-not-package@
