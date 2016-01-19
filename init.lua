local timer = require("textadept-spellchecker.timer")
local suggestions = require("textadept-spellchecker.suggestions")
local check = require("textadept-spellchecker.check")
local gui = require("textadept-spellchecker.gui")

-------------------------------
-- Live checking routines
-------------------------------
local function on_expire()
  check.frame()
end

local livecheck_timer = timer.create_timer(on_expire, 2)

local function hasbit(x, bit)
  return x % (bit + bit) >= bit
end

local function on_activity(updated)
  if updated and hasbit(updated, buffer.UPDATE_V_SCROLL) then
    timer.start(livecheck_timer)
  end
end

local function on_keypress()
  timer.start(livecheck_timer)
end

-------------------------------
-- Module load/unload routines
-------------------------------
local function shutdown()
  events.disconnect(events.RESET_BEFORE, shutdown)
  events.disconnect(events.UPDATE_UI, on_activity)
  events.disconnect(events.KEYPRESS, on_keypress)
  events.disconnect(events.INITIALIZED, connect_events)
end
local function init()
  events.connect(events.QUIT, shutdown)
  events.connect(events.RESET_BEFORE, shutdown)
  events.connect(events.UPDATE_UI, on_activity)
  events.connect(events.KEYPRESS, on_keypress)
  if suggestions then
    suggestions.init()
  end
  if gui then
    gui.init()
  end
  on_keypress() -- Start spellchecking after loading
end

if check then
  events.connect(events.INITIALIZED, init)
end
