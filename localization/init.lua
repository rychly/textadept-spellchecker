
local function set_default()
  -- GUI
  -- Labels
  _L["PROBLEM"] = "Problem"
  _L["ENTER_SC_BACKEND"] = "Enter backend command"
  _L["ENTER_SC_BACKEND_INFO"] = "Enter the command to call of ispell-compatible backend."..
    "Be careful! The command will be executed on your computer!"
  _L["SELECT_BACKEND"] = "Select backend"
  _L["SELECT_BACKEND_INFO"] = "Select backend to be used for spellchecking:"
  _L["ENTER_DICT"] = "Enter the dictionary name"
  _L["ENTER_DICT_INFO"] = "Enter the dictionary name."..
    "How to obtain list of available dictionaries see in documentation for selected backend"
  
  -- Messages
  _L["NOT_DICT"] = "%s is not a correct dictionary for backend %s"
  _L["NOT_BACKEND"] = "%s is not Ispell-compatible backend or can not be executed."
  
  -- Menu and buttons
  _L["S_PELLCHECK"] = "S_pell check"
  _L["_SCON"] = "Enable _spellchecking"
  _L["_SCOFF"] = "Disable _spellchecking"
  _L["_BACKENDSELECT"] = "_Backend selection"
  _L["_DICTSELECT"] = "_Dictionary selection"
  _L["_NOTINLIST"] = "_Not in the list"

    
  -- Suggestions
  _L["DICT_ADD"] = "Add to a personal dictionary"
  _L["IGNORE"] = "Ignore"
end

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
  set_default()
end