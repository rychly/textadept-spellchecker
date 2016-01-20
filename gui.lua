--------------------
-- GUI modification
--------------------

local _M = {}
local backend = require("textadept-spellchecker.backend")
local check = require("textadept-spellchecker.check")
local live = require("textadept-spellchecker.livechecking")

------------------------
-- On/Off spellchecking
------------------------
local on_off_msgs = {
  _L["Enable _spellchecking"],
  _L["Disable _spellchecking"],
}


local function toggle_spellchecking(check_state)
  if check_state == 2 then
    check_state = 1
    check.shutdown()
    live.shutdown()
  else
    check_state = 2
    check.connect_events()
    live.init()
  end
  -- Changing messages and status in menu
  textadept.menu.menubar[#textadept.menu.menubar-1][1][1] = on_off_msgs[check_state]
  textadept.menu.menubar[#textadept.menu.menubar-1][1][2][2] = check_state
end

---------------------
-- Backend selection
---------------------
local function new_backend()
  local input_box = {
    title = _L["Enter backend command"],
    informative_text = _L["Enter the command to call of ispell-compatible backend."..
    "Be careful! It will be executed on your computer!"],
    button2 = _L["_Cancel"],
    float = true,
  }
  local status, command = ui.dialogs.inputbox(input_box)
  if status == 1 then
    if backend.check_backend(command) then
      table.insert(backend.AVAILABLE_CHECKERS, command)
      return command
    else
      ui.dialogs.ok_msgbox({
        title = _L["Problem"],
        text = command.._L[" is not Ispell-compatible backend or can not be executed"],
        no_cancel = true
      })
    end
  end
  return nil
end

local function backend_selector()
  local backend_select_dialog = {
    title = _L["Select backend"],
    text = _L["Select backend to be used for spellchecking:"],
    float = true,
    button2 = _L["_Cancel"],
    button3 = _L["_Not in the list"],
    items = backend.AVAILABLE_CHECKERS,
    select = backend.CURRENT_CHECKER
  }
  local status = 0
  local status, checker = ui.dialogs.dropdown(backend_select_dialog)
  if status == 2 then
    checker = nil
  elseif status == 3 then
    checker = new_backend()
  end
  if checker and checker ~= backend.CURRENT_CHECKER then
    backend.CURRENT_CHECKER = checker or backend.CURRENT_CHECKER
    backend.kill_checker()
    check.frame()
  end
end

------------------------
-- Dictionary selection
------------------------
local function dictionary_selector()
  local input_box = {
    title = _L["Enter dictionary name"],
    informative_text = _L["Enter the dictionary name."..
    "How to obtain list of available dictionaries see in documentation for selected backend"],
    button2 = _L["_Cancel"],
    float = true,
  }
  local status, dict = ui.dialogs.inputbox(input_box)
  if status == 1 then
    local status = backend.check_dict(dict)
    if status == true then
      backend.dicts = dict
      backend.kill_checker()
      check.frame()
    else
      ui.dialogs.ok_msgbox({
        title = _L["Problem"],
        text = dict.._L[" is not a correct dictionary for backend "]..backend.AVAILABLE_CHECKERS[backend.CURRENT_CHECKER],
        no_cancel = true
      })
    end
  end
end

-------------
-- Root menu
-------------
local spellcheck_menu = {
  title = _L["S_pell check"],
  {
    on_off_msgs[2],
    {
      toggle_spellchecking,
      2 -- on by default until config files not implemented
    }
  },
  {""},
  {
    _L["_Backend selection"],
    backend_selector
  },
  {
    _L["_Dictionary selection"],
    dictionary_selector
  },
}

function _M.init()
  table.insert(textadept.menu.menubar, #textadept.menu.menubar, spellcheck_menu)
end

return _M