----------------------
-- Backend management
----------------------
local _M = {}

-- Possible spellchecker program names
local SPELL_CHECKERS = {
  "aspell",
  "hunspell",
  "ispell",
  "hunspell.exe",
  "aspell.exe",
  "ispell.exe"
}

-- Event for spellchecking data receiving
_M.ANSWER = "SC_wordsuggest"

-- Available checkers in current system (will be filled after module load)
_M.AVAILABLE_CHECKERS = {}
-- Current selected spellchecker
_M.CURRENT_CHECKER = 1

-- Handles for checker process
_M.spellchecker_process = false
_M.current_dicts = false

local function parse(checker_answer)
  -- Performs initial parsing of backend data and emits corresponding events
  for line in checker_answer:gmatch("([^\r\n]*)\r?\n")
  do
    local mode, word, tail = line:match("([&#])%s+(%S+)(.*)")
    if mode and mode:match("[#&]") then
      local suggestions = tail:match(":%s?(.+)")
      events.emit(_M.ANSWER, word, suggestions)
    end
  end
end

function _M.get_checker(dicts)
  -- Runs checker backend or return existent one
  local dict_switch  = ""
  if dicts and dicts:len() > 0 then
    dict_switch = "-d "..dicts
  end
  if not _M.spellchecker_process or _M.spellchecker_process:status()  ~= "running" or _M.current_dicts ~= dicts then
    if _M.current_dicts ~= dicts and _M.spellchecker_process then
      _M.spellchecker_process:kill()
    end
    _M.spellchecker_process = spawn(_M.AVAILABLE_CHECKERS[_M.CURRENT_CHECKER].." -m -a "..dict_switch, nil, parse)
    if _M.spellchecker_process:status()  ~= "running" then
      error("Can not start spellchecker ".._M.AVAILABLE_CHECKERS[_M.CURRENT_CHECKER])
    end
    -- Entering terse mode to improove performance
    _M.spellchecker_process:write("!\n")
  end
  _M.current_dicts = dicts
  return _M.spellchecker_process
end

function _M.kill_checker()
  -- Stops spellchecker backend
  if _M.spellchecker_process and _M.spellchecker_process:status()  == "running" then
    _M.spellchecker_process:kill()
  end
end


-- Check which spellcheckers present in the system
for i, v in ipairs(SPELL_CHECKERS) do
  local status = io.popen(v.." -vv")
  if status then
    local result = status:read()
    if result and result:match("Ispell") then
      table.insert(_M.AVAILABLE_CHECKERS, v)
    end
  end
end

-- Set default checker and register events when checker available
if _M.AVAILABLE_CHECKERS and _M.AVAILABLE_CHECKERS[1] then
  _M.CURRENT_CHECKER = 1 -- By default we pick first checker
  return _M -- Backend ready to work
end


return false