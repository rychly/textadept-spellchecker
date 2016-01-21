--------------------
-- GUI modification
--------------------

local _M = {}
local backend = require("textadept-spellchecker.backend")
local check = require("textadept-spellchecker.check")
local live = require("textadept-spellchecker.livechecking")
local config = require("textadept-spellchecker.config")

------------------------
-- On/Off spellchecking
------------------------
local on_off_msgs = {
  _L["_SCON"],
  _L["_SCOFF"],
}

local function renew()
  backend.kill_checker()
  check.frame()
  config:save()
end

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
  config.checking = check_state
  config:save()
end

---------------------
-- Backend selection
---------------------
local function new_backend()
  local input_box = {
    title = _L["ENTER_SC_BACKEND"],
    informative_text = _L["ENTER_SC_BACKEND_INFO"],
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
        title = _L["PROBLEM"],
        text = string.format(_L["NOT_BACKEND"], command),
        no_cancel = true
      })
    end
  end
  return nil
end

local function backend_selector()
  local backend_select_dialog = {
    title = _L["SELECT_BACKEND"],
    text = _L["SELECT_BACKEND_INFO"],
    float = true,
    button2 = _L["_Cancel"],
    button3 = _L["_NOTINLIST"],
    items = backend.AVAILABLE_CHECKERS,
    select = config.CURRENT_CHECKER
  }
  local status = 0
  local status, checker = ui.dialogs.dropdown(backend_select_dialog)
  if status == 2 then
    checker = nil
  elseif status == 3 then
    checker = new_backend()
  end
  if checker and checker ~= config.CURRENT_CHECKER then
    config.CURRENT_CHECKER = checker or config.CURRENT_CHECKER
    renew()
  end
end

------------------------
-- Dictionary selection
------------------------
local function dictionary_selector()
  local input_box = {
    title = _L["ENTER_DICT"],
    informative_text = _L["ENTER_DICT_INFO"],
    button2 = _L["_Cancel"],
    float = true,
    text = config.dicts,
  }
  local status, dict = ui.dialogs.inputbox(input_box)
  if status == 1 then
    local status = backend.check_dict(dict)
    if status == true then
      config.dicts = dict
      renew()
    else
      ui.dialogs.ok_msgbox({
        title = _L["PROBLEM"],
        text = string.format(_L["NOT_DICT"], dict, backend.AVAILABLE_CHECKERS[config.CURRENT_CHECKER]),
        no_cancel = true
      })
    end
  end
end

-------------
-- Root menu
-------------


function _M.init()
  local spellcheck_menu = {
    title = _L["S_PELLCHECK"],
    {
      on_off_msgs[config.checking or 1],
      {
        toggle_spellchecking,
        config.checking or 1 
      }
    },
    {""},
    {
      _L["_BACKENDSELECT"],
      backend_selector
    },
    {
      _L["_DICTSELECT"],
      dictionary_selector
    },
  }
  table.insert(textadept.menu.menubar, #textadept.menu.menubar, spellcheck_menu)
end

return _M