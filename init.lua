
-- Possible spellchecker program names
local SPELL_CHECKERS = {"aspell", "hunspell", "hunspell.exe", "aspell.exe"}
-- Event for spellchecking data receiving
local SC_WORD_NOTFOUND = "SC_wordnotfound"
local SC_WORD_SUGGEST = "SC_wordsuggest"
-- Available checkers in current system (will be filled after module load)
local AVAILABLE_CHECKERS = {}
-- Current selected spellchecker
local SPELL_CHECKER = ""
-- Handles for checker process
local spellchecker_process = false
local current_dicts = false

--------------------------------------------------
-- Some timer api nessesary for live spellchecking
--------------------------------------------------
local function create_timer(on_expire, timeout)
  -- Creates new timer object with given timeout and calling 'on_expire' when expires
  return {
    exec = on_expire,
    time = timeout,
    last_cycle = false,
    running = false
  }
end

local function start(timer)
  -- Starts timer.
  -- If timer already started - gives additional timeout equivalent to original.
  -- Full duration of additional timeouts and original wont be longer whan two original timeouts.
  timer.last_cycle = false
  if not timer.running then
    timer.running = true
    timeout(timer.time, function(t) 
      if t.last_cycle then
        t.on_expire()
        t.running = false
        t.last_cycle = false
        return false
      end
      t.last_cycle = true
      return true
    end, timer)
  end
end

------------------------
-- Backend data parsing
------------------------
local function parse(checker_answer)
  -- Performs initial parsing of backend data and emits corresponding events
  local mode, word, tail = checker_answer:match("([&#])%s+(%S+)(.*)")
  if mode then
    if mode == "&" then
      local suggestions = tail:match(":(.+)")
      events.emit(SC_WORD_SUGGEST, word, suggestions)
    elseif mode == "#" then
      events.emit(SC_WORD_NOTFOUND, word)
    end
  end
end

----------------------
-- Backend management
----------------------
local function get_checker(dicts)
  -- Runs checker backend or return existent one
  local dict_switch  = ""
  if dicts and dicts:len() > 0 then
    dict_switch = "-d "..dicts
  end
  if not spellchecker_process or spellchecker_process:status()  ~= "running" or current_dicts ~= dicts then
    if current_dicts ~= dicts and spellchecker_process then
      spellchecker_process:kill()
    end
    ui.print("Starting checker")
    spellchecker_process = spawn(SPELL_CHECKER.." -m -a "..dict_switch, nil, parse, parse_err, parse_exit)
    if spellchecker_process:status()  ~= "running" then
      error("Can not start spellchecker "..SPELL_CHECKER)
      shutdown()
      return nil
    end
    -- Entering terse mode to improove performance
    spellchecker_process:write("!\n")
  end
  current_dicts = dicts
  return spellchecker_process
end

local function kill_checker()
  -- Stops spellchecker backend
  if spellchecker_process and spellchecker_process:status()  == "running" then
    spellchecker_process:kill()
  end
end

------------------------
-- Document highlighting
------------------------
local function highlight(word, style)
  -- Highlights all occurences of given word in buffer with given style
  if word == nil or word:len() < 2 then
    return
  end
  local word_len = word:len()
  local text = buffer:text_range(0, buffer.length)
  local pos = 1
  local last = 1
  while pos do
    pos = text:find("[%p%s]"..word.."[%p%s]", last)
    if pos then
      last = pos + word_len
      buffer.indicator_current = style
      buffer:indicator_fill_range( pos, word_len )
    end
  end
end


--------------------
-- Check initiators
--------------------
local function check_text(text)
  -- Performs spelling check for supplied visible text
  local checker = get_checker()
  local uniq_words = {}
  for word in text:gmatch("[^%s%p][^%s%p]+")
  do
    if not uniq_words[word] and word:len() > 1 then
      uniq_words[word] = true
    end
  end
  events.connect(SC_WORD_NOTFOUND, function(w) highlight(w, 3) end)
  events.connect(SC_WORD_SUGGEST, function(w, s) highlight(w, 1) end)
  for word,_ in pairs(uniq_words)
  do
    checker:write(word.."\n")
  end
end

local function check_frame()
  -- Performs spelling check for visible text
  local lastline = buffer.first_visible_line + buffer.lines_on_screen
  local start = buffer:position_from_line(buffer.first_visible_line-1)
  local finish = buffer:position_from_line(lastline+1)
  if start == -1 then start = 0 end
  if finish == -1 then finish = buffer.length end
  buffer:indicator_clear_range(start, finish)
  check_text(buffer:text_range(start, finish))
end

local function check_file()
  -- Checking whole file in background
  buffer:indicator_clear_range(0, buffer.length)
  check_text(buffer:text_range(0, buffer.length))
end



-------------------------------
-- Module load/unload routines
-------------------------------
local function shutdown()
  events.disconnect(events.FILE_AFTER_SAVE, check_file)
  events.disconnect(events.RESET_BEFORE, shutdown)
  kill_checker()
  buffer:indicator_clear_range(0, buffer.length)
end
local function connect_events()
  events.connect(events.FILE_AFTER_SAVE, check_file)
  events.connect(events.QUIT, shutdown)
  events.connect(events.RESET_BEFORE, shutdown)
end

-- Check which spellcheckers present in the system
for i, v in ipairs(SPELL_CHECKERS) do
  local status = os.execute(v.." --help")
  if status then
    ui.print("Added checker "..tostring(v))
    table.insert(AVAILABLE_CHECKERS, v)
  else
    ui.print("Checker "..v.." not added due to error "..tostring(status))
  end
end

-- Set default checker and register events when checker available
if AVAILABLE_CHECKERS and AVAILABLE_CHECKERS[1] then
  ui.print("Event registred!")
  SPELL_CHECKER = AVAILABLE_CHECKERS[1]
  connect_events()
end
