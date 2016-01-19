local timer = require("textadept-spellchecker.timer")
local backend = require("textadept-spellchecker.backend")
local suggestions = require("textadept-spellchecker.suggestions")

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
  local checker = backend.get_checker()
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
  events.disconnect(backend.ANSWER, highlight)
  events.connect(backend.ANSWER, highlight)
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
  -- occurs when user scrolls buffer during position measurements
  if start >= finish then return end 
  buffer:indicator_clear_range(start, finish)
  check_text(buffer:text_range(start, finish))
end

local function check_file()
  -- Checking whole file in background
  buffer:indicator_clear_range(0, buffer.length)
  check_text(buffer:text_range(0, buffer.length))
end


-------------------------------
-- Live checking routines
-------------------------------
local function on_expire()
  check_frame()
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
  --events.disconnect(events.FILE_AFTER_SAVE, check_file)
  events.disconnect(events.RESET_BEFORE, shutdown)
  events.disconnect(events.UPDATE_UI, on_activity)
  events.disconnect(events.KEYPRESS, on_keypress)
  suggestions.disconnect_events()
  backend.kill_checker()
  buffer:indicator_clear_range(0, buffer.length)
end
local function connect_events()
  --events.connect(events.FILE_AFTER_SAVE, check_file)
  events.connect(events.QUIT, shutdown)
  events.connect(events.RESET_BEFORE, shutdown)
  events.connect(events.UPDATE_UI, on_activity)
  events.connect(events.KEYPRESS, on_keypress)
  suggestions.connect_events()
end

if backend then
  connect_events()
end
