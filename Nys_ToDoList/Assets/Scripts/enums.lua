-- Namespaces
local addonName, addonTable = ...

-- addonTable aliases
local enums = addonTable.enums

-- unique enums (the value NEVER changes, but i can change the left name if i want to)
-- TODO REDOOO THISSSS
enums.item = "efd9f225-9a16-4a6b-97ac-1fc871974272" -- item type enum
enums.category = "f1405b4b-367f-4c21-9bef-44c513afa9e1" -- category type enum
enums.tab = "893a9824-8c91-4bae-9294-0e67eff014df" -- tab type enum

enums.menus = {
  addcat = "930551e6-7dd0-4f00-90a3-fe47cb5898bc", -- addcat menu
  frameopt = "57eba537-cb14-4795-8254-d464ad516809", -- frameopt menu
  tabact = "85ba8efb-570c-4e94-b27c-864fc86ebdc7", -- tabactions menu
}

enums.databrokerModes = {
  simple = "03ddaa75-dde4-410b-9eb0-190e1dc3608d", -- simple databroker mode
  advanced = "1daf3e99-4ae2-4f58-b36e-2e8d74b36614", -- advanced databroker mode
  frame = "7e7bb22a-9278-4563-8225-12352eb7d528", -- frame databroker mode
}

-- pure data (see those as global variables accessible by any file, but not global)

enums.idtype = "string"
enums.tdlFrameDefaultWidth = 340
enums.tdlFrameDefaultHeight = 400

enums.ofsxContent = 12
enums.ofsyCatContent = 26
enums.ofsyCat = 26
enums.ofsyContentCat = 28
enums.ofsyContent = 24
