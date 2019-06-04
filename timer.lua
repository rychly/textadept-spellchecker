--------------------------------------------------
-- Some timer nessesary for live spellchecking
--------------------------------------------------
local _M = {}

function _M.create_timer(on_expire, timeout)
  -- Creates new timer object with given timeout and calling 'on_expire' when expires
  return {
    trigger = on_expire,
    time = timeout,
    last_cycle = false,
    running = false
  }
end

function _M.start(timer)
  -- Starts timer.
  -- If timer already started - gives additional timeout equivalent to original.
  -- Full duration of additional timeouts and original wont be longer whan two original timeouts.
  timer.last_cycle = false
  if not timer.running then
    timer.running = true
    timeout(timer.time, function(t)
      if t.last_cycle then
        t.trigger()
        t.running = false
        t.last_cycle = false
        return false
      end
      t.last_cycle = true
      return true
    end, timer)
  end
end

return _M
