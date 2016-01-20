local backend = require("textadept-spellchecker.backend")
local suggestions = require("textadept-spellchecker.suggestions")
local check = require("textadept-spellchecker.check")
local gui = require("textadept-spellchecker.gui")
local live = require("textadept-spellchecker.livechecking")



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
  if suggestions then
    suggestions.init()
  end
  if gui then
    gui.init()
  end
  if live then
    live.init()
  end
end

events.connect(events.INITIALIZED, init)

