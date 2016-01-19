
-- Possible spellchecker program names
local SPELL_CHECKERS = {"aspell", "hunspell", "hunspell.exe", "aspell.exe"}
-- Event for spellchecking data receiving
local SC_WORD_ANSWER = "SC_wordsuggest"
local SUGGESTION_LIST = 4242 -- List id
-- Available checkers in current system (will be filled after module load)
local AVAILABLE_CHECKERS = {}
-- Current selected spellchecker
local SPELL_CHECKER = ""
-- Handles for checker process
local spellchecker_process = false
local current_dicts = false

--------------------------------------------------
-- Some timer nessesary for live spellchecking
--------------------------------------------------
local function create_timer(on_expire, timeout)
  -- Creates new timer object with given timeout and calling 'on_expire' when expires
  return {
    trigger = on_expire,
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

------------------------
-- Backend data parsing
------------------------
local function parse(checker_answer)
  -- Performs initial parsing of backend data and emits corresponding events
  for line in checker_answer:gmatch("([^\r\n]*)\r?\n")
  do
    local mode, word, tail = line:match("([&#])%s+(%S+)(.*)")
    if mode and mode:match("[#&]") then
      local suggestions = tail:match(":%s?(.+)")
      events.emit(SC_WORD_ANSWER, word, suggestions)
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
local function highlight(word, suggestions)
  -- Highlights all occurences of given word in buffer with given style
  if word == nil or word:len() < 2 then
    return
  end
  local style = 3
  if suggestions then style = 1 end
  local word_len = word:len()
  local text = buffer:text_range(0, buffer.length)
  local pos = 1
  local last = 1
  while pos do
    pos = text:find("[%s%p]"..word.."[%s%p]", last)
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
  -- for word in text:gmatch("[^%s%p][^%s%p]+")
  for word in text:gmatch("[^%s%p][^%s%p]+")
  do
    if not uniq_words[word] and word:len() > 1 then
      uniq_words[word] = true
    end
  end
  -- Not sure how events work in textadept.
  -- Reconnect events just in case
  events.disconnect(SC_WORD_ANSWER, highlight)
  events.connect(SC_WORD_ANSWER, highlight)
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
  start = buffer:word_start_position(start, false)
  finish = buffer:word_end_position(finish, false)
  buffer:indicator_clear_range(start, finish)
  check_text(buffer:text_range(start, finish))
end

local function check_file()
  -- Checking whole file in background
  buffer:indicator_clear_range(0, buffer.length)
  check_text(buffer:text_range(0, buffer.length))
end

---------------------------
-- Indicator click handler
---------------------------

-- autocomplete handler will be placed here to avoid presence of
-- many anonimous handlers in event table
local current_autocomplete_handler = false

-- Word begining and lenght for correct substitution of suggestion
local g_word_start = 0
local g_word_length = 0

-- only this autocomplete handler presents in event table
local function on_answer(word, suggestion)
  -- Handles autocompletion answer if it is nessesary
  -- then removes handler
  if current_autocomplete_handler and suggestion then
    current_autocomplete_handler(word, suggestion)
  end
  current_autocomplete_handler = false
end

local function on_suggestion_click(list_id, selection, pos)
  -- Handles click on item in suggestion list and replaces mistake
  if list_id == SUGGESTION_LIST then
    if selection ~= _L["Add to personal dictionary"] then
      buffer:delete_range(g_word_start, g_word_length)
      buffer:insert_text(buffer.current_pos, selection)
    else
      -- TODO: addition to the dictionary
      ui.print("Spellchecker: Dictionary addition not implemented yet")
    end
  end
end

local function on_indicator_click(pos, mod)
  -- Handles click on indicator and shows suggestion menu
  if mod ~= 0 then return end -- no modificators should be pressed
  local word_start = buffer:word_start_position(pos, true)
  local word_end = buffer:word_end_position(pos, true)
  g_word_start = word_start
  local word = buffer:text_range(word_start, word_end)
  -- not sure how events in textadept work
  -- reconnection just in case
  events.disconnect(SC_WORD_ANSWER, on_answer)
  events.disconnect(SC_WORD_ANSWER, highlight)
  events.connect(SC_WORD_ANSWER, on_answer)
  current_autocomplete_handler = function(origin_word, suggestions)
    g_word_length = origin_word:len()
    local old_separator = buffer.auto_c_separator
    buffer.auto_c_separator = string.byte(",")
    buffer:user_list_show(SUGGESTION_LIST,
      suggestions:gsub(", ",",")..",".._L["Add to personal dictionary"]
    )
    buffer.auto_c_separator = old_separator
  end
  local checker = get_checker()
  checker:write(word.."\n")
end

-------------------------------
-- Live checking routines
-------------------------------
local function on_expire()
  -- ui.print("Fake checking...")
  check_frame()
end

local livecheck_timer = create_timer(on_expire, 2)

local function hasbit(x, bit)
  return x % (bit + bit) >= bit
end

local function on_activity(updated)
  if updated and hasbit(updated, buffer.UPDATE_V_SCROLL) then
    start(livecheck_timer)
  end
end

local function on_keypress()
  start(livecheck_timer)
end

-------------------------------
-- Module load/unload routines
-------------------------------
local function shutdown()
  events.disconnect(events.FILE_AFTER_SAVE, check_file)
  events.disconnect(events.RESET_BEFORE, shutdown)
  events.disconnect(events.INDICATOR_CLICK, on_indicator_click)
  events.disconnect(SC_WORD_ANSWER, on_answer)
  events.disconnect(events.USER_LIST_SELECTION, on_suggestion_click)
  events.disconnect(events.UPDATE_UI, on_activity)
  events.disconnect(events.KEYPRESS, on_keypress)
  kill_checker()
  buffer:indicator_clear_range(0, buffer.length)
end
local function connect_events()
  events.connect(events.FILE_AFTER_SAVE, check_file)
  events.connect(events.QUIT, shutdown)
  events.connect(events.RESET_BEFORE, shutdown)
  events.connect(events.INDICATOR_CLICK, on_indicator_click)
  events.connect(SC_WORD_ANSWER, on_answer)
  events.connect(events.USER_LIST_SELECTION, on_suggestion_click)
  events.connect(events.UPDATE_UI, on_activity)
  events.connect(events.KEYPRESS, on_keypress)
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
  --ui.print("Event registred!")
  SPELL_CHECKER = AVAILABLE_CHECKERS[2]
  connect_events()
end
