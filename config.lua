------------------------
-- Configuration keeper
------------------------

local _M = {}
local sep = "/"
if WIN32 then
  sep = "\\"
end

local FILENAME = _USERHOME..sep.."spellchecker.conf"

function _M:load()
  local handle = io.open(FILENAME, "r")
  if not handle then return end
  for line in handle:lines()
  do
    key, val = line:match("([^=]+)=(.+)")
    if key then
      self[key] = tonumber(val) or val
    end
  end
  handle:close()
end

function _M:save()
  local handle = io.open(FILENAME, "w")
  if handle then
    for key, val in pairs(self)
    do
      if type(val) == "string" or type(val) == "number" then
        handle:write(tostring(key).."="..tostring(val).."\n")
      end
    end
    handle:close()
  end
end

local function shutdown()
  _M:save()
end

function _M.init()
  _M:load(_USERHOME..sep.."spellchecker.conf")
  events.connect(events.RESET_BEFORE, shutdown)
  events.connect(events.QUIT, shutdown)
end

return _M
