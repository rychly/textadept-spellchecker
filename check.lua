--------------------
-- Check initiators
--------------------
local _M = {}
local backend = require("textadept-spellchecker.backend")

-----------------------
-- Highlighting styles
-----------------------
local indicator_number_error = 3
local indicator_number_suggestion = 1
buffer.indic_style[indicator_number_error] = buffer.INDIC_GRADIENT
buffer.indic_style[indicator_number_suggestion] = buffer.INDIC_GRADIENT

------------------------
-- Document highlighting
------------------------
local function highlight(word, suggestions)
  -- Highlights all occurences of given word in buffer with given style
  if word == nil or word:len() < 2 then
    return
  end
  local style = indicator_number_error
  if suggestions then style = indicator_number_suggestion end
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
  for word,_ in pairs(uniq_words)
  do
    checker:write(word.."\n")
  end
end

function _M.frame()
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
  _M.clear(buffer)
  check_text(buffer:text_range(start, finish))
end

function _M.file()
  -- Checking whole file in background
  _M.clear(buffer)
  check_text(buffer:text_range(0, buffer.length))
end

function _M.clear(buffer)
  buffer.indicator_current = indicator_number_suggestion
  buffer:indicator_clear_range(0, buffer.length)
  buffer.indicator_current = indicator_number_error
  buffer:indicator_clear_range(0, buffer.length)
end

function _M.clear_all()
  for i, b in ipairs(_BUFFERS)
  do
    _M.clear(b)
  end
end

function _M.shutdown()
  if CURSES then
    events.disconnect(events.FILE_AFTER_SAVE, _M.file)
  end
  events.disconnect(backend.ANSWER, highlight)
  events.disconnect(events.RESET_BEFORE, shutdown)
  events.disconnect(events.INITIALIZED, connect_events)
  backend.kill_checker()
  _M.clear_all()
end

function _M.connect_events()
  if CURSES then -- livechecking not implemented for CURSES so its better to use filechecking
    events.connect(events.FILE_AFTER_SAVE, _M.file)
  end
  events.connect(backend.ANSWER, highlight)
  events.connect(events.QUIT, _M.shutdown)
  events.connect(events.RESET_BEFORE, _M.shutdown)
end

if backend then
  events.connect(events.INITIALIZED, _M.connect_events)
  return _M
end
