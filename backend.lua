----------------------
-- Backend management
----------------------
local _M = {}
local config = require("textadept-spellchecker.config")
-- Possible spellchecker program names
local SPELL_CHECKERS = {
  "aspell",
  "hunspell",
  "ispell"
}
local ispell_cmd = '%s -a'
local ispell_cmd_dict = ispell_cmd .. ' -d "%q"'
local ispell_cmd_dict_no_stdin = ispell_cmd_dict .. ' </dev/null'

-- Event for spellchecking data receiving
_M.ANSWER = "SC_wordsuggest"

-- Available checkers in current system (will be filled after module load)
_M.AVAILABLE_CHECKERS = {}

-- Handles for checker process
_M.spellchecker_process = false

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

function _M.check_dict(dict)
  -- Checking if dictionary is exist
  if not (config.CURRENT_CHECKER and _M.AVAILABLE_CHECKERS[config.CURRENT_CHECKER]) then
    config.CURRENT_CHECKER = 1
  end
  local status = os.execute(string.format(ispell_cmd_dict_no_stdin, _M.AVAILABLE_CHECKERS[config.CURRENT_CHECKER], dict))
  return status
end

function _M.get_checker()
  -- Runs checker backend or return existent one
  if not (config.CURRENT_CHECKER and _M.AVAILABLE_CHECKERS[config.CURRENT_CHECKER]) then
    config.CURRENT_CHECKER = 1
  end
  local ispell_to_spawn
  if type(config.dicts) == "string" and config.dicts:len() > 0 and _M.check_dict(config.dicts) then
    ispell_to_spawn = string.format(ispell_cmd_dict, _M.AVAILABLE_CHECKERS[config.CURRENT_CHECKER], config.dicts)
  else
    ispell_to_spawn = string.format(ispell_cmd, _M.AVAILABLE_CHECKERS[config.CURRENT_CHECKER])
    config.dicts = "" -- Invalid dictionary reset
  end
  if not _M.spellchecker_process or _M.spellchecker_process:status()  ~= "running" then
    _M.spellchecker_process = os.spawn(ispell_to_spawn, parse)
    if _M.spellchecker_process:status()  ~= "running" then
      error("Can not start spellchecker as "..ispell_to_spawn)
    end
    -- Entering terse mode to improove performance
    _M.spellchecker_process:write("!\n")
  end
  return _M.spellchecker_process
end

function _M.kill_checker()
  -- Stops spellchecker backend
  if _M.spellchecker_process and _M.spellchecker_process:status()  == "running" then
    _M.spellchecker_process:kill()
  end
end

function _M.check_backend(backend)
  -- Checking if backend is exist and (perhaps) Ispell-compatible
  local status = io.popen(backend.." -vv")
  if status then
    local result = status:read()
    if result and result:match("Ispell") then
      return true
    end
  end
  return false
end

-- Check which spellcheckers present in the system
for i, v in ipairs(SPELL_CHECKERS) do
  if _M.check_backend(v) then
    table.insert(_M.AVAILABLE_CHECKERS, v)
  end
end

-- Set default checker and register events when checker available
if _M.AVAILABLE_CHECKERS and _M.AVAILABLE_CHECKERS[1] then
  return _M -- Backend ready to work
end

return false
