
-- Possible spellchecker program names
local SPELL_CHECKERS = {"aspell", "hunspell", "hunspell.exe", "aspell.exe"}
-- Available checkers in current system (will be filled after module load)
local AVAILABLE_CHECKERS = {}
-- Current selected spellchecker
local SPELL_CHECKER = ""
-- Handles for checker process
local spellchecker_process = nil
local current_dicts = nil

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

-- Some timer api nessesary for live spellchecking
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


local function highlight(word, style)
  if word == nil or word:len() < 2 then
    return
  end
  local word_len = word:len()
  local text = buffer:text_range(0, buffer.length)
  local pos = 1
  local last = 1
  -- buffer:colourise(0, buffer.length)
  while pos do
    pos = text:find("[%p%s]"..word.."[%p%s]", last)
    if pos then
      last = pos + word_len
      buffer.indicator_current = style
      buffer:indicator_fill_range( pos, word_len )
    end
  end
end

local function parse(checker_answer)
  print(checker_answer)
  local word = checker_answer:match("%&%s+(%S+)") or checker_answer:match("%#%s+(%S+)")
  if word then
    local indicator = 1
    print("Got in stdout: "..word)
    if checker_answer:match("&") then indicator = 1 else indicator = 3 end
    highlight(word, indicator)
  end
end

local function parse_err(checker_answer)
  print("Got in stderr: "..checker_answer)
end
local function parse_exit(checker_answer)
  print("Got exitcode: "..tostring(checker_answer))
end
local function get_checker(dicts)
  -- Runs checker daemon or return existent one
  local dict_switch  = ""
  if dicts and dicts:len() > 0 then
    dict_switch = "-d "..dicts
  end
  if spellchecker_process == nil or spellchecker_process:status()  ~= "running" or current_dicts ~= dicts then
    if current_dicts ~= dicts and spellchecker_process then
      spellchecker_process:kill()
    end
    ui.print("Starting checker")
    spellchecker_process = spawn(SPELL_CHECKER.." -m -a "..dict_switch, nil, parse, parse_err, parse_exit)
    if spellchecker_process:status()  ~= "running" then
      error("Can not start spellchecker "..SPELL_CHECKER)
      disconnect_events()
    end
    spellchecker_process:write("!\n")
    -- print("First line reading")
    -- spellchecker_process:read() -- Read first line
    -- print("First line read")
  end
  current_dicts = dicts
  return spellchecker_process
end

local function kill_checker()
  if spellchecker_process and spellchecker_process:status()  == "running" then
    spellchecker_process:kill()
  end
end

local function check_frame()
  -- Performs spelling check for visible text
  ui.print("Checking frame")
  local lastline = buffer.first_visible_line + buffer.lines_on_screen
  local start = buffer:position_from_line(buffer.first_visible_line-1)
  local finish = buffer:position_from_line(lastline+1)
  if start == -1 then start = 0 end
  if finish == -1 then finish = buffer.length end
  ui.print("start: "..tostring(start).." end: "..tostring(finish))
  local text = buffer:text_range(start, finish)
  local checker = get_checker()
  ui.print("text sent")
  spellchecker_process:write(text)
  ui.print("Got at read: "..spellchecker_process:read())
end

local function check_file(filename, save_as)
  local checker = get_checker()
  local uniq_words = {}
  local incrementor = 0
  buffer:indicator_clear_range(0, buffer.length)
  for word in buffer:text_range(0, buffer.length):gmatch("[^%s%p][^%s%p]+")
  do
    if not uniq_words[word] and word:len() > 1 then
      uniq_words[word] = true
      incrementor = incrementor + 1
    end
  end
  print("Found "..tostring(incrementor).." uniq words")
  for word,_ in pairs(uniq_words)
  do
    checker:write(word.."\n")
  end
end





local function disconnect_events()
  events.disconnect(events.FILE_BEFORE_SAVE, check_file)
  events.disconnect(events.RESET_BEFORE, disconnect_events)
  kill_checker()
  buffer:indicator_clear_range(0, buffer.length)
end
local function connect_events()
  events.connect(events.FILE_BEFORE_SAVE, check_file)
  events.connect(events.QUIT, disconnect_events)
  events.connect(events.RESET_BEFORE, disconnect_events)
end
-- Set default checker and register events when checker available
if AVAILABLE_CHECKERS and AVAILABLE_CHECKERS[1] then
  ui.print("Event registred!")
  SPELL_CHECKER = AVAILABLE_CHECKERS[1]
  connect_events()
end
