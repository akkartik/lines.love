curses = require 'curses'

local stdscr = curses.initscr()
curses.echo(false) -- unclear why implicit echo can't handle newlines, regardless of stdscr:nl()
stdscr:clear()
stdscr:scrollok(true)

local function gather_results(success, ...)
  local n = select('#', ...)
  return success, { n = n, ... }
end

local function readline()
  local result = ''
  while true do
    local x = stdscr:getch()
    stdscr:addch(x)
    local c = string.char(x)
    result = result .. c
    if c == '\n' then break end
  end
  return result
end

local new_expr = true
local buf = ''
while true do
  if new_expr then
    stdscr:addstr('> ')
  else
    stdscr:addstr('>> ')
  end
  buf = buf .. readline()
  local f, err = load('return '..buf, 'REPL')
  if f then
    buf = ''
    new_expr = true
    local success, results = gather_results(xpcall(f, function(...) return debug.traceback() end))
    if success then
      for i, result in ipairs(results) do
        if i > 1 then
          stdscr:addch('\t')
        end
        stdscr:addstr(tostring(result))
      end
    else
      stdscr:addstr(tostring(result[1]))
    end
    stdscr:addch('\n')
  else
    local f, err = load(buf, 'REPL')
    if f then
      buf = ''
      new_expr = true
      local success, results = gather_results(xpcall(f, function(...) return debug.traceback() end))
      if success then
        for _, result in ipairs(results) do
          if i > 1 then
            stdscr:addch('\t')
          end
          stdscr:addstr(tostring(result))
        end
      else
        stdscr:addstr(tostring(result[1]))
      end
      stdscr:addch('\n')
    else
      stdscr:addstr(err..'\n')
      if string.match(err, "'<eof>'$") or string.match(err, "<eof>$") then
        buf = buf .. '\n'
        new_expr = false
      else
        print(err)
        buf = ''
        new_expr = true
      end
    end
  end
end

curses.endwin()
