local addonName = ...

-- default language
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true)

-- ============================================ --

--@localization(locale="enUS", format="lua_additive_table", same-key-is-true=true)@

--@do-not-package@

-- this code, present in every localization file,
-- as well as the "devLocale.lua" script are used for local development and testing for translations.

-- basically, it allows me to never touch any localization file.
-- all I have to do is update the table inside the dev file as I wish,
-- and any changes that I do in it will instantly be applied to every locale,
-- and be visible whichever the current language my game is in.

local addonTable = (select(2, ...))
for k, v in pairs(addonTable.devLocale) do
	L[k] = v
end

--@end-do-not-package@
