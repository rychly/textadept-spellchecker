local check = require("textadept-spellchecker.check")
local timer = require("textadept-spellchecker.timer")

-------------------------------
-- Live checking routines
-------------------------------
local _M = {}

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

function _M.shutdown()
  events.disconnect(events.RESET_BEFORE, _M.shutdown)
  events.disconnect(events.UPDATE_UI, on_activity)
  events.disconnect(events.KEYPRESS, on_keypress)
end

function _M.init()
  events.connect(events.QUIT, _M.shutdown)
  -- TODO: Investigate why shutdown causes calling nil value
  -- events.connect(events.RESET_BEFORE, shutdown)
  events.connect(events.UPDATE_UI, on_activity)
  events.connect(events.KEYPRESS, on_keypress)
  on_keypress() -- Start spellchecking after loading
end

return _M
