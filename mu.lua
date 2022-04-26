curses = require 'curses'

local stdscr = curses.initscr()
stdscr:clear()
stdscr:getch()
curses.endwin()
