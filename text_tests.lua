-- major tests for text editing flows
-- This still isn't quite as thorough as I'd like.

function test_draw_text()
  io.write('\ntest_draw_text')
  App.screen.init{width=120, height=60}
  Lines = load_array{'abc', 'def', 'ghi'}
  Line_width = App.screen.width
  Cursor1 = {line=1, pos=1}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'abc', 'F - test_draw_text/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_draw_text/screen:2')
  y = y + Line_height
  App.screen.check(y, 'ghi', 'F - test_draw_text/screen:3')
end

function test_draw_wrapping_text()
  io.write('\ntest_draw_wrapping_text')
  App.screen.init{width=50, height=60}
  Lines = load_array{'abc', 'defgh', 'xyz'}
  Line_width = App.screen.width
  Cursor1 = {line=1, pos=1}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'abc', 'F - test_draw_wrapping_text/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_draw_wrapping_text/screen:2')
  y = y + Line_height
  App.screen.check(y, 'gh', 'F - test_draw_wrapping_text/screen:3')
end

function test_draw_word_wrapping_text()
  io.write('\ntest_draw_word_wrapping_text')
  App.screen.init{width=60, height=60}
  Lines = load_array{'abc def ghi', 'jkl'}
  Line_width = App.screen.width
  Cursor1 = {line=1, pos=1}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'abc ', 'F - test_draw_word_wrapping_text/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def ', 'F - test_draw_word_wrapping_text/screen:2')
  y = y + Line_height
  App.screen.check(y, 'ghi', 'F - test_draw_word_wrapping_text/screen:3')
end

function test_draw_text_wrapping_within_word()
  -- arrange a screen line that needs to be split within a word
  io.write('\ntest_draw_text_wrapping_within_word')
  App.screen.init{width=60, height=60}
  Lines = load_array{'abcd e fghijk', 'xyz'}
  Line_width = App.screen.width
  Cursor1 = {line=1, pos=1}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'abcd ', 'F - test_draw_text_wrapping_within_word/screen:1')
  y = y + Line_height
  App.screen.check(y, 'e fghi', 'F - test_draw_text_wrapping_within_word/screen:2')
  y = y + Line_height
  App.screen.check(y, 'jk', 'F - test_draw_text_wrapping_within_word/screen:3')
end

function test_edit_wrapping_text()
  io.write('\ntest_edit_wrapping_text')
  App.screen.init{width=50, height=60}
  Lines = load_array{'abc', 'def', 'xyz'}
  Line_width = App.screen.width
  Cursor1 = {line=2, pos=4}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  App.run_after_textinput('g')
  App.run_after_textinput('h')
  App.run_after_textinput('i')
  App.run_after_textinput('j')
  App.run_after_textinput('k')
  App.run_after_textinput('l')
  local y = Margin_top
  App.screen.check(y, 'abc', 'F - test_edit_wrapping_text/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_edit_wrapping_text/screen:2')
  y = y + Line_height
  App.screen.check(y, 'ghij', 'F - test_edit_wrapping_text/screen:3')
end

function test_insert_newline()
  io.write('\ntest_insert_newline')
  -- display a few lines with cursor on bottom line
  App.screen.init{width=25+30, height=60}
  Lines = load_array{'abc', 'def', 'ghi', 'jkl'}
  Line_width = App.screen.width
  Cursor1 = {line=1, pos=2}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'abc', 'F - test_insert_newline/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_insert_newline/baseline/screen:2')
  y = y + Line_height
  App.screen.check(y, 'ghi', 'F - test_insert_newline/baseline/screen:3')
  -- after hitting the enter key the screen scrolls down
  App.run_after_keychord('return')
  check_eq(Screen_top1.line, 1, 'F - test_insert_newline/screen_top')
  check_eq(Cursor1.line, 2, 'F - test_insert_newline/cursor:line')
  check_eq(Cursor1.pos, 1, 'F - test_insert_newline/cursor:pos')
  y = Margin_top
  App.screen.check(y, 'a', 'F - test_insert_newline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'bc', 'F - test_insert_newline/screen:2')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_insert_newline/screen:3')
end

function test_insert_from_clipboard()
  io.write('\ntest_insert_from_clipboard')
  -- display a few lines with cursor on bottom line
  App.screen.init{width=25+30, height=60}
  Lines = load_array{'abc', 'def', 'ghi', 'jkl'}
  Line_width = App.screen.width
  Cursor1 = {line=1, pos=2}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'abc', 'F - test_insert_from_clipboard/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_insert_from_clipboard/baseline/screen:2')
  y = y + Line_height
  App.screen.check(y, 'ghi', 'F - test_insert_from_clipboard/baseline/screen:3')
  -- after hitting the enter key the screen scrolls down
  App.clipboard = 'xy\nz'
  App.run_after_keychord('C-v')
  check_eq(Screen_top1.line, 1, 'F - test_insert_from_clipboard/screen_top')
  check_eq(Cursor1.line, 2, 'F - test_insert_from_clipboard/cursor:line')
  check_eq(Cursor1.pos, 2, 'F - test_insert_from_clipboard/cursor:pos')
  y = Margin_top
  App.screen.check(y, 'axy', 'F - test_insert_from_clipboard/screen:1')
  y = y + Line_height
  App.screen.check(y, 'zbc', 'F - test_insert_from_clipboard/screen:2')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_insert_from_clipboard/screen:3')
end

function test_move_cursor_using_mouse()
  io.write('\ntest_move_cursor_using_mouse')
  App.screen.init{width=50, height=60}
  Lines = load_array{'abc', 'def', 'xyz'}
  Line_width = App.screen.width
  Cursor1 = {line=1, pos=1}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  Selection1 = {}
  App.draw()  -- populate line.y for each line in Lines
  local screen_left_margin = 25  -- pixels
  App.run_after_mouserelease(screen_left_margin+8,Margin_top+5, '1')
  check_eq(Cursor1.line, 1, 'F - test_move_cursor_using_mouse/cursor:line')
  check_eq(Cursor1.pos, 2, 'F - test_move_cursor_using_mouse/cursor:pos')
  check_nil(Selection1.line, 'F - test_move_cursor_using_mouse/selection:line')
  check_nil(Selection1.pos, 'F - test_move_cursor_using_mouse/selection:pos')
end

function test_select_text_using_mouse()
  io.write('\ntest_select_text_using_mouse')
  App.screen.init{width=50, height=60}
  Lines = load_array{'abc', 'def', 'xyz'}
  Line_width = App.screen.width
  Cursor1 = {line=1, pos=1}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  Selection1 = {}
  App.draw()  -- populate line.y for each line in Lines
  local screen_left_margin = 25  -- pixels
  -- click on first location
  App.run_after_mousepress(screen_left_margin+8,Margin_top+5, '1')
  App.run_after_mouserelease(screen_left_margin+8,Margin_top+5, '1')
  -- hold down shift and click somewhere else
  App.keypress('lshift')
  App.run_after_mousepress(screen_left_margin+20,Margin_top+5, '1')
  App.run_after_mouserelease(screen_left_margin+20,Margin_top+Line_height+5, '1')
  App.keyrelease('lshift')
  check_eq(Cursor1.line, 2, 'F - test_select_text_using_mouse/cursor:line')
  check_eq(Cursor1.pos, 4, 'F - test_select_text_using_mouse/cursor:pos')
  check_eq(Selection1.line, 1, 'F - test_select_text_using_mouse/selection:line')
  check_eq(Selection1.pos, 2, 'F - test_select_text_using_mouse/selection:pos')
end

function test_pagedown()
  io.write('\ntest_pagedown')
  App.screen.init{width=120, height=45}
  Lines = load_array{'abc', 'def', 'ghi'}
  Line_width = App.screen.width
  Cursor1 = {line=1, pos=1}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  -- initially the first two lines are displayed
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'abc', 'F - test_pagedown/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_pagedown/baseline/screen:2')
  -- after pagedown the bottom line becomes the top
  App.run_after_keychord('pagedown')
  check_eq(Screen_top1.line, 2, 'F - test_pagedown/screen_top')
  check_eq(Cursor1.line, 2, 'F - test_pagedown/cursor')
  y = Margin_top
  App.screen.check(y, 'def', 'F - test_pagedown/screen:1')
  y = y + Line_height
  App.screen.check(y, 'ghi', 'F - test_pagedown/screen:2')
end

function test_pagedown_skips_drawings()
  io.write('\ntest_pagedown_skips_drawings')
  -- some lines of text with a drawing intermixed
  App.screen.init{width=50, height=80}
  Lines = load_array{'abc',               -- height 15
                     '```lines', '```',   -- height 25
                     'def',               -- height 15
                     'ghi'}               -- height 15
  check_eq(Lines[2].mode, 'drawing', 'F - test_pagedown_skips_drawings/baseline/lines')
  Line_width = App.screen.width
  Cursor1 = {line=1, pos=1}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  local drawing_height = 20 + App.screen.width / 2  -- default
  -- initially the screen displays the first line and the drawing
  -- 15px margin + 15px line1 + 10px margin + 25px drawing + 10px margin = 75px < screen height 80px
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'abc', 'F - test_pagedown_skips_drawings/baseline/screen:1')
  -- after pagedown the screen draws the drawing up top
  -- 15px margin + 10px margin + 25px drawing + 10px margin + 15px line3 = 75px < screen height 80px
  App.run_after_keychord('pagedown')
  check_eq(Screen_top1.line, 2, 'F - test_pagedown_skips_drawings/screen_top')
  check_eq(Cursor1.line, 3, 'F - test_pagedown_skips_drawings/cursor')
  y = Margin_top + drawing_height
  App.screen.check(y, 'def', 'F - test_pagedown_skips_drawings/screen:1')
end

function test_pagedown_shows_one_screen_line_in_common()
  io.write('\ntest_pagedown_shows_one_screen_line_in_common')
  -- some lines of text with a drawing intermixed
  App.screen.init{width=50, height=60}
  Lines = load_array{'abc', 'def ghi jkl', 'mno'}
  Line_width = App.screen.width
  Cursor1 = {line=1, pos=1}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'abc', 'F - test_pagedown_shows_one_screen_line_in_common/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def ', 'F - test_pagedown_shows_one_screen_line_in_common/baseline/screen:2')
  y = y + Line_height
  App.screen.check(y, 'ghi ', 'F - test_pagedown_shows_one_screen_line_in_common/baseline/screen:3')
  -- after pagedown the bottom screen line becomes the top
  App.run_after_keychord('pagedown')
  check_eq(Screen_top1.line, 2, 'F - test_pagedown_shows_one_screen_line_in_common/screen_top:line')
  check_eq(Screen_top1.pos, 5, 'F - test_pagedown_shows_one_screen_line_in_common/screen_top:pos')
  check_eq(Cursor1.line, 2, 'F - test_pagedown_shows_one_screen_line_in_common/cursor:line')
  check_eq(Cursor1.pos, 5, 'F - test_pagedown_shows_one_screen_line_in_common/cursor:pos')
  y = Margin_top
  App.screen.check(y, 'ghi ', 'F - test_pagedown_shows_one_screen_line_in_common/screen:1')
  y = y + Line_height
  App.screen.check(y, 'jkl', 'F - test_pagedown_shows_one_screen_line_in_common/screen:2')
  y = y + Line_height
  App.screen.check(y, 'mn', 'F - test_pagedown_shows_one_screen_line_in_common/screen:3')
end

function test_down_arrow_moves_cursor()
  io.write('\ntest_down_arrow_moves_cursor')
  App.screen.init{width=120, height=60}
  Lines = load_array{'abc', 'def', 'ghi', 'jkl'}
  Line_width = App.screen.width
  Cursor1 = {line=1, pos=1}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  -- initially the first three lines are displayed
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'abc', 'F - test_down_arrow_moves_cursor/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_down_arrow_moves_cursor/baseline/screen:2')
  y = y + Line_height
  App.screen.check(y, 'ghi', 'F - test_down_arrow_moves_cursor/baseline/screen:3')
  -- after hitting the down arrow, the cursor moves down by 1 line
  App.run_after_keychord('down')
  check_eq(Screen_top1.line, 1, 'F - test_down_arrow_moves_cursor/screen_top')
  check_eq(Cursor1.line, 2, 'F - test_down_arrow_moves_cursor/cursor')
  -- the screen is unchanged
  y = Margin_top
  App.screen.check(y, 'abc', 'F - test_down_arrow_moves_cursor/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_down_arrow_moves_cursor/screen:2')
  y = y + Line_height
  App.screen.check(y, 'ghi', 'F - test_down_arrow_moves_cursor/screen:3')
end

function test_down_arrow_scrolls_down_by_one_line()
  io.write('\ntest_down_arrow_scrolls_down_by_one_line')
  -- display the first three lines with the cursor on the bottom line
  App.screen.init{width=120, height=60}
  Lines = load_array{'abc', 'def', 'ghi', 'jkl'}
  Line_width = App.screen.width
  Cursor1 = {line=3, pos=1}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'abc', 'F - test_down_arrow_scrolls_down_by_one_line/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_down_arrow_scrolls_down_by_one_line/baseline/screen:2')
  y = y + Line_height
  App.screen.check(y, 'ghi', 'F - test_down_arrow_scrolls_down_by_one_line/baseline/screen:3')
  -- after hitting the down arrow the screen scrolls down by one line
  App.run_after_keychord('down')
  check_eq(Screen_top1.line, 2, 'F - test_down_arrow_scrolls_down_by_one_line/screen_top')
  check_eq(Cursor1.line, 4, 'F - test_down_arrow_scrolls_down_by_one_line/cursor')
  y = Margin_top
  App.screen.check(y, 'def', 'F - test_down_arrow_scrolls_down_by_one_line/screen:1')
  y = y + Line_height
  App.screen.check(y, 'ghi', 'F - test_down_arrow_scrolls_down_by_one_line/screen:2')
  y = y + Line_height
  App.screen.check(y, 'jkl', 'F - test_down_arrow_scrolls_down_by_one_line/screen:3')
end

function test_down_arrow_scrolls_down_by_one_screen_line()
  io.write('\ntest_down_arrow_scrolls_down_by_one_screen_line')
  -- display the first three lines with the cursor on the bottom line
  App.screen.init{width=25+30, height=60}
  Lines = load_array{'abc', 'def', 'ghi jkl', 'mno'}
  Line_width = App.screen.width
  Cursor1 = {line=3, pos=1}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'abc', 'F - test_down_arrow_scrolls_down_by_one_screen_line/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_down_arrow_scrolls_down_by_one_screen_line/baseline/screen:2')
  y = y + Line_height
  App.screen.check(y, 'ghi ', 'F - test_down_arrow_scrolls_down_by_one_screen_line/baseline/screen:3')  -- line wrapping includes trailing whitespace
  -- after hitting the down arrow the screen scrolls down by one line
  App.run_after_keychord('down')
  check_eq(Screen_top1.line, 2, 'F - test_down_arrow_scrolls_down_by_one_screen_line/screen_top')
  check_eq(Cursor1.line, 3, 'F - test_down_arrow_scrolls_down_by_one_screen_line/cursor:line')
  check_eq(Cursor1.pos, 5, 'F - test_down_arrow_scrolls_down_by_one_screen_line/cursor:pos')
  y = Margin_top
  App.screen.check(y, 'def', 'F - test_down_arrow_scrolls_down_by_one_screen_line/screen:1')
  y = y + Line_height
  App.screen.check(y, 'ghi ', 'F - test_down_arrow_scrolls_down_by_one_screen_line/screen:2')
  y = y + Line_height
  App.screen.check(y, 'jkl', 'F - test_down_arrow_scrolls_down_by_one_screen_line/screen:3')
end

function test_down_arrow_scrolls_down_by_one_screen_line_after_splitting_within_word()
  io.write('\ntest_down_arrow_scrolls_down_by_one_screen_line_after_splitting_within_word')
  -- display the first three lines with the cursor on the bottom line
  App.screen.init{width=25+30, height=60}
  Lines = load_array{'abc', 'def', 'ghijkl', 'mno'}
  Line_width = App.screen.width
  Cursor1 = {line=3, pos=1}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'abc', 'F - test_down_arrow_scrolls_down_by_one_screen_line_after_splitting_within_word/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_down_arrow_scrolls_down_by_one_screen_line_after_splitting_within_word/baseline/screen:2')
  y = y + Line_height
  App.screen.check(y, 'ghijk', 'F - test_down_arrow_scrolls_down_by_one_screen_line_after_splitting_within_word/baseline/screen:3')
  -- after hitting the down arrow the screen scrolls down by one line
  App.run_after_keychord('down')
  check_eq(Screen_top1.line, 2, 'F - test_down_arrow_scrolls_down_by_one_screen_line_after_splitting_within_word/screen_top')
  check_eq(Cursor1.line, 3, 'F - test_down_arrow_scrolls_down_by_one_screen_line_after_splitting_within_word/cursor:line')
  check_eq(Cursor1.pos, 6, 'F - test_down_arrow_scrolls_down_by_one_screen_line_after_splitting_within_word/cursor:pos')
  y = Margin_top
  App.screen.check(y, 'def', 'F - test_down_arrow_scrolls_down_by_one_screen_line_after_splitting_within_word/screen:1')
  y = y + Line_height
  App.screen.check(y, 'ghijk', 'F - test_down_arrow_scrolls_down_by_one_screen_line_after_splitting_within_word/screen:2')
  y = y + Line_height
  App.screen.check(y, 'l', 'F - test_down_arrow_scrolls_down_by_one_screen_line_after_splitting_within_word/screen:3')
end

function test_page_down_followed_by_down_arrow_does_not_scroll_screen_up()
  io.write('\ntest_page_down_followed_by_down_arrow_does_not_scroll_screen_up')
  App.screen.init{width=25+30, height=60}
  Lines = load_array{'abc', 'def', 'ghijkl', 'mno'}
  Line_width = App.screen.width
  Cursor1 = {line=3, pos=1}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'abc', 'F - test_page_down_followed_by_down_arrow_does_not_scroll_screen_up/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_page_down_followed_by_down_arrow_does_not_scroll_screen_up/baseline/screen:2')
  y = y + Line_height
  App.screen.check(y, 'ghijk', 'F - test_page_down_followed_by_down_arrow_does_not_scroll_screen_up/baseline/screen:3')
  -- after hitting pagedown the screen scrolls down to start of a long line
  App.run_after_keychord('pagedown')
  check_eq(Screen_top1.line, 3, 'F - test_page_down_followed_by_down_arrow_does_not_scroll_screen_up/baseline2/screen_top')
  check_eq(Cursor1.line, 3, 'F - test_page_down_followed_by_down_arrow_does_not_scroll_screen_up/baseline2/cursor:line')
  check_eq(Cursor1.pos, 1, 'F - test_page_down_followed_by_down_arrow_does_not_scroll_screen_up/baseline2/cursor:pos')
  -- after hitting down arrow the screen doesn't scroll down further, and certainly doesn't scroll up
  App.run_after_keychord('down')
  check_eq(Screen_top1.line, 3, 'F - test_page_down_followed_by_down_arrow_does_not_scroll_screen_up/screen_top')
  check_eq(Cursor1.line, 3, 'F - test_page_down_followed_by_down_arrow_does_not_scroll_screen_up/cursor:line')
  check_eq(Cursor1.pos, 6, 'F - test_page_down_followed_by_down_arrow_does_not_scroll_screen_up/cursor:pos')
  y = Margin_top
  App.screen.check(y, 'ghijk', 'F - test_page_down_followed_by_down_arrow_does_not_scroll_screen_up/screen:1')
  y = y + Line_height
  App.screen.check(y, 'l', 'F - test_page_down_followed_by_down_arrow_does_not_scroll_screen_up/screen:2')
  y = y + Line_height
  App.screen.check(y, 'mno', 'F - test_page_down_followed_by_down_arrow_does_not_scroll_screen_up/screen:3')
end

function test_up_arrow_moves_cursor()
  io.write('\ntest_up_arrow_moves_cursor')
  -- display the first 3 lines with the cursor on the bottom line
  App.screen.init{width=120, height=60}
  Lines = load_array{'abc', 'def', 'ghi', 'jkl'}
  Line_width = 120
  Cursor1 = {line=3, pos=1}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'abc', 'F - test_up_arrow_moves_cursor/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_up_arrow_moves_cursor/baseline/screen:2')
  y = y + Line_height
  App.screen.check(y, 'ghi', 'F - test_up_arrow_moves_cursor/baseline/screen:3')
  -- after hitting the up arrow the cursor moves up by 1 line
  App.run_after_keychord('up')
  check_eq(Screen_top1.line, 1, 'F - test_up_arrow_moves_cursor/screen_top')
  check_eq(Cursor1.line, 2, 'F - test_up_arrow_moves_cursor/cursor')
  -- the screen is unchanged
  y = Margin_top
  App.screen.check(y, 'abc', 'F - test_up_arrow_moves_cursor/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_up_arrow_moves_cursor/screen:2')
  y = y + Line_height
  App.screen.check(y, 'ghi', 'F - test_up_arrow_moves_cursor/screen:3')
end

function test_up_arrow_scrolls_up_by_one_line()
  io.write('\ntest_up_arrow_scrolls_up_by_one_line')
  -- display the lines 2/3/4 with the cursor on line 2
  App.screen.init{width=120, height=60}
  Lines = load_array{'abc', 'def', 'ghi', 'jkl'}
  Line_width = 120
  Cursor1 = {line=2, pos=1}
  Screen_top1 = {line=2, pos=1}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'def', 'F - test_up_arrow_scrolls_up_by_one_line/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'ghi', 'F - test_up_arrow_scrolls_up_by_one_line/baseline/screen:2')
  y = y + Line_height
  App.screen.check(y, 'jkl', 'F - test_up_arrow_scrolls_up_by_one_line/baseline/screen:3')
  -- after hitting the up arrow the screen scrolls up by one line
  App.run_after_keychord('up')
  check_eq(Screen_top1.line, 1, 'F - test_up_arrow_scrolls_up_by_one_line/screen_top')
  check_eq(Cursor1.line, 1, 'F - test_up_arrow_scrolls_up_by_one_line/cursor')
  y = Margin_top
  App.screen.check(y, 'abc', 'F - test_up_arrow_scrolls_up_by_one_line/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_up_arrow_scrolls_up_by_one_line/screen:2')
  y = y + Line_height
  App.screen.check(y, 'ghi', 'F - test_up_arrow_scrolls_up_by_one_line/screen:3')
end

function test_up_arrow_scrolls_up_by_one_screen_line()
  io.write('\ntest_up_arrow_scrolls_up_by_one_screen_line')
  -- display lines starting from second screen line of a line
  App.screen.init{width=25+30, height=60}
  Lines = load_array{'abc', 'def', 'ghi jkl', 'mno'}
  Line_width = App.screen.width
  Cursor1 = {line=3, pos=6}
  Screen_top1 = {line=3, pos=5}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'jkl', 'F - test_up_arrow_scrolls_up_by_one_screen_line/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'mno', 'F - test_up_arrow_scrolls_up_by_one_screen_line/baseline/screen:2')
  -- after hitting the up arrow the screen scrolls up to first screen line
  App.run_after_keychord('up')
  y = Margin_top
  App.screen.check(y, 'ghi ', 'F - test_up_arrow_scrolls_up_by_one_screen_line/screen:1')
  y = y + Line_height
  App.screen.check(y, 'jkl', 'F - test_up_arrow_scrolls_up_by_one_screen_line/screen:2')
  y = y + Line_height
  App.screen.check(y, 'mno', 'F - test_up_arrow_scrolls_up_by_one_screen_line/screen:3')
  check_eq(Screen_top1.line, 3, 'F - test_up_arrow_scrolls_up_by_one_screen_line/screen_top')
  check_eq(Screen_top1.pos, 1, 'F - test_up_arrow_scrolls_up_by_one_screen_line/screen_top')
  check_eq(Cursor1.line, 3, 'F - test_up_arrow_scrolls_up_by_one_screen_line/cursor:line')
  check_eq(Cursor1.pos, 1, 'F - test_up_arrow_scrolls_up_by_one_screen_line/cursor:pos')
end

function test_up_arrow_scrolls_up_to_final_screen_line()
  io.write('\ntest_up_arrow_scrolls_up_to_final_screen_line')
  -- display lines starting just after a long line
  App.screen.init{width=25+30, height=60}
  Lines = load_array{'abc def', 'ghi', 'jkl', 'mno'}
  Line_width = App.screen.width
  Cursor1 = {line=2, pos=1}
  Screen_top1 = {line=2, pos=1}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'ghi', 'F - test_up_arrow_scrolls_up_to_final_screen_line/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'jkl', 'F - test_up_arrow_scrolls_up_to_final_screen_line/baseline/screen:2')
  y = y + Line_height
  App.screen.check(y, 'mno', 'F - test_up_arrow_scrolls_up_to_final_screen_line/baseline/screen:3')
  -- after hitting the up arrow the screen scrolls up to final screen line of previous line
  App.run_after_keychord('up')
  y = Margin_top
  App.screen.check(y, 'def', 'F - test_up_arrow_scrolls_up_to_final_screen_line/screen:1')
  y = y + Line_height
  App.screen.check(y, 'ghi', 'F - test_up_arrow_scrolls_up_to_final_screen_line/screen:2')
  y = y + Line_height
  App.screen.check(y, 'jkl', 'F - test_up_arrow_scrolls_up_to_final_screen_line/screen:3')
  check_eq(Screen_top1.line, 1, 'F - test_up_arrow_scrolls_up_to_final_screen_line/screen_top')
  check_eq(Screen_top1.pos, 5, 'F - test_up_arrow_scrolls_up_to_final_screen_line/screen_top')
  check_eq(Cursor1.line, 1, 'F - test_up_arrow_scrolls_up_to_final_screen_line/cursor:line')
  check_eq(Cursor1.pos, 5, 'F - test_up_arrow_scrolls_up_to_final_screen_line/cursor:pos')
end

function test_up_arrow_scrolls_up_to_empty_line()
  io.write('\ntest_up_arrow_scrolls_up_to_empty_line')
  -- display a screenful of text with an empty line just above it outside the screen
  App.screen.init{width=120, height=60}
  Lines = load_array{'', 'abc', 'def', 'ghi', 'jkl'}
  Line_width = 120
  Cursor1 = {line=2, pos=1}
  Screen_top1 = {line=2, pos=1}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'abc', 'F - test_up_arrow_scrolls_up_to_empty_line/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_up_arrow_scrolls_up_to_empty_line/baseline/screen:2')
  y = y + Line_height
  App.screen.check(y, 'ghi', 'F - test_up_arrow_scrolls_up_to_empty_line/baseline/screen:3')
  -- after hitting the up arrow the screen scrolls up by one line
  App.run_after_keychord('up')
  check_eq(Screen_top1.line, 1, 'F - test_up_arrow_scrolls_up_to_empty_line/screen_top')
  check_eq(Cursor1.line, 1, 'F - test_up_arrow_scrolls_up_to_empty_line/cursor')
  y = Margin_top
  -- empty first line
  y = y + Line_height
  App.screen.check(y, 'abc', 'F - test_up_arrow_scrolls_up_to_empty_line/screen:2')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_up_arrow_scrolls_up_to_empty_line/screen:3')
end

function test_pageup()
  io.write('\ntest_pageup')
  App.screen.init{width=120, height=45}
  Lines = load_array{'abc', 'def', 'ghi'}
  Line_width = App.screen.width
  Cursor1 = {line=2, pos=1}
  Screen_top1 = {line=2, pos=1}
  Screen_bottom1 = {}
  -- initially the last two lines are displayed
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'def', 'F - test_pageup/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'ghi', 'F - test_pageup/baseline/screen:2')
  -- after pageup the cursor goes to first line
  App.run_after_keychord('pageup')
  check_eq(Screen_top1.line, 1, 'F - test_pageup/screen_top')
  check_eq(Cursor1.line, 1, 'F - test_pageup/cursor')
  y = Margin_top
  App.screen.check(y, 'abc', 'F - test_pageup/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_pageup/screen:2')
end

function test_pageup_scrolls_up_by_screen_line()
  io.write('\ntest_pageup_scrolls_up_by_screen_line')
  -- display the first three lines with the cursor on the bottom line
  App.screen.init{width=25+30, height=60}
  Lines = load_array{'abc def', 'ghi', 'jkl', 'mno'}
  Line_width = App.screen.width
  Cursor1 = {line=2, pos=1}
  Screen_top1 = {line=2, pos=1}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'ghi', 'F - test_pageup_scrolls_up_by_screen_line/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'jkl', 'F - test_pageup_scrolls_up_by_screen_line/baseline/screen:2')
  y = y + Line_height
  App.screen.check(y, 'mno', 'F - test_pageup_scrolls_up_by_screen_line/baseline/screen:3')  -- line wrapping includes trailing whitespace
  -- after hitting the page-up key the screen scrolls up to top
  App.run_after_keychord('pageup')
  check_eq(Screen_top1.line, 1, 'F - test_pageup_scrolls_up_by_screen_line/screen_top')
  check_eq(Cursor1.line, 1, 'F - test_pageup_scrolls_up_by_screen_line/cursor:line')
  check_eq(Cursor1.pos, 1, 'F - test_pageup_scrolls_up_by_screen_line/cursor:pos')
  y = Margin_top
  App.screen.check(y, 'abc ', 'F - test_pageup_scrolls_up_by_screen_line/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_pageup_scrolls_up_by_screen_line/screen:2')
  y = y + Line_height
  App.screen.check(y, 'ghi', 'F - test_pageup_scrolls_up_by_screen_line/screen:3')
end

function test_pageup_scrolls_up_from_middle_screen_line()
  io.write('\ntest_pageup_scrolls_up_from_middle_screen_line')
  -- display a few lines starting from the middle of a line (Cursor1.pos > 1)
  App.screen.init{width=25+30, height=60}
  Lines = load_array{'abc def', 'ghi jkl', 'mno'}
  Line_width = App.screen.width
  Cursor1 = {line=2, pos=5}
  Screen_top1 = {line=2, pos=5}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'jkl', 'F - test_pageup_scrolls_up_from_middle_screen_line/baseline/screen:2')
  y = y + Line_height
  App.screen.check(y, 'mno', 'F - test_pageup_scrolls_up_from_middle_screen_line/baseline/screen:3')  -- line wrapping includes trailing whitespace
  -- after hitting the page-up key the screen scrolls up to top
  App.run_after_keychord('pageup')
  check_eq(Screen_top1.line, 1, 'F - test_pageup_scrolls_up_from_middle_screen_line/screen_top')
  check_eq(Cursor1.line, 1, 'F - test_pageup_scrolls_up_from_middle_screen_line/cursor:line')
  check_eq(Cursor1.pos, 1, 'F - test_pageup_scrolls_up_from_middle_screen_line/cursor:pos')
  y = Margin_top
  App.screen.check(y, 'abc ', 'F - test_pageup_scrolls_up_from_middle_screen_line/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_pageup_scrolls_up_from_middle_screen_line/screen:2')
  y = y + Line_height
  App.screen.check(y, 'ghi ', 'F - test_pageup_scrolls_up_from_middle_screen_line/screen:3')
end

function test_enter_on_bottom_line_scrolls_down()
  io.write('\ntest_enter_on_bottom_line_scrolls_down')
  -- display a few lines with cursor on bottom line
  App.screen.init{width=25+30, height=60}
  Lines = load_array{'abc', 'def', 'ghi', 'jkl'}
  Line_width = App.screen.width
  Cursor1 = {line=3, pos=2}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'abc', 'F - test_enter_on_bottom_line_scrolls_down/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_enter_on_bottom_line_scrolls_down/baseline/screen:2')
  y = y + Line_height
  App.screen.check(y, 'ghi', 'F - test_enter_on_bottom_line_scrolls_down/baseline/screen:3')
  -- after hitting the enter key the screen scrolls down
  App.run_after_keychord('return')
  check_eq(Screen_top1.line, 2, 'F - test_enter_on_bottom_line_scrolls_down/screen_top')
  check_eq(Cursor1.line, 4, 'F - test_enter_on_bottom_line_scrolls_down/cursor:line')
  check_eq(Cursor1.pos, 1, 'F - test_enter_on_bottom_line_scrolls_down/cursor:pos')
  y = Margin_top
  App.screen.check(y, 'def', 'F - test_enter_on_bottom_line_scrolls_down/screen:1')
  y = y + Line_height
  App.screen.check(y, 'g', 'F - test_enter_on_bottom_line_scrolls_down/screen:2')
  y = y + Line_height
  App.screen.check(y, 'hi', 'F - test_enter_on_bottom_line_scrolls_down/screen:3')
end

function test_enter_on_final_line_avoids_scrolling_down_when_not_at_bottom()
  io.write('\ntest_enter_on_final_line_avoids_scrolling_down_when_not_at_bottom')
  -- display just the bottom line on screen
  App.screen.init{width=25+30, height=60}
  Lines = load_array{'abc', 'def', 'ghi', 'jkl'}
  Line_width = App.screen.width
  Cursor1 = {line=4, pos=2}
  Screen_top1 = {line=4, pos=1}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'jkl', 'F - test_enter_on_final_line_avoids_scrolling_down_when_not_at_bottom/baseline/screen:1')
  -- after hitting the enter key the screen does not scroll down
  App.run_after_keychord('return')
  check_eq(Screen_top1.line, 4, 'F - test_enter_on_final_line_avoids_scrolling_down_when_not_at_bottom/screen_top')
  check_eq(Cursor1.line, 5, 'F - test_enter_on_final_line_avoids_scrolling_down_when_not_at_bottom/cursor:line')
  check_eq(Cursor1.pos, 1, 'F - test_enter_on_final_line_avoids_scrolling_down_when_not_at_bottom/cursor:pos')
  y = Margin_top
  App.screen.check(y, 'j', 'F - test_enter_on_final_line_avoids_scrolling_down_when_not_at_bottom/screen:1')
  y = y + Line_height
  App.screen.check(y, 'kl', 'F - test_enter_on_final_line_avoids_scrolling_down_when_not_at_bottom/screen:2')
end

function test_position_cursor_on_recently_edited_wrapping_line()
  -- draw a line wrapping over 2 screen lines
  io.write('\ntest_position_cursor_on_recently_edited_wrapping_line')
  App.screen.init{width=120, height=200}
  Lines = load_array{'abc def ghi jkl mno pqr ', 'xyz'}
  Line_width = 100
  Cursor1 = {line=1, pos=25}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  -- I don't understand why 120px fits so much on a fake screen, but whatever..
  App.screen.check(y, 'abc def ghi ', 'F - test_position_cursor_on_recently_edited_wrapping_line/baseline1/screen:1')
  y = y + Line_height
  App.screen.check(y, 'jkl mno pqr ', 'F - test_position_cursor_on_recently_edited_wrapping_line/baseline1/screen:2')
  y = y + Line_height
  App.screen.check(y, 'xyz', 'F - test_position_cursor_on_recently_edited_wrapping_line/baseline1/screen:3')
  -- add to the line until it's wrapping over 3 screen lines
  App.run_after_textinput('s')
  App.run_after_textinput('t')
  App.run_after_textinput('u')
  check_eq(Cursor1.pos, 28, 'F - test_move_cursor_using_mouse/cursor:pos')
  y = Margin_top
  App.screen.check(y, 'abc def ghi ', 'F - test_position_cursor_on_recently_edited_wrapping_line/baseline2/screen:1')
  y = y + Line_height
  App.screen.check(y, 'jkl mno pqr ', 'F - test_position_cursor_on_recently_edited_wrapping_line/baseline2/screen:2')
  y = y + Line_height
  App.screen.check(y, 'stu', 'F - test_position_cursor_on_recently_edited_wrapping_line/baseline2/screen:3')
  -- try to move the cursor earlier in the third screen line by clicking the mouse
  local screen_left_margin = 25  -- pixels
  App.run_after_mouserelease(screen_left_margin+8,Margin_top+Line_height*2+5, '1')
  -- cursor should move
  check_eq(Cursor1.line, 1, 'F - test_move_cursor_using_mouse/cursor:line')
  check_eq(Cursor1.pos, 26, 'F - test_move_cursor_using_mouse/cursor:pos')
end

function test_backspace_can_scroll_up()
  io.write('\ntest_backspace_can_scroll_up')
  -- display the lines 2/3/4 with the cursor on line 2
  App.screen.init{width=120, height=60}
  Lines = load_array{'abc', 'def', 'ghi', 'jkl'}
  Line_width = 120
  Cursor1 = {line=2, pos=1}
  Screen_top1 = {line=2, pos=1}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'def', 'F - test_backspace_can_scroll_up/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'ghi', 'F - test_backspace_can_scroll_up/baseline/screen:2')
  y = y + Line_height
  App.screen.check(y, 'jkl', 'F - test_backspace_can_scroll_up/baseline/screen:3')
  -- after hitting backspace the screen scrolls up by one line
  App.run_after_keychord('backspace')
  check_eq(Screen_top1.line, 1, 'F - test_backspace_can_scroll_up/screen_top')
  check_eq(Cursor1.line, 1, 'F - test_backspace_can_scroll_up/cursor')
  y = Margin_top
  App.screen.check(y, 'abcdef', 'F - test_backspace_can_scroll_up/screen:1')
  y = y + Line_height
  App.screen.check(y, 'ghi', 'F - test_backspace_can_scroll_up/screen:2')
  y = y + Line_height
  App.screen.check(y, 'jkl', 'F - test_backspace_can_scroll_up/screen:3')
end

function test_backspace_can_scroll_up_screen_line()
  io.write('\ntest_backspace_can_scroll_up_screen_line')
  -- display lines starting from second screen line of a line
  App.screen.init{width=25+30, height=60}
  Lines = load_array{'abc', 'def', 'ghi jkl', 'mno'}
  Line_width = App.screen.width
  Cursor1 = {line=3, pos=5}
  Screen_top1 = {line=3, pos=5}
  Screen_bottom1 = {}
  App.draw()
  local y = Margin_top
  App.screen.check(y, 'jkl', 'F - test_backspace_can_scroll_up_screen_line/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'mno', 'F - test_backspace_can_scroll_up_screen_line/baseline/screen:2')
  -- after hitting backspace the screen scrolls up by one screen line
  App.run_after_keychord('backspace')
  y = Margin_top
  App.screen.check(y, 'ghijk', 'F - test_backspace_can_scroll_up_screen_line/screen:1')
  y = y + Line_height
  App.screen.check(y, 'l', 'F - test_backspace_can_scroll_up_screen_line/screen:2')
  y = y + Line_height
  App.screen.check(y, 'mno', 'F - test_backspace_can_scroll_up_screen_line/screen:3')
  check_eq(Screen_top1.line, 3, 'F - test_backspace_can_scroll_up_screen_line/screen_top')
  check_eq(Screen_top1.pos, 1, 'F - test_backspace_can_scroll_up_screen_line/screen_top')
  check_eq(Cursor1.line, 3, 'F - test_backspace_can_scroll_up_screen_line/cursor:line')
  check_eq(Cursor1.pos, 4, 'F - test_backspace_can_scroll_up_screen_line/cursor:pos')
end

-- some tests for operating over selections created using Shift- chords
-- we're just testing delete_selection, and it works the same for all keys

function test_backspace_over_selection()
  io.write('\ntest_backspace_over_selection')
  -- select just one character within a line with cursor before selection
  App.screen.init{width=25+30, height=60}
  Lines = load_array{'abc', 'def', 'ghi', 'jkl', 'mno'}
  Line_width = App.screen.width
  Cursor1 = {line=1, pos=1}
  Selection1 = {line=1, pos=2}
  -- backspace deletes the selected character, even though it's after the cursor
  App.run_after_keychord('backspace')
  check_eq(Lines[1].data, 'bc', "F - test_backspace_over_selection/data")
  -- cursor (remains) at start of selection
  check_eq(Cursor1.line, 1, "F - test_backspace_over_selection/cursor:line")
  check_eq(Cursor1.pos, 1, "F - test_backspace_over_selection/cursor:pos")
  -- selection is cleared
  check_nil(Selection1.line, "F - test_backspace_over_selection/selection")
end

function test_backspace_over_selection_reverse()
  io.write('\ntest_backspace_over_selection_reverse')
  -- select just one character within a line with cursor after selection
  App.screen.init{width=25+30, height=60}
  Lines = load_array{'abc', 'def', 'ghi', 'jkl', 'mno'}
  Line_width = App.screen.width
  Cursor1 = {line=1, pos=2}
  Selection1 = {line=1, pos=1}
  -- backspace deletes the selected character
  App.run_after_keychord('backspace')
  check_eq(Lines[1].data, 'bc', "F - test_backspace_over_selection_reverse/data")
  -- cursor moves to start of selection
  check_eq(Cursor1.line, 1, "F - test_backspace_over_selection_reverse/cursor:line")
  check_eq(Cursor1.pos, 1, "F - test_backspace_over_selection_reverse/cursor:pos")
  -- selection is cleared
  check_nil(Selection1.line, "F - test_backspace_over_selection_reverse/selection")
end

function test_backspace_over_multiple_lines()
  io.write('\ntest_backspace_over_multiple_lines')
  -- select just one character within a line with cursor after selection
  App.screen.init{width=25+30, height=60}
  Lines = load_array{'abc', 'def', 'ghi', 'jkl', 'mno'}
  Line_width = App.screen.width
  Cursor1 = {line=1, pos=2}
  Selection1 = {line=4, pos=2}
  -- backspace deletes the region and joins the remaining portions of lines on either side
  App.run_after_keychord('backspace')
  check_eq(Lines[1].data, 'akl', "F - test_backspace_over_multiple_lines/data:1")
  check_eq(Lines[2].data, 'mno', "F - test_backspace_over_multiple_lines/data:2")
  -- cursor remains at start of selection
  check_eq(Cursor1.line, 1, "F - test_backspace_over_multiple_lines/cursor:line")
  check_eq(Cursor1.pos, 2, "F - test_backspace_over_multiple_lines/cursor:pos")
  -- selection is cleared
  check_nil(Selection1.line, "F - test_backspace_over_multiple_lines/selection")
end

function test_backspace_to_end_of_line()
  io.write('\ntest_backspace_to_end_of_line')
  -- select region from cursor to end of line
  App.screen.init{width=25+30, height=60}
  Lines = load_array{'abc', 'def', 'ghi', 'jkl', 'mno'}
  Line_width = App.screen.width
  Cursor1 = {line=1, pos=2}
  Selection1 = {line=1, pos=4}
  -- backspace deletes rest of line without joining to any other line
  App.run_after_keychord('backspace')
  check_eq(Lines[1].data, 'a', "F - test_backspace_to_start_of_line/data:1")
  check_eq(Lines[2].data, 'def', "F - test_backspace_to_start_of_line/data:2")
  -- cursor remains at start of selection
  check_eq(Cursor1.line, 1, "F - test_backspace_to_start_of_line/cursor:line")
  check_eq(Cursor1.pos, 2, "F - test_backspace_to_start_of_line/cursor:pos")
  -- selection is cleared
  check_nil(Selection1.line, "F - test_backspace_to_start_of_line/selection")
end

function test_backspace_to_start_of_line()
  io.write('\ntest_backspace_to_start_of_line')
  -- select region from cursor to start of line
  App.screen.init{width=25+30, height=60}
  Lines = load_array{'abc', 'def', 'ghi', 'jkl', 'mno'}
  Line_width = App.screen.width
  Cursor1 = {line=2, pos=1}
  Selection1 = {line=2, pos=3}
  -- backspace deletes beginning of line without joining to any other line
  App.run_after_keychord('backspace')
  check_eq(Lines[1].data, 'abc', "F - test_backspace_to_start_of_line/data:1")
  check_eq(Lines[2].data, 'f', "F - test_backspace_to_start_of_line/data:2")
  -- cursor remains at start of selection
  check_eq(Cursor1.line, 2, "F - test_backspace_to_start_of_line/cursor:line")
  check_eq(Cursor1.pos, 1, "F - test_backspace_to_start_of_line/cursor:pos")
  -- selection is cleared
  check_nil(Selection1.line, "F - test_backspace_to_start_of_line/selection")
end

function test_undo_insert_text()
  io.write('\ntest_undo_insert_text')
  App.screen.init{width=120, height=60}
  Lines = load_array{'abc', 'def', 'xyz'}
  Line_width = App.screen.width
  Cursor1 = {line=2, pos=4}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  -- insert a character
  App.run_after_textinput('g')
  check_eq(Cursor1.line, 2, 'F - test_undo_insert_text/baseline/cursor:line')
  check_eq(Cursor1.pos, 5, 'F - test_undo_insert_text/baseline/cursor:pos')
  check_nil(Selection1.line, 'F - test_undo_insert_text/baseline/selection:line')
  check_nil(Selection1.pos, 'F - test_undo_insert_text/baseline/selection:pos')
  local y = Margin_top
  App.screen.check(y, 'abc', 'F - test_undo_insert_text/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'defg', 'F - test_undo_insert_text/baseline/screen:2')
  y = y + Line_height
  App.screen.check(y, 'xyz', 'F - test_undo_insert_text/baseline/screen:3')
  -- undo
  App.run_after_keychord('C-z')
  check_eq(Cursor1.line, 2, 'F - test_undo_insert_text/cursor:line')
  check_eq(Cursor1.pos, 4, 'F - test_undo_insert_text/cursor:pos')
  check_nil(Selection1.line, 'F - test_undo_insert_text/selection:line')
  check_nil(Selection1.pos, 'F - test_undo_insert_text/selection:pos')
  y = Margin_top
  App.screen.check(y, 'abc', 'F - test_undo_insert_text/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_undo_insert_text/screen:2')
  y = y + Line_height
  App.screen.check(y, 'xyz', 'F - test_undo_insert_text/screen:3')
end

function test_undo_delete_text()
  io.write('\ntest_undo_delete_text')
  App.screen.init{width=120, height=60}
  Lines = load_array{'abc', 'defg', 'xyz'}
  Line_width = App.screen.width
  Cursor1 = {line=2, pos=5}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  -- delete a character
  App.run_after_keychord('backspace')
  check_eq(Cursor1.line, 2, 'F - test_undo_delete_text/baseline/cursor:line')
  check_eq(Cursor1.pos, 4, 'F - test_undo_delete_text/baseline/cursor:pos')
  check_nil(Selection1.line, 'F - test_undo_delete_text/baseline/selection:line')
  check_nil(Selection1.pos, 'F - test_undo_delete_text/baseline/selection:pos')
  local y = Margin_top
  App.screen.check(y, 'abc', 'F - test_undo_delete_text/baseline/screen:1')
  y = y + Line_height
  App.screen.check(y, 'def', 'F - test_undo_delete_text/baseline/screen:2')
  y = y + Line_height
  App.screen.check(y, 'xyz', 'F - test_undo_delete_text/baseline/screen:3')
  -- undo
--?   -- after undo, the backspaced key is selected
  App.run_after_keychord('C-z')
  check_eq(Cursor1.line, 2, 'F - test_undo_delete_text/cursor:line')
  check_eq(Cursor1.pos, 5, 'F - test_undo_delete_text/cursor:pos')
  check_nil(Selection1.line, 'F - test_undo_delete_text/selection:line')
  check_nil(Selection1.pos, 'F - test_undo_delete_text/selection:pos')
--?   check_eq(Selection1.line, 2, 'F - test_undo_delete_text/selection:line')
--?   check_eq(Selection1.pos, 4, 'F - test_undo_delete_text/selection:pos')
  y = Margin_top
  App.screen.check(y, 'abc', 'F - test_undo_delete_text/screen:1')
  y = y + Line_height
  App.screen.check(y, 'defg', 'F - test_undo_delete_text/screen:2')
  y = y + Line_height
  App.screen.check(y, 'xyz', 'F - test_undo_delete_text/screen:3')
end
