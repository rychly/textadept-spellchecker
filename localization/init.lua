----------------
-- Localization
----------------
-- To make your own localization copy body of function set_default
-- to new file with ".lua" extension and name of your locale in "localization" folder
-- then you can edit fields in new file. For example see ru_RU.lua in "localization" folder

local sep = "/"
if WIN32 then
  sep = "\\"
end

local function localization_exist(lang)
  local search_path = _USERHOME..sep.."modules"..sep.."textadept-spellchecker"..
    sep.."localization"..sep
  local handle = io.open(search_path..lang..".lua")
  if handle then
    handle:close()
    return true
  end
  return false
end

local localization = os.setlocale(nil, "ctype"):match("([^%.]+)%.?.*")
if localization_exist(localization) then
  require("textadept-spellchecker.localization."..localization)
else
  require("textadept-spellchecker.localization.en_US")
end
