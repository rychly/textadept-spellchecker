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
local AVAILABLE_CHECKERS = {}
-- Current selected spellchecker
local SPELL_CHECKER = ""

-- Handles for checker process
local spellchecker_process = false
local current_dicts = false

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
  if not spellchecker_process or spellchecker_process:status()  ~= "running" or current_dicts ~= dicts then
    if current_dicts ~= dicts and spellchecker_process then
      spellchecker_process:kill()
    end
    spellchecker_process = spawn(SPELL_CHECKER.." -m -a "..dict_switch, nil, parse)
    if spellchecker_process:status()  ~= "running" then
      error("Can not start spellchecker "..SPELL_CHECKER)
    end
    -- Entering terse mode to improove performance
    spellchecker_process:write("!\n")
  end
  current_dicts = dicts
  return spellchecker_process
end

function _M.kill_checker()
  -- Stops spellchecker backend
  if spellchecker_process and spellchecker_process:status()  == "running" then
    spellchecker_process:kill()
  end
end


-- Check which spellcheckers present in the system
for i, v in ipairs(SPELL_CHECKERS) do
  local status = io.popen(v.." -vv")
  if status then
    local result = status:read()
    if result and result:match("Ispell") then
      table.insert(AVAILABLE_CHECKERS, v)
    end
  end
end

-- Set default checker and register events when checker available
if AVAILABLE_CHECKERS and AVAILABLE_CHECKERS[1] then
  SPELL_CHECKER = AVAILABLE_CHECKERS[1]
  return _M -- Backend ready to work
end

return false