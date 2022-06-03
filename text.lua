-- primitives for editing text
Text = {}

local utf8 = require 'utf8'

require 'undo'

-- return values:
--  y coordinate drawn until in px
--  position of start of final screen line drawn
function Text.draw(line, line_width, line_index)
--?   print('text.draw')
  love.graphics.setColor(0,0,0)
  -- wrap long lines
  local x = 25
  local y = line.y
  local pos = 1
  local screen_line_starting_pos = 1
  if line.fragments == nil then
    Text.compute_fragments(line, line_width)
  end
  if line.screen_line_starting_pos == nil then
    Text.populate_screen_line_starting_pos(line_index)
  end
--?   print('--')
  for _, f in ipairs(line.fragments) do
    local frag, frag_text = f.data, f.text
    -- render fragment
    local frag_width = App.width(frag_text)
    local frag_len = utf8.len(frag)
--?     local s=tostring
--?     print('('..s(x)..','..s(y)..') '..frag..'('..s(frag_width)..' vs '..s(line_width)..') '..s(line_index)..' vs '..s(Screen_top1.line)..'; '..s(pos)..' vs '..s(Screen_top1.pos)..'; bottom: '..s(Screen_bottom1.line)..'/'..s(Screen_bottom1.pos))
    if x + frag_width > line_width then
      assert(x > 25)  -- no overfull lines
      -- update y only after drawing the first screen line of screen top
      if Text.lt1(Screen_top1, {line=line_index, pos=pos}) then
        y = y + Line_height
        if y + Line_height > App.screen.height then
--?           print('b', y, App.screen.height, '=>', screen_line_starting_pos)
          return y, screen_line_starting_pos
        end
        screen_line_starting_pos = pos
--?         print('text: new screen line', y, App.screen.height, screen_line_starting_pos)
      end
      x = 25
    end
--?     print('checking to draw', pos, Screen_top1.pos)
    -- don't draw text above screen top
    if Text.le1(Screen_top1, {line=line_index, pos=pos}) then
      if Selection1.line then
        local lo, hi = Text.clip_selection(line_index, pos, pos+frag_len)
        if lo then
          local lo_offset = utf8.offset(line.data, lo)
          local hi_offset = utf8.offset(line.data, hi)
          local pos_offset = utf8.offset(line.data, pos)
          local lo_px
          if pos == lo then
            lo_px = 0
          else
            local before = line.data:sub(pos_offset, lo_offset-1)
            local before_text = App.newText(love.graphics.getFont(), before)
            lo_px = App.width(before_text)
          end
--?           print(lo,pos,hi, '--', lo_offset,pos_offset,hi_offset, '--', lo_px)
          local s = line.data:sub(lo_offset, hi_offset-1)
          local text = App.newText(love.graphics.getFont(), s)
          local text_width = App.width(text)
          love.graphics.setColor(0.7,0.7,0.9)
          love.graphics.rectangle('fill', x+lo_px,y, text_width,Line_height)
          love.graphics.setColor(0,0,0)
        end
      end
--?       print('drawing '..frag)
      App.screen.draw(frag_text, x,y)
    end
    -- render cursor if necessary
    if line_index == Cursor1.line then
      if pos <= Cursor1.pos and pos + frag_len > Cursor1.pos then
        if Search_term then
          if Lines[Cursor1.line].data:sub(Cursor1.pos, Cursor1.pos+utf8.len(Search_term)-1) == Search_term then
            if Search_text == nil then
              Search_text = App.newText(love.graphics.getFont(), Search_term)
            end
            love.graphics.setColor(0.7,1,1)
            love.graphics.rectangle('fill', x,y, App.width(Search_text),Line_height)
            love.graphics.setColor(0,0,0)
            love.graphics.print(Search_term, x,y)
          end
        else
          Text.draw_cursor(x+Text.x(frag, Cursor1.pos-pos+1), y)
        end
      end
    end
    x = x + frag_width
    pos = pos + frag_len
  end
  if Search_term == nil then
    if line_index == Cursor1.line and Cursor1.pos == pos then
      Text.draw_cursor(x, y)
    end
  end
  return y, screen_line_starting_pos
end
-- manual tests:
--  draw with small line_width of 100

function Text.draw_search_bar()
  local h = Line_height+2
  local y = App.screen.height-h
  love.graphics.setColor(0.9,0.9,0.9)
  love.graphics.rectangle('fill', 0, y-10, App.screen.width-1, h+8)
  love.graphics.setColor(0.6,0.6,0.6)
  love.graphics.line(0, y-10, App.screen.width-1, y-10)
  love.graphics.setColor(1,1,1)
  love.graphics.rectangle('fill', 20, y-6, App.screen.width-40, h+2, 2,2)
  love.graphics.setColor(0.6,0.6,0.6)
  love.graphics.rectangle('line', 20, y-6, App.screen.width-40, h+2, 2,2)
  love.graphics.setColor(0,0,0)
  App.screen.print(Search_term, 25,y-5)
  love.graphics.setColor(1,0,0)
  if Search_text == nil then
    Search_text = App.newText(love.graphics.getFont(), Search_term)
  end
  love.graphics.circle('fill', 25+App.width(Search_text),y-5+h, 2)
  love.graphics.setColor(0,0,0)
end

function Text.search_next()
  -- search current line
  local pos = Lines[Cursor1.line].data:find(Search_term, Cursor1.pos)
  if pos then
    Cursor1.pos = pos
  end
  if pos == nil then
    for i=Cursor1.line+1,#Lines do
      pos = Lines[i].data:find(Search_term)
      if pos then
        Cursor1.line = i
        Cursor1.pos = pos
        break
      end
    end
  end
  if pos == nil then
    -- wrap around
    for i=1,Cursor1.line-1 do
      pos = Lines[i].data:find(Search_term)
      if pos then
        Cursor1.line = i
        Cursor1.pos = pos
        break
      end
    end
  end
  if pos == nil then
    Cursor1.line = Search_backup_cursor1.line
    Cursor1.pos = Search_backup_cursor1.pos
  end
  if Text.lt1(Cursor1, Screen_top1) or Text.lt1(Screen_bottom1, Cursor1) then
    Screen_top1.line = Cursor1.line
    local _, pos = Text.pos_at_start_of_cursor_screen_line()
    Screen_top1.pos = pos
  end
end

function Text.search_previous()
  -- search current line
  local pos = rfind(Lines[Cursor1.line].data, Search_term, Cursor1.pos)
  if pos then
    Cursor1.pos = pos
  end
  if pos == nil then
    for i=Cursor1.line-1,1,-1 do
      pos = rfind(Lines[i].data, Search_term)
      if pos then
        Cursor1.line = i
        Cursor1.pos = pos
        break
      end
    end
  end
  if pos == nil then
    -- wrap around
    for i=#Lines,Cursor1.line+1,-1 do
      pos = rfind(Lines[i].data, Search_term)
      if pos then
        Cursor1.line = i
        Cursor1.pos = pos
        break
      end
    end
  end
  if pos == nil then
    Cursor1.line = Search_backup_cursor1.line
    Cursor1.pos = Search_backup_cursor1.pos
  end
  if Text.lt1(Cursor1, Screen_top1) or Text.lt1(Screen_bottom1, Cursor1) then
    Screen_top1.line = Cursor1.line
    local _, pos = Text.pos_at_start_of_cursor_screen_line()
    Screen_top1.pos = pos
  end
end

function rfind(s, pat, i)
  local rs = s:reverse()
  local rpat = pat:reverse()
  if i == nil then i = #s end
  local ri = #s - i + 1
  local rendpos = rs:find(rpat, ri)
  if rendpos == nil then return nil end
  local endpos = #s - rendpos + 1
  assert (endpos >= #pat)
  return endpos-#pat+1
end

-- Return any intersection of the region from Selection1 to Cursor1 with the
-- region between {line=line_index, pos=apos} and {line=line_index, pos=bpos}.
-- apos must be less than bpos. However Selection1 and Cursor1 can be in any order.
-- Result: positions spos,epos between apos,bpos.
function Text.clip_selection(line_index, apos, bpos)
  if Selection1.line == nil then return nil,nil end
  -- min,max = sorted(Selection1,Cursor1)
  local minl,minp = Selection1.line,Selection1.pos
  local maxl,maxp = Cursor1.line,Cursor1.pos
  if minl > maxl then
    minl,maxl = maxl,minl
    minp,maxp = maxp,minp
  elseif minl == maxl then
    if minp > maxp then
      minp,maxp = maxp,minp
    end
  end
  -- check if intervals are disjoint
  if line_index < minl then return nil,nil end
  if line_index > maxl then return nil,nil end
  if line_index == minl and bpos <= minp then return nil,nil end
  if line_index == maxl and apos >= maxp then return nil,nil end
  -- compare bounds more carefully (start inclusive, end exclusive)
  local a_ge = Text.le1({line=minl, pos=minp}, {line=line_index, pos=apos})
  local b_lt = Text.lt1({line=line_index, pos=bpos}, {line=maxl, pos=maxp})
--?   print(minl,line_index,maxl, '--', minp,apos,bpos,maxp, '--', a_ge,b_lt)
  if a_ge and b_lt then
    -- fully contained
    return apos,bpos
  elseif a_ge then
    assert(maxl == line_index)
    return apos,maxp
  elseif b_lt then
    assert(minl == line_index)
    return minp,bpos
  else
    assert(minl == maxl and minl == line_index)
    return minp,maxp
  end
end

function Text.delete_selection()
  local minl,maxl = minmax(Selection1.line, Cursor1.line)
  local before = snapshot(minl, maxl)
  Text.delete_selection_without_undo()
  record_undo_event({before=before, after=snapshot(Cursor1.line)})
end

function Text.delete_selection_without_undo()
  if Selection1.line == nil then return end
  -- min,max = sorted(Selection1,Cursor1)
  local minl,minp = Selection1.line,Selection1.pos
  local maxl,maxp = Cursor1.line,Cursor1.pos
  if minl > maxl then
    minl,maxl = maxl,minl
    minp,maxp = maxp,minp
  elseif minl == maxl then
    if minp > maxp then
      minp,maxp = maxp,minp
    end
  end
  -- update Cursor1 and Selection1
  Cursor1.line = minl
  Cursor1.pos = minp
  Selection1 = {}
  -- delete everything between min (inclusive) and max (exclusive)
  Lines[minl].fragments = nil
  Lines[minl].screen_line_starting_pos = nil
  local min_offset = utf8.offset(Lines[minl].data, minp)
  local max_offset = utf8.offset(Lines[maxl].data, maxp)
  if minl == maxl then
--?     print('minl == maxl')
    Lines[minl].data = Lines[minl].data:sub(1, min_offset-1)..Lines[minl].data:sub(max_offset)
    return
  end
  assert(minl < maxl)
  local rhs = Lines[maxl].data:sub(max_offset)
  for i=maxl,minl+1,-1 do
    table.remove(Lines, i)
  end
  Lines[minl].data = Lines[minl].data:sub(1, min_offset-1)..rhs
end

function Text.selection()
  if Selection1.line == nil then return end
  -- min,max = sorted(Selection1,Cursor1)
  local minl,minp = Selection1.line,Selection1.pos
  local maxl,maxp = Cursor1.line,Cursor1.pos
  if minl > maxl then
    minl,maxl = maxl,minl
    minp,maxp = maxp,minp
  elseif minl == maxl then
    if minp > maxp then
      minp,maxp = maxp,minp
    end
  end
  local min_offset = utf8.offset(Lines[minl].data, minp)
  local max_offset = utf8.offset(Lines[maxl].data, maxp)
  if minl == maxl then
    return Lines[minl].data:sub(min_offset, max_offset-1)
  end
  assert(minl < maxl)
  local result = Lines[minl].data:sub(min_offset)..'\n'
  for i=minl+1,maxl-1 do
    if Lines[i].mode == 'text' then
      result = result..Lines[i].data..'\n'
    end
  end
  result = result..Lines[maxl].data:sub(1, max_offset-1)
  return result
end

function Text.cut_selection()
  local result = Text.selection()
  Text.delete_selection()
  return result
end

function Text.draw_cursor(x, y)
  love.graphics.setColor(1,0,0)
  love.graphics.circle('fill', x,y+Line_height, 2)
  love.graphics.setColor(0,0,0)
  Cursor_x = x
  Cursor_y = y+Line_height
end

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
  App.draw()  -- populate line.y for each line in Lines
  local screen_left_margin = 25  -- pixels
  App.run_after_mousepress(screen_left_margin+8,Margin_top+5, '1')
  check_eq(Cursor1.line, 1, 'F - test_move_cursor_using_mouse/cursor:line')
  check_eq(Cursor1.pos, 2, 'F - test_move_cursor_using_mouse/cursor:pos')
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
  App.run_after_mousepress(screen_left_margin+8,Margin_top+Line_height*2+5, '1')
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

function Text.compute_fragments(line, line_width)
--?   print('compute_fragments', line_width)
  line.fragments = {}
  local x = 25
  -- try to wrap at word boundaries
  for frag in line.data:gmatch('%S*%s*') do
    local frag_text = App.newText(love.graphics.getFont(), frag)
    local frag_width = App.width(frag_text)
--?     print('x: '..tostring(x)..'; '..tostring(line_width-x)..'px to go')
--?     print('frag: ^'..frag..'$ is '..tostring(frag_width)..'px wide')
    if x + frag_width > line_width then
      while x + frag_width > line_width do
--?         print(x, frag, frag_width, line_width)
        if x < 0.8*line_width then
--?           print(frag, x, frag_width, line_width)
          -- long word; chop it at some letter
          -- We're not going to reimplement TeX here.
          local b = Text.nearest_pos_less_than(frag, line_width - x)
          assert(b > 0)  -- avoid infinite loop when window is too narrow
--?           print('space for '..tostring(b)..' graphemes')
          local frag1 = string.sub(frag, 1, b)
          local frag1_text = App.newText(love.graphics.getFont(), frag1)
          local frag1_width = App.width(frag1_text)
--?           print(frag, x, frag1_width, line_width)
          assert(x + frag1_width <= line_width)
--?           print('inserting '..frag1..' of width '..tostring(frag1_width)..'px')
          table.insert(line.fragments, {data=frag1, text=frag1_text})
          frag = string.sub(frag, b+1)
          frag_text = App.newText(love.graphics.getFont(), frag)
          frag_width = App.width(frag_text)
        end
        x = 25  -- new line
      end
    end
    if #frag > 0 then
--?       print('inserting '..frag..' of width '..tostring(frag_width)..'px')
      table.insert(line.fragments, {data=frag, text=frag_text})
    end
    x = x + frag_width
  end
end

function Text.textinput(t)
  if love.mouse.isDown('1') then return end
  if App.ctrl_down() or App.alt_down() or App.cmd_down() then return end
  if Selection1.line then
    Text.delete_selection()
  end
  local before = snapshot(Cursor1.line)
  Text.insert_at_cursor(t)
  record_undo_event({before=before, after=snapshot(Cursor1.line)})
end

function Text.insert_at_cursor(t)
  local byte_offset
  if Cursor1.pos > 1 then
    byte_offset = utf8.offset(Lines[Cursor1.line].data, Cursor1.pos)
  else
    byte_offset = 1
  end
  Lines[Cursor1.line].data = string.sub(Lines[Cursor1.line].data, 1, byte_offset-1)..t..string.sub(Lines[Cursor1.line].data, byte_offset)
  Lines[Cursor1.line].fragments = nil
  Lines[Cursor1.line].screen_line_starting_pos = nil
  Cursor1.pos = Cursor1.pos+1
end

-- Don't handle any keys here that would trigger love.textinput above.
function Text.keychord_pressed(chord)
--?   print(chord)
  --== shortcuts that mutate text
  if chord == 'return' then
    local before_line = Cursor1.line
    local before = snapshot(before_line)
    Text.insert_return()
    save_to_disk(Lines, Filename)
    record_undo_event({before=before, after=snapshot(before_line, Cursor1.line)})
  elseif chord == 'tab' then
    local before = snapshot(Cursor1.line)
    Text.insert_at_cursor('\t')
    save_to_disk(Lines, Filename)
    record_undo_event({before=before, after=snapshot(Cursor1.line)})
  elseif chord == 'backspace' then
    if Selection1.line then
      Text.delete_selection()
      save_to_disk(Lines, Filename)
      return
    end
    local before
    if Cursor1.pos > 1 then
      before = snapshot(Cursor1.line)
    else
      before = snapshot(Cursor1.line-1, Cursor1.line)
    end
    if Cursor1.pos > 1 then
      local byte_start = utf8.offset(Lines[Cursor1.line].data, Cursor1.pos-1)
      local byte_end = utf8.offset(Lines[Cursor1.line].data, Cursor1.pos)
      if byte_start then
        if byte_end then
          Lines[Cursor1.line].data = string.sub(Lines[Cursor1.line].data, 1, byte_start-1)..string.sub(Lines[Cursor1.line].data, byte_end)
        else
          Lines[Cursor1.line].data = string.sub(Lines[Cursor1.line].data, 1, byte_start-1)
        end
        Lines[Cursor1.line].fragments = nil
        Cursor1.pos = Cursor1.pos-1
      end
    elseif Cursor1.line > 1 then
      if Lines[Cursor1.line-1].mode == 'drawing' then
        table.remove(Lines, Cursor1.line-1)
      else
        -- join lines
        Cursor1.pos = utf8.len(Lines[Cursor1.line-1].data)+1
        Lines[Cursor1.line-1].data = Lines[Cursor1.line-1].data..Lines[Cursor1.line].data
        Lines[Cursor1.line-1].fragments = nil
        table.remove(Lines, Cursor1.line)
      end
      Cursor1.line = Cursor1.line-1
    end
    if Text.lt1(Cursor1, Screen_top1) then
      local top2 = Text.to2(Screen_top1)
      top2 = Text.previous_screen_line(top2)
      Screen_top1 = Text.to1(top2)
    end
    assert(Text.le1(Screen_top1, Cursor1))
    save_to_disk(Lines, Filename)
    record_undo_event({before=before, after=snapshot(Cursor1.line)})
  elseif chord == 'delete' then
    if Selection1.line then
      Text.delete_selection()
      save_to_disk(Lines, Filename)
      return
    end
    local before
    if Cursor1.pos <= utf8.len(Lines[Cursor1.line].data) then
      before = snapshot(Cursor1.line)
    else
      before = snapshot(Cursor1.line, Cursor1.line+1)
    end
    if Cursor1.pos <= utf8.len(Lines[Cursor1.line].data) then
      local byte_start = utf8.offset(Lines[Cursor1.line].data, Cursor1.pos)
      local byte_end = utf8.offset(Lines[Cursor1.line].data, Cursor1.pos+1)
      if byte_start then
        if byte_end then
          Lines[Cursor1.line].data = string.sub(Lines[Cursor1.line].data, 1, byte_start-1)..string.sub(Lines[Cursor1.line].data, byte_end)
        else
          Lines[Cursor1.line].data = string.sub(Lines[Cursor1.line].data, 1, byte_start-1)
        end
        Lines[Cursor1.line].fragments = nil
        -- no change to Cursor1.pos
      end
    elseif Cursor1.line < #Lines then
      if Lines[Cursor1.line+1].mode == 'drawing' then
        table.remove(Lines, Cursor1.line+1)
      else
        -- join lines
        Lines[Cursor1.line].data = Lines[Cursor1.line].data..Lines[Cursor1.line+1].data
        Lines[Cursor1.line].fragments = nil
        table.remove(Lines, Cursor1.line+1)
      end
    end
    save_to_disk(Lines, Filename)
    record_undo_event({before=before, after=snapshot(Cursor1.line)})
  --== shortcuts that move the cursor
  elseif chord == 'left' then
    if Selection1.line then
      Selection1 = {}
    end
    Text.left()
  elseif chord == 'right' then
    if Selection1.line then
      Selection1 = {}
    end
    Text.right()
  elseif chord == 'S-left' then
    if Selection1.line == nil then
      Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
    end
    Text.left()
  elseif chord == 'S-right' then
    if Selection1.line == nil then
      Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
    end
    Text.right()
  -- C- hotkeys reserved for drawings, so we'll use M-
  elseif chord == 'M-left' then
    if Selection1.line then
      Selection1 = {}
    end
    Text.word_left()
  elseif chord == 'M-right' then
    if Selection1.line then
      Selection1 = {}
    end
    Text.word_right()
  elseif chord == 'M-S-left' then
    if Selection1.line == nil then
      Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
    end
    Text.word_left()
  elseif chord == 'M-S-right' then
    if Selection1.line == nil then
      Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
    end
    Text.word_right()
  elseif chord == 'home' then
    if Selection1.line then
      Selection1 = {}
    end
    Cursor1.pos = 1
  elseif chord == 'end' then
    if Selection1.line then
      Selection1 = {}
    end
    Cursor1.pos = utf8.len(Lines[Cursor1.line].data) + 1
  elseif chord == 'S-home' then
    if Selection1.line == nil then
      Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
    end
    Cursor1.pos = 1
  elseif chord == 'S-end' then
    if Selection1.line == nil then
      Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
    end
    Cursor1.pos = utf8.len(Lines[Cursor1.line].data) + 1
  elseif chord == 'up' then
    if Selection1.line then
      Selection1 = {}
    end
    Text.up()
  elseif chord == 'down' then
    if Selection1.line then
      Selection1 = {}
    end
    Text.down()
  elseif chord == 'S-up' then
    if Selection1.line == nil then
      Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
    end
    Text.up()
  elseif chord == 'S-down' then
    if Selection1.line == nil then
      Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
    end
    Text.down()
  elseif chord == 'pageup' then
    if Selection1.line then
      Selection1 = {}
    end
    Text.pageup()
  elseif chord == 'pagedown' then
    if Selection1.line then
      Selection1 = {}
    end
    Text.pagedown()
  elseif chord == 'S-pageup' then
    if Selection1.line == nil then
      Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
    end
    Text.pageup()
  elseif chord == 'S-pagedown' then
    if Selection1.line == nil then
      Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
    end
    Text.pagedown()
  end
end

function Text.insert_return()
  local byte_offset = utf8.offset(Lines[Cursor1.line].data, Cursor1.pos)
  table.insert(Lines, Cursor1.line+1, {mode='text', data=string.sub(Lines[Cursor1.line].data, byte_offset)})
  local scroll_down = (Cursor_y + Line_height) > App.screen.height
  Lines[Cursor1.line].data = string.sub(Lines[Cursor1.line].data, 1, byte_offset-1)
  Lines[Cursor1.line].fragments = nil
  Cursor1.line = Cursor1.line+1
  Cursor1.pos = 1
  if scroll_down then
    Screen_top1.line = Cursor1.line
    Text.scroll_up_while_cursor_on_screen()
  end
end

function Text.pageup()
  -- duplicate some logic from love.draw
  local top2 = Text.to2(Screen_top1)
--?   print(App.screen.height)
  local y = App.screen.height - Line_height
  while y >= Margin_top do
--?     print(y, top2.line)
    if Screen_top1.line == 1 and Screen_top1.pos == 1 then break end
    if Lines[Screen_top1.line].mode == 'text' then
      y = y - Line_height
    elseif Lines[Screen_top1.line].mode == 'drawing' then
      y = y - 20 - Drawing.pixels(Lines[Screen_top1.line].h)
    end
    top2 = Text.previous_screen_line(top2)
  end
  Screen_top1 = Text.to1(top2)
  Cursor1.line = Screen_top1.line
  Cursor1.pos = Screen_top1.pos
  Text.move_cursor_down_to_next_text_line_while_scrolling_again_if_necessary()
--?   print(Cursor1.line, Cursor1.pos, Screen_top1.line, Screen_top1.pos)
end

function Text.pagedown()
  Screen_top1.line = Screen_bottom1.line
  Screen_top1.pos = Screen_bottom1.pos
--?   print('setting top to', Screen_top1.line, Screen_top1.pos)
  Cursor1.line = Screen_top1.line
  Cursor1.pos = Screen_top1.pos
  Text.move_cursor_down_to_next_text_line_while_scrolling_again_if_necessary()
--?   print('top now', Screen_top1.line)
end

function Text.up()
  assert(Lines[Cursor1.line].mode == 'text')
--?   print('up', Cursor1.pos, Screen_top1.pos)
  local screen_line_index,screen_line_starting_pos = Text.pos_at_start_of_cursor_screen_line()
  if screen_line_starting_pos == 1 then
--?     print('cursor is at first screen line of its line')
    -- line is done; skip to previous text line
    local new_cursor_line = Cursor1.line
    while new_cursor_line > 1 do
      new_cursor_line = new_cursor_line-1
      if Lines[new_cursor_line].mode == 'text' then
--?         print('found previous text line')
        Cursor1.line = new_cursor_line
        Text.populate_screen_line_starting_pos(Cursor1.line)
        if Lines[Cursor1.line].screen_line_starting_pos == nil then
          Cursor1.pos = Text.nearest_cursor_pos(Lines[Cursor1.line].data, Cursor_x)
          break
        end
        -- previous text line found, pick its final screen line
--?         print('has multiple screen lines')
        local screen_line_starting_pos = Lines[Cursor1.line].screen_line_starting_pos
--?         print(#screen_line_starting_pos)
        screen_line_starting_pos = screen_line_starting_pos[#screen_line_starting_pos]
--?         print('previous screen line starts at pos '..tostring(screen_line_starting_pos)..' of its line')
        if Screen_top1.line > Cursor1.line then
          Screen_top1.line = Cursor1.line
          Screen_top1.pos = screen_line_starting_pos
--?           print('pos of top of screen is also '..tostring(Screen_top1.pos)..' of the same line')
        end
        local s = string.sub(Lines[Cursor1.line].data, screen_line_starting_pos)
        Cursor1.pos = screen_line_starting_pos + Text.nearest_cursor_pos(s, Cursor_x) - 1
        break
      end
    end
    if Cursor1.line < Screen_top1.line then
      Screen_top1.line = Cursor1.line
    end
  else
    -- move up one screen line in current line
--?     print('cursor is NOT at first screen line of its line')
    assert(screen_line_index > 1)
    new_screen_line_starting_pos = Lines[Cursor1.line].screen_line_starting_pos[screen_line_index-1]
--?     print('switching pos of screen line at cursor from '..tostring(screen_line_starting_pos)..' to '..tostring(new_screen_line_starting_pos))
    if Screen_top1.line == Cursor1.line and Screen_top1.pos == screen_line_starting_pos then
      Screen_top1.pos = new_screen_line_starting_pos
--?       print('also setting pos of top of screen to '..tostring(Screen_top1.pos))
    end
    local s = string.sub(Lines[Cursor1.line].data, new_screen_line_starting_pos)
    Cursor1.pos = new_screen_line_starting_pos + Text.nearest_cursor_pos(s, Cursor_x) - 1
--?     print('cursor pos is now '..tostring(Cursor1.pos))
  end
end

function Text.down()
  assert(Lines[Cursor1.line].mode == 'text')
--?   print('down', Cursor1.line, Cursor1.pos, Screen_top1.line, Screen_top1.pos, Screen_bottom1.line, Screen_bottom1.pos)
  if Text.cursor_at_final_screen_line() then
    -- line is done, skip to next text line
--?     print('cursor at final screen line of its line')
    local new_cursor_line = Cursor1.line
    while new_cursor_line < #Lines do
      new_cursor_line = new_cursor_line+1
      if Lines[new_cursor_line].mode == 'text' then
        Cursor1.line = new_cursor_line
        Cursor1.pos = Text.nearest_cursor_pos(Lines[Cursor1.line].data, Cursor_x)
--?         print(Cursor1.pos)
        break
      end
    end
    if Cursor1.line > Screen_bottom1.line then
--?       print('screen top before:', Screen_top1.line, Screen_top1.pos)
      Screen_top1.line = Cursor1.line
--?       print('scroll up preserving cursor')
      Text.scroll_up_while_cursor_on_screen()
--?       print('screen top after:', Screen_top1.line, Screen_top1.pos)
    end
  else
    -- move down one screen line in current line
    local scroll_up = false
    if Text.le1(Screen_bottom1, Cursor1) then
      scroll_up = true
    end
--?     print('cursor is NOT at final screen line of its line')
    local screen_line_index, screen_line_starting_pos = Text.pos_at_start_of_cursor_screen_line()
    new_screen_line_starting_pos = Lines[Cursor1.line].screen_line_starting_pos[screen_line_index+1]
--?     print('switching pos of screen line at cursor from '..tostring(screen_line_starting_pos)..' to '..tostring(new_screen_line_starting_pos))
    local s = string.sub(Lines[Cursor1.line].data, new_screen_line_starting_pos)
    Cursor1.pos = new_screen_line_starting_pos + Text.nearest_cursor_pos(s, Cursor_x) - 1
--?     print('cursor pos is now', Cursor1.line, Cursor1.pos)
    if scroll_up then
      Screen_top1.line = Cursor1.line
--?       print('scroll up preserving cursor')
      Text.scroll_up_while_cursor_on_screen()
--?       print('screen top after:', Screen_top1.line, Screen_top1.pos)
    end
  end
--?   print('=>', Cursor1.line, Cursor1.pos, Screen_top1.line, Screen_top1.pos, Screen_bottom1.line, Screen_bottom1.pos)
end

function Text.word_left()
  while true do
    Text.left()
    if Cursor1.pos == 1 then break end
    assert(Cursor1.pos > 1)
    local offset = utf8.offset(Lines[Cursor1.line].data, Cursor1.pos)
    assert(offset > 1)
    if Lines[Cursor1.line].data:sub(offset-1,offset-1) == ' ' then
      break
    end
  end
end

function Text.word_right()
  while true do
    Text.right()
    if Cursor1.pos > utf8.len(Lines[Cursor1.line].data) then break end
    local offset = utf8.offset(Lines[Cursor1.line].data, Cursor1.pos)
    if Lines[Cursor1.line].data:sub(offset,offset) == ' ' then  -- TODO: other space characters
      break
    end
  end
end

function Text.left()
  assert(Lines[Cursor1.line].mode == 'text')
  if Cursor1.pos > 1 then
    Cursor1.pos = Cursor1.pos-1
  else
    local new_cursor_line = Cursor1.line
    while new_cursor_line > 1 do
      new_cursor_line = new_cursor_line-1
      if Lines[new_cursor_line].mode == 'text' then
        Cursor1.line = new_cursor_line
        Cursor1.pos = utf8.len(Lines[Cursor1.line].data) + 1
        break
      end
    end
    if Cursor1.line < Screen_top1.line then
      Screen_top1.line = Cursor1.line
    end
  end
end

function Text.right()
  assert(Lines[Cursor1.line].mode == 'text')
  if Cursor1.pos <= utf8.len(Lines[Cursor1.line].data) then
    Cursor1.pos = Cursor1.pos+1
  else
    local new_cursor_line = Cursor1.line
    while new_cursor_line <= #Lines-1 do
      new_cursor_line = new_cursor_line+1
      if Lines[new_cursor_line].mode == 'text' then
        Cursor1.line = new_cursor_line
        Cursor1.pos = 1
        break
      end
    end
    if Cursor1.line > Screen_bottom1.line then
      Screen_top1.line = Cursor1.line
    end
  end
end

function Text.pos_at_start_of_cursor_screen_line()
  if Lines[Cursor1.line].screen_line_starting_pos == nil then
    return 1,1
  end
  for i=#Lines[Cursor1.line].screen_line_starting_pos,1,-1 do
    local spos = Lines[Cursor1.line].screen_line_starting_pos[i]
    if spos <= Cursor1.pos then
      return i,spos
    end
  end
  assert(false)
end

function Text.cursor_at_final_screen_line()
  if Lines[Cursor1.line].screen_line_starting_pos == nil then
    return true
  end
  local screen_lines = Lines[Cursor1.line].screen_line_starting_pos
--?   print(screen_lines[#screen_lines], Cursor1.pos)
  return screen_lines[#screen_lines] <= Cursor1.pos
end

function Text.move_cursor_down_to_next_text_line_while_scrolling_again_if_necessary()
  local y = Margin_top
  while Cursor1.line <= #Lines do
    if Lines[Cursor1.line].mode == 'text' then
      break
    end
--?     print('cursor skips', Cursor1.line)
    y = y + 20 + Drawing.pixels(Lines[Cursor1.line].h)
    Cursor1.line = Cursor1.line + 1
  end
  -- hack: insert a text line at bottom of file if necessary
  if Cursor1.line > #Lines then
    assert(Cursor1.line == #Lines+1)
    table.insert(Lines, {mode='text', data=''})
  end
--?   print(y, App.screen.height, App.screen.height-Line_height)
  if y > App.screen.height - Line_height then
--?     print('scroll up')
    Screen_top1.line = Cursor1.line
    Text.scroll_up_while_cursor_on_screen()
  end
end

function Text.scroll_up_while_cursor_on_screen()
  local top2 = Text.to2(Cursor1)
--?   print('cursor pos '..tostring(Cursor1.pos)..' is on the #'..tostring(top2.screen_line)..' screen line down')
  local y = App.screen.height - Line_height
  -- duplicate some logic from love.draw
  while true do
--?     print(y, 'top2:', top2.line, top2.screen_line, top2.screen_pos)
    if top2.line == 1 and top2.screen_line == 1 then break end
    if top2.screen_line > 1 or Lines[top2.line-1].mode == 'text' then
      local h = Line_height
      if y - h < Margin_top then
        break
      end
      y = y - h
    else
      assert(top2.line > 1)
      assert(Lines[top2.line-1].mode == 'drawing')
      -- We currently can't draw partial drawings, so either skip it entirely
      -- or not at all.
      local h = 20 + Drawing.pixels(Lines[top2.line-1].h)
      if y - h < Margin_top then
        break
      end
--?       print('skipping drawing of height', h)
      y = y - h
    end
    top2 = Text.previous_screen_line(top2)
  end
--?   print('top2 finally:', top2.line, top2.screen_line, top2.screen_pos)
  Screen_top1 = Text.to1(top2)
--?   print('top1 finally:', Screen_top1.line, Screen_top1.pos)
end

function Text.in_line(line, x,y)
  if line.y == nil then return false end  -- outside current page
  if x < 25 then return false end
  if y < line.y then return false end
  if line.screen_line_starting_pos == nil then return y < line.y + Line_height end
  return y < line.y + #line.screen_line_starting_pos * Line_height
end

-- mx,my in pixels
function Text.move_cursor(line_index, line, mx, my)
  Cursor1.line = line_index
  if line.screen_line_starting_pos == nil then
    Cursor1.pos = Text.nearest_cursor_pos(line.data, mx)
    return
  end
  assert(line.fragments)
  assert(my >= line.y)
  -- duplicate some logic from Text.draw
  local y = line.y
  for screen_line_index,screen_line_starting_pos in ipairs(line.screen_line_starting_pos) do
    local nexty = y + Line_height
    if my < nexty then
      -- On all wrapped screen lines but the final one, clicks past end of
      -- line position cursor on final character of screen line.
      -- (The final screen line positions past end of screen line as always.)
      if mx > Line_width and screen_line_index < #line.screen_line_starting_pos then
        Cursor1.pos = line.screen_line_starting_pos[screen_line_index+1]
        return
      end
      local s = string.sub(line.data, screen_line_starting_pos)
      Cursor1.pos = screen_line_starting_pos + Text.nearest_cursor_pos(s, mx) - 1
      return
    end
    y = nexty
  end
  assert(false)
end
-- manual test:
--  line: abc
--        def
--        gh
--  fragments: abc, def, gh
--  click inside e
--  line_starting_pos = 1 + 3 = 4
--  nearest_cursor_pos('defgh', mx) = 2
--  Cursor1.pos = 4 + 2 - 1 = 5
-- manual test:
--  click inside h
--  line_starting_pos = 1 + 3 + 3 = 7
--  nearest_cursor_pos('gh', mx) = 2
--  Cursor1.pos = 7 + 2 - 1 = 8

function Text.nearest_cursor_pos(line, x)  -- x includes left margin
  if x == 0 then
    return 1
  end
  local len = utf8.len(line)
  local max_x = 25+Text.x(line, len+1)
  if x > max_x then
    return len+1
  end
  local left, right = 1, len+1
--?   print('-- nearest', x)
  while true do
--?     print('nearest', x, '^'..line..'$', left, right)
    if left == right then
      return left
    end
    local curr = math.floor((left+right)/2)
    local currxmin = 25+Text.x(line, curr)
    local currxmax = 25+Text.x(line, curr+1)
--?     print('nearest', x, left, right, curr, currxmin, currxmax)
    if currxmin <= x and x < currxmax then
      if x-currxmin < currxmax-x then
        return curr
      else
        return curr+1
      end
    end
    if left >= right-1 then
      return right
    end
    if currxmin > x then
      right = curr
    else
      left = curr
    end
  end
  assert(false)
end

function Text.nearest_pos_less_than(line, x)  -- x DOES NOT include left margin
  if x == 0 then
    return 1
  end
  local len = utf8.len(line)
  local max_x = Text.x(line, len+1)
  if x > max_x then
    return len+1
  end
  local left, right = 1, len+1
--?   print('--')
  while true do
    local curr = math.floor((left+right)/2)
    local currxmin = Text.x(line, curr+1)
    local currxmax = Text.x(line, curr+2)
--?     print(x, left, right, curr, currxmin, currxmax)
    if currxmin <= x and x < currxmax then
      return curr
    end
    if left >= right-1 then
      return left
    end
    if currxmin > x then
      right = curr
    else
      left = curr
    end
  end
  assert(false)
end

function Text.x(s, pos)
  local offset = utf8.offset(s, pos)
  assert(offset)
  local s_before = s:sub(1, offset-1)
  local text_before = App.newText(love.graphics.getFont(), s_before)
  return App.width(text_before)
end

function Text.to2(pos1)
  if Lines[pos1.line].mode == 'drawing' then
    return {line=pos1.line, screen_line=1, screen_pos=1}
  end
  local result = {line=pos1.line, screen_line=1}
  if Lines[pos1.line].screen_line_starting_pos == nil then
    result.screen_pos = pos1.pos
  else
    for i=#Lines[pos1.line].screen_line_starting_pos,1,-1 do
      local spos = Lines[pos1.line].screen_line_starting_pos[i]
      if spos <= pos1.pos then
        result.screen_line = i
        result.screen_pos = pos1.pos - spos + 1
        break
      end
    end
  end
  assert(result.screen_pos)
  return result
end

function Text.to1(pos2)
  local result = {line=pos2.line, pos=pos2.screen_pos}
  if pos2.screen_line > 1 then
    result.pos = Lines[pos2.line].screen_line_starting_pos[pos2.screen_line] + pos2.screen_pos - 1
  end
  return result
end

function Text.lt1(a, b)
  if a.line < b.line then
    return true
  end
  if a.line > b.line then
    return false
  end
  return a.pos < b.pos
end

function Text.le1(a, b)
  if a.line < b.line then
    return true
  end
  if a.line > b.line then
    return false
  end
  return a.pos <= b.pos
end

function Text.previous_screen_line(pos2)
  if pos2.screen_line > 1 then
    return {line=pos2.line, screen_line=pos2.screen_line-1, screen_pos=1}
  elseif pos2.line == 1 then
    return pos2
  elseif Lines[pos2.line-1].mode == 'drawing' then
    return {line=pos2.line-1, screen_line=1, screen_pos=1}
  else
    local l = Lines[pos2.line-1]
    if l.screen_line_starting_pos == nil then
      return {line=pos2.line-1, screen_line=1, screen_pos=1}
    else
      return {line=pos2.line-1, screen_line=#Lines[pos2.line-1].screen_line_starting_pos, screen_pos=1}
    end
  end
end

function Text.populate_screen_line_starting_pos(line_index)
--?   print('Text.populate_screen_line_starting_pos')
  local line = Lines[line_index]
  if line.screen_line_starting_pos then
    return
  end
  -- duplicate some logic from Text.draw
  if line.fragments == nil then
    Text.compute_fragments(line, Line_width)
  end
  local x = 25
  local pos = 1
  for _, f in ipairs(line.fragments) do
    local frag, frag_text = f.data, f.text
--?     print(x, frag)
    -- render fragment
    local frag_width = App.width(frag_text)
    if x + frag_width > Line_width then
      x = 25
      if line.screen_line_starting_pos == nil then
        line.screen_line_starting_pos = {1, pos}
      else
--?         print(' ', #line.screen_line_starting_pos, line.data)
        table.insert(line.screen_line_starting_pos, pos)
      end
    end
    x = x + frag_width
    local frag_len = utf8.len(frag)
    pos = pos + frag_len
  end
end

function Text.redraw_all()
  for _,line in ipairs(Lines) do
    line.fragments = nil
    line.screen_line_starting_pos = nil
  end
end

return Text
