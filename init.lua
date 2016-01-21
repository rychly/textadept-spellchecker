local backend = require("textadept-spellchecker.backend")
local suggestions = require("textadept-spellchecker.suggestions")
local check = require("textadept-spellchecker.check")
local gui = require("textadept-spellchecker.gui")
local live = require("textadept-spellchecker.livechecking")
local config = require("textadept-spellchecker.config")


-------------------------------
-- Module load/unload routines
-------------------------------
local function shutdown()
  events.disconnect(events.RESET_BEFORE, shutdown)
end

local function init()
  events.disconnect(events.INITIALIZED, init)
  if not (backend and check)
  then
    return
  end
  events.connect(events.QUIT, shutdown)
  -- TODO: Investigate why shutdown causes calling nil value
  -- events.connect(events.RESET_BEFORE, shutdown)
  if config then
    config.init()
  end
  if suggestions then
    suggestions.init()
  end
  if gui then
    gui.init()
  end
  if live and not CURSES then
    live.init()
  end
  -- Shutdown checkers when checking is off
  if config.checking ~= 2 then
    check.shutdown()
    live.shutdown()
  end
end

events.connect(events.INITIALIZED, init)

